import 'dart:async';
import 'package:flutter/material.dart';
import 'assessment_audio_controller.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_access_code_screen.dart';
import 'assessment_instructions_screen.dart';
import 'assessment_result_screen.dart';

const int _likertPageSize = 1;

class _RenderUnit {
  final String kind; // 'batch' | 'single' | 'multiselect' | 'ranking'
  final String typeName;
  final List<Map<String, dynamic>> questions;
  _RenderUnit({required this.kind, required this.typeName, required this.questions});
  Map<String, dynamic> get question => questions.first;
}

bool _isLikert(Map<String, dynamic> q) => q['questionType'] == 'LIKERT_SCALE' || q['questionType'] == null;

List<_RenderUnit> _buildRenderUnits(List<Map<String, dynamic>> sections) {
  final units = <_RenderUnit>[];
  for (final section in sections) {
    final qs = List<Map<String, dynamic>>.from(section['questions'] as List);
    final typeName = (section['typeName'] as String?) ?? 'Questions';
    var i = 0;
    while (i < qs.length) {
      if (_isLikert(qs[i])) {
        final batch = <Map<String, dynamic>>[];
        while (i < qs.length && _isLikert(qs[i]) && batch.length < _likertPageSize) {
          batch.add(qs[i]);
          i++;
        }
        units.add(_RenderUnit(kind: 'batch', typeName: typeName, questions: batch));
      } else {
        final q = qs[i];
        final kind = q['questionType'] == 'MULTI_SELECT'
            ? 'multiselect'
            : q['questionType'] == 'RANKING'
                ? 'ranking'
                : 'single';
        units.add(_RenderUnit(kind: kind, typeName: typeName, questions: [q]));
        i++;
      }
    }
  }
  return units;
}

bool _isAnswered(Map<String, dynamic> q, Map<String, dynamic> answers) {
  final val = answers[q['_id']];
  if (q['questionType'] == 'MULTI_SELECT') return val is List && val.isNotEmpty;
  if (q['questionType'] == 'RANKING') return val is List && val.length == (q['options'] as List).length;
  return val != null;
}

bool _isResolved(Map<String, dynamic> q, Map<String, dynamic> answers, Map<String, bool> timedOut) =>
    _isAnswered(q, answers) || (timedOut[q['_id']] ?? false);

/// Ported from app/frontend/user/assessment.html — the question-taking flow:
/// global + per-question countdown timers, 4 question-type renderers,
/// 2-tier audio (see [AssessmentAudioController]), autosave, review-marking,
/// and submit.
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _sections = [];
  List<_RenderUnit> _renderUnits = [];
  List<Map<String, dynamic>> _flatQuestions = [];
  final Map<String, dynamic> _answers = {};
  final Map<String, bool> _timedOut = {};
  final Map<String, int> _timeSpentSeconds = {};
  final Map<String, DateTime> _questionStart = {};
  final Set<int> _marked = {};
  int _currentSection = 0;
  String? _sessionId;
  String? _token;
  String? _unansweredMsg;
  bool _submitting = false;

  Timer? _globalTicker;
  Duration _globalRemaining = Duration.zero;
  Timer? _questionTicker;
  Duration _questionRemaining = Duration.zero;
  String? _questionTickerQid;

  late final AssessmentAudioController _audio;

  @override
  void initState() {
    super.initState();
    _audio = AssessmentAudioController();
    _audio.addListener(_onAudioChanged);
    _bootstrap();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _globalTicker?.cancel();
    _questionTicker?.cancel();
    _audio.removeListener(_onAudioChanged);
    _audio.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final hasCode = await AssessmentSession.hasCode();
    if (!hasCode) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
      return;
    }
    final sessionId = await AssessmentSession.getSessionId();
    final sessionExpires = await AssessmentSession.getSessionExpires();
    if (sessionId == null || sessionExpires == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentInstructionsScreen()));
      return;
    }
    _sessionId = sessionId;
    _token = await AssessmentSession.getToken();

    final res = await AssessmentService.instance.getQuestions(_token!);
    if (!mounted) return;
    if (!res.ok || res.data['data'] == null) {
      setState(() {
        _loadError = (res.data['message'] as String?) ?? "Couldn't load your questions. Please check your connection.";
        _loading = false;
      });
      return;
    }

    _sections = List<Map<String, dynamic>>.from(
      (res.data['data'] as List).map((s) => Map<String, dynamic>.from(s as Map)),
    );

    final saved = await AssessmentSession.loadAutosave(sessionId);
    if (saved != null) {
      if (saved['answers'] is Map) _answers.addAll(Map<String, dynamic>.from(saved['answers'] as Map));
      if (saved['timedOut'] is Map) {
        (saved['timedOut'] as Map).forEach((k, v) => _timedOut[k as String] = v == true);
      }
      if (saved['timeSpent'] is Map) {
        (saved['timeSpent'] as Map).forEach((k, v) => _timeSpentSeconds[k as String] = (v as num).toInt());
      }
      if (saved['marked'] is List) {
        for (final m in saved['marked'] as List) {
          _marked.add((m as num).toInt());
        }
      }
    }

    _renderUnits = _buildRenderUnits(_sections);
    _flatQuestions = _sections.expand((s) => List<Map<String, dynamic>>.from(s['questions'] as List)).toList();

    // remainingSeconds is server-recalculated (accounts for elapsed time);
    // fall back to the session's absolute expiry rather than leaving the
    // timer unset, mirroring assessment.html.
    int seconds;
    final remaining = res.data['remainingSeconds'];
    if (remaining is num) {
      seconds = remaining.toInt();
    } else {
      final expiresAt = DateTime.tryParse(sessionExpires);
      seconds = expiresAt != null ? expiresAt.difference(DateTime.now()).inSeconds : 0;
    }
    // Re-check mounted: loadAutosave() above awaited, so the widget could
    // have been disposed in the meantime (e.g. the user navigated back
    // while it was loading) — starting a timer or calling setState after
    // that would be a bug (a timer leaking past dispose, or a
    // "setState() called after dispose()" crash).
    if (!mounted) return;
    _startGlobalTimer(Duration(seconds: seconds < 0 ? 0 : seconds));

    setState(() => _loading = false);
    _enterSection(0);
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  void _startGlobalTimer(Duration duration) {
    _globalTicker?.cancel();
    _globalRemaining = duration;
    _globalTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_globalRemaining.inSeconds <= 0) {
        t.cancel();
        _submit(auto: true);
        return;
      }
      setState(() => _globalRemaining -= const Duration(seconds: 1));
    });
  }

  void _startQuestionTimer(Map<String, dynamic> question) {
    _questionTicker?.cancel();
    final qid = question['_id'] as String;
    _questionTickerQid = qid;
    _questionRemaining = Duration(seconds: (question['timeLimitSeconds'] as num).toInt());
    _questionTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_questionRemaining.inSeconds <= 0) {
        t.cancel();
        _onQuestionTimeout(qid);
        return;
      }
      setState(() => _questionRemaining -= const Duration(seconds: 1));
    });
  }

  void _stopQuestionTimer() {
    _questionTicker?.cancel();
    _questionTicker = null;
    _questionTickerQid = null;
  }

  void _onQuestionTimeout(String qid) {
    _markTimeSpent(qid);
    setState(() => _timedOut[qid] = true);
    _saveAutosave();
    if (_currentSection < _renderUnits.length - 1) {
      _enterSection(_currentSection + 1);
    }
  }

  // ── Section navigation ───────────────────────────────────────────────
  void _enterSection(int index) {
    _stopQuestionTimer();
    _audio.stop();
    final unit = _renderUnits[index];
    final qs = unit.kind == 'batch' ? unit.questions : [unit.question];
    for (final q in qs) {
      _questionStart.putIfAbsent(q['_id'] as String, () => DateTime.now());
    }
    if (unit.kind == 'ranking' && _answers[unit.question['_id']] == null) {
      _answers[unit.question['_id'] as String] =
          (unit.question['options'] as List).map((o) => (o as Map)['_id'] as String).toList();
    }
    final q = unit.kind == 'single' ? unit.question : null;
    final timeLimited = q != null && q['timeLimitSeconds'] != null && !_isAnswered(q, _answers) && !(_timedOut[q['_id']] ?? false);
    setState(() {
      _currentSection = index;
      _unansweredMsg = null;
    });
    if (timeLimited) _startQuestionTimer(q);
  }

  void _markTimeSpent(String qid) {
    final start = _questionStart[qid];
    if (start != null) _timeSpentSeconds[qid] = DateTime.now().difference(start).inSeconds;
  }

  Future<void> _saveAutosave() async {
    if (_sessionId == null) return;
    await AssessmentSession.saveAutosave(_sessionId!, {
      'answers': _answers,
      'timedOut': _timedOut,
      'timeSpent': _timeSpentSeconds,
      'marked': _marked.toList(),
    });
  }

  // ── Answering ────────────────────────────────────────────────────────
  void _recordAnswer(String qid, String optionId) {
    setState(() => _answers[qid] = optionId);
    _markTimeSpent(qid);
    final unit = _renderUnits[_currentSection];
    if (unit.kind == 'single' && unit.question['_id'] == qid) _stopQuestionTimer();
    _saveAutosave();
  }

  void _toggleMultiSelect(String qid, String optionId, bool checked) {
    final current = Set<String>.from((_answers[qid] as List?)?.cast<String>() ?? const []);
    if (checked) {
      current.add(optionId);
    } else {
      current.remove(optionId);
    }
    setState(() => _answers[qid] = current.toList());
    _markTimeSpent(qid);
    _saveAutosave();
  }

  void _moveRankingItem(String qid, int index, int dir) {
    final order = List<String>.from((_answers[qid] as List).cast<String>());
    final j = index + dir;
    if (j < 0 || j >= order.length) return;
    final tmp = order[index];
    order[index] = order[j];
    order[j] = tmp;
    setState(() => _answers[qid] = order);
    _markTimeSpent(qid);
    _saveAutosave();
  }

  void _toggleReview(int unitIndex) {
    setState(() {
      if (_marked.contains(unitIndex)) {
        _marked.remove(unitIndex);
      } else {
        _marked.add(unitIndex);
      }
    });
    _saveAutosave();
  }

  bool _unitHasAnswer(_RenderUnit unit) => unit.kind == 'batch'
      ? unit.questions.every((q) => _isAnswered(q, _answers))
      : _isAnswered(unit.question, _answers);

  void _goNext() {
    final unit = _renderUnits[_currentSection];
    final timedOutHere = unit.kind != 'batch' && (_timedOut[unit.question['_id']] ?? false);
    if (!_unitHasAnswer(unit) && !timedOutHere) {
      showAssessmentSnack(context, 'Please select an answer before continuing.', isError: true);
      return;
    }
    _enterSection(_currentSection + 1);
  }

  void _goPrev() {
    if (_currentSection > 0) _enterSection(_currentSection - 1);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit assessment?'),
        content: const Text('Your progress is saved, but the timer keeps running while you\'re away.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Exit')),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Submit ───────────────────────────────────────────────────────────
  Future<void> _submit({required bool auto}) async {
    if (_submitting) return;
    final resolvedCount = _flatQuestions.where((q) => _isResolved(q, _answers, _timedOut)).length;
    if (!auto && resolvedCount < _flatQuestions.length) {
      setState(() => _unansweredMsg =
          '⚠️ ${_flatQuestions.length - resolvedCount} question(s) unanswered. Please answer all questions before submitting.');
      return;
    }
    _globalTicker?.cancel();
    _stopQuestionTimer();
    await _audio.stop();

    final payload = _flatQuestions.map((q) {
      final qid = q['_id'] as String;
      final entry = <String, dynamic>{'questionId': qid};
      if (_isAnswered(q, _answers)) {
        final val = _answers[qid];
        if (q['questionType'] == 'MULTI_SELECT') {
          entry['answerOptionIds'] = val;
        } else if (q['questionType'] == 'RANKING') {
          entry['orderedOptionIds'] = val;
        } else {
          entry['answerOptionId'] = val;
        }
        entry['status'] = (_timedOut[qid] ?? false) ? 'timeout' : 'answered';
      } else {
        entry['status'] = (_timedOut[qid] ?? false) ? 'timeout' : 'skipped';
      }
      if (_timeSpentSeconds[qid] != null) entry['timeTakenSeconds'] = _timeSpentSeconds[qid];
      return entry;
    }).toList();

    setState(() => _submitting = true);
    final res = await AssessmentService.instance.submitAssessment(
      sessionId: _sessionId!,
      answers: payload,
      autoSubmitted: auto,
      token: _token!,
    );
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _submitting = false);
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Submission failed.', isError: true);
      return;
    }
    await AssessmentSession.clearSessionState();
    await AssessmentSession.clearAutosave(_sessionId!);
    final user = await AssessmentSession.getUser();
    if (user != null) {
      user['hasCompletedAssessment'] = true;
      await AssessmentSession.setUser(user);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentResultScreen()));
  }

  // ── Sections sheet (mobile equivalent of the web sidebar) ────────────
  void _openSectionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final cats = <String>[];
        final firstUnitForCat = <String, int>{};
        for (var i = 0; i < _renderUnits.length; i++) {
          final name = _renderUnits[i].typeName;
          if (!cats.contains(name)) {
            cats.add(name);
            firstUnitForCat[name] = i;
          }
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: cats.map((name) {
              final done = _renderUnits
                  .where((u) => u.typeName == name)
                  .expand((u) => u.questions)
                  .every((q) => _isAnswered(q, _answers));
              return ListTile(
                leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? const Color(0xFF006C49) : null),
                title: Text(name),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _enterSection(firstUnitForCat[name]!);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AssessmentScaffold(title: 'Assessment', body: AssessmentLoading(message: 'Loading questions...'));
    }
    if (_loadError != null) {
      return AssessmentScaffold(
        title: 'Assessment',
        body: AssessmentErrorView(
          message: _loadError!,
          onRetry: () {
            setState(() {
              _loading = true;
              _loadError = null;
            });
            _bootstrap();
          },
        ),
      );
    }

    final unit = _renderUnits[_currentSection];
    final isLast = _currentSection == _renderUnits.length - 1;
    final answeredCount = _flatQuestions.where((q) => _isAnswered(q, _answers)).length;
    final currentPos = _flatQuestions.indexOf(unit.kind == 'batch' ? unit.questions.first : unit.question) + 1;
    final total = _flatQuestions.length;
    final timerColor =
        _globalRemaining.inSeconds <= 60 ? Colors.red : (_globalRemaining.inSeconds <= 300 ? Colors.orange : const Color(0xFFE50914));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!mounted || !shouldExit) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          foregroundColor: context.textColor,
          elevation: 0,
          title: Text('Question $currentPos of $total'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 4),
                Text(_fmt(_globalRemaining), style: TextStyle(fontWeight: FontWeight.bold, color: timerColor)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.list_alt_rounded), onPressed: _openSectionsSheet),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : answeredCount / total,
              backgroundColor: context.borderCol,
              color: const Color(0xFFE50914),
              minHeight: 4,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildUnitCard(unit, currentPos, total),
              ),
            ),
            _buildFooter(unit, isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(_RenderUnit unit, int num, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE50914),
                child: Text('$num', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(unit.typeName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textColor)),
              ),
              IconButton(
                icon: Icon(
                  _marked.contains(_currentSection) ? Icons.bookmark : Icons.bookmark_border,
                  color: _marked.contains(_currentSection) ? const Color(0xFFE50914) : context.subTextColor,
                ),
                onPressed: () => _toggleReview(_currentSection),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (unit.kind == 'batch') ..._buildBatch(unit),
          if (unit.kind == 'single') ..._buildSingle(unit),
          if (unit.kind == 'multiselect') ..._buildMultiSelect(unit),
          if (unit.kind == 'ranking') ..._buildRanking(unit),
        ],
      ),
    );
  }

  List<Widget> _buildBatch(_RenderUnit unit) {
    final widgets = <Widget>[];
    for (final q in unit.questions) {
      widgets.add(Text(q['text'] as String? ?? '',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: context.textColor)));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_buildAudioRow(q));
      widgets.add(_OptionsList(
        question: q,
        answers: _answers,
        disabled: _timedOut[q['_id']] ?? false,
        onSelect: (optId) => _recordAnswer(q['_id'] as String, optId),
      ));
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  List<Widget> _buildSingle(_RenderUnit unit) {
    final q = unit.question;
    final qid = q['_id'] as String;
    final widgets = <Widget>[];
    if (q['timeLimitSeconds'] != null && _questionTickerQid == qid) {
      widgets.add(Align(
        alignment: Alignment.centerRight,
        child: Text('${_fmt(_questionRemaining)} left', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ));
    }
    if ((q['instructionText'] as String?)?.isNotEmpty == true) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(q['instructionText'] as String, style: TextStyle(fontStyle: FontStyle.italic, color: context.subTextColor)),
      ));
    }
    if ((q['imageUrl'] as String?)?.isNotEmpty == true) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(q['imageUrl'] as String, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ));
    }
    widgets.add(Text(q['text'] as String? ?? '',
        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: context.textColor)));
    widgets.add(const SizedBox(height: 10));
    widgets.add(_buildAudioRow(q));
    widgets.add(_OptionsList(
      question: q,
      answers: _answers,
      disabled: _timedOut[qid] ?? false,
      onSelect: (optId) => _recordAnswer(qid, optId),
    ));
    return widgets;
  }

  List<Widget> _buildMultiSelect(_RenderUnit unit) {
    final q = unit.question;
    final qid = q['_id'] as String;
    return [
      Text(q['text'] as String? ?? '', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: context.textColor)),
      const SizedBox(height: 4),
      Text('Select all that apply.', style: TextStyle(fontSize: 12, color: context.subTextColor)),
      const SizedBox(height: 10),
      _buildAudioRow(q),
      _OptionsList(
        question: q,
        answers: _answers,
        checkbox: true,
        disabled: false,
        onToggle: (optId, checked) => _toggleMultiSelect(qid, optId, checked),
      ),
    ];
  }

  List<Widget> _buildRanking(_RenderUnit unit) {
    final q = unit.question;
    final qid = q['_id'] as String;
    final order = List<String>.from((_answers[qid] as List?)?.cast<String>() ??
        (q['options'] as List).map((o) => (o as Map)['_id'] as String));
    final optionById = {for (final o in (q['options'] as List)) (o as Map)['_id'] as String: o};
    return [
      Text(q['text'] as String? ?? '', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: context.textColor)),
      const SizedBox(height: 4),
      Text('Use the arrows to arrange in your preferred order (top = first).',
          style: TextStyle(fontSize: 12, color: context.subTextColor)),
      const SizedBox(height: 10),
      _buildAudioRow(q),
      ...order.asMap().entries.map((entry) {
        final i = entry.key;
        final optId = entry.value;
        final opt = optionById[optId];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: context.borderCol), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFE50914),
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(opt?['optionText'] as String? ?? '', style: TextStyle(color: context.textColor))),
              Column(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: i == 0 ? null : () => _moveRankingItem(qid, i, -1),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: i == order.length - 1 ? null : () => _moveRankingItem(qid, i, 1),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    ];
  }

  Widget _buildAudioRow(Map<String, dynamic> question) {
    final qid = question['_id'] as String;
    final isActive = _audio.activeQuestionId == qid;
    final state = isActive ? _audio.state : AssessmentAudioState.idle;
    final hasAnyAudioSource = (question['hasAudio'] == true && (question['audioUrl'] as String?)?.isNotEmpty == true) ||
        question['neuralAudio'] == true;

    if (!hasAnyAudioSource) return const SizedBox.shrink();
    if (isActive && state == AssessmentAudioState.unavailable) return const SizedBox.shrink();

    String label;
    IconData icon;
    VoidCallback? onTap;
    switch (state) {
      case AssessmentAudioState.loading:
        label = 'Loading...';
        icon = Icons.hourglass_bottom;
        onTap = null;
        break;
      case AssessmentAudioState.playing:
        label = 'Pause';
        icon = Icons.pause;
        onTap = () => _audio.togglePause();
        break;
      case AssessmentAudioState.paused:
        label = 'Resume';
        icon = Icons.play_arrow;
        onTap = () => _audio.togglePause();
        break;
      case AssessmentAudioState.ended:
        label = 'Replay';
        icon = Icons.replay;
        onTap = () => _audio.togglePause();
        break;
      case AssessmentAudioState.error:
        label = 'Play Question';
        icon = Icons.play_arrow;
        onTap = () => _audio.playQuestion(question, _token!);
        break;
      default:
        label = 'Play Question';
        icon = Icons.play_arrow;
        onTap = () => _audio.playQuestion(question, _token!);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE50914), side: const BorderSide(color: Color(0xFFE50914))),
          ),
          if (isActive && state != AssessmentAudioState.idle)
            OutlinedButton.icon(
              onPressed: () => _audio.stop(),
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: context.subTextColor, side: BorderSide(color: context.borderCol)),
            ),
          if (isActive && state == AssessmentAudioState.error)
            Text(_audio.errorMessage, style: const TextStyle(fontSize: 11, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildFooter(_RenderUnit unit, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.borderCol)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_unansweredMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_unansweredMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentSection == 0 ? null : _goPrev,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: isLast
                      ? AssessmentPrimaryButton(
                          label: _submitting ? 'Submitting...' : 'Submit Assessment',
                          loading: _submitting,
                          onPressed: () => _submit(auto: false),
                        )
                      : AssessmentPrimaryButton(label: 'Save & Continue', onPressed: _goNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  final Map<String, dynamic> question;
  final Map<String, dynamic> answers;
  final bool checkbox;
  final bool disabled;
  final void Function(String optionId)? onSelect;
  final void Function(String optionId, bool checked)? onToggle;

  const _OptionsList({
    required this.question,
    required this.answers,
    this.checkbox = false,
    required this.disabled,
    this.onSelect,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final qid = question['_id'] as String;
    final options = List<Map>.from(question['options'] as List);
    final selected = checkbox ? Set<String>.from((answers[qid] as List?)?.cast<String>() ?? const []) : null;
    return Column(
      children: options.map((opt) {
        final optId = opt['_id'] as String;
        final isSelected = checkbox ? selected!.contains(optId) : answers[qid] == optId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled
                ? null
                : () => checkbox ? onToggle?.call(optId, !isSelected) : onSelect?.call(optId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? const Color(0xFFE50914) : context.borderCol, width: isSelected ? 1.5 : 1),
                color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.08) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    checkbox
                        ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                        : (isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                    color: isSelected ? const Color(0xFFE50914) : context.subTextColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      opt['optionText'] as String? ?? '',
                      style: TextStyle(color: disabled ? context.subTextColor : context.textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
