import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'main.dart';
import 'ai_content_service.dart';
import 'ai_recording_controller.dart';
import 'ai_chat_history_screen.dart';
import 'ai_saved_content_screen.dart';

const Color _kAiRed = Color(0xFFE50914);

// Client-side mirror of imageUploadService.js's limits (plan.md §2) — fast
// feedback before even attempting the upload; the backend re-validates and
// compresses again regardless, so this is a UX nicety, not the sole guard.
const int _kMaxImageBytes = 8 * 1024 * 1024;
const List<String> _kAllowedImageExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

// FR-005's exact required copy — shown on both a plain denial and a
// "permanently denied" (asked before) status, since the spec doesn't
// distinguish the two.
const String _kMicPermissionDeniedMessage =
    'Microphone permission is required to record your request. Please enable it from your device settings.';

// FR-034's Thanglish loading/progress copy, one per request phase.
const String _kLoadingSending = 'Ungalukku content create pannitu iruken... 🎨';
const String _kLoadingAnalyzingImage = 'Ungal photo-va paathutu, adhukku content create pannuren... 🖼️';
const String _kLoadingTranscribing = 'Ungal voice-ah text-ah convert pannitu iruken... 🎙️';

/// "Content Buddy AI" — the AI Content Creation Assistant chat screen.
///
/// Phase C (text-first) + Phase D (image) + Phase E (voice) per
/// specs/001-ai-content-assistant/tasks.md: text, image, and voice
/// send/receive/quick-actions/history-scaffold. Chat History gets a real
/// screen in Phase F (T035/T037); New Chat is fully functional now since it
/// needs nothing else.
class AIContentScreen extends StatefulWidget {
  const AIContentScreen({super.key});

  @override
  State<AIContentScreen> createState() => _AIContentScreenState();
}

class _AIContentScreenState extends State<AIContentScreen> {
  final AIContentService _service = AIContentService.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Each entry: {sender: 'user'|'assistant', message, status?, errorMessage?, suggestions?}
  final List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  bool _isSending = false;
  AICancelToken? _activeCancelToken;
  File? _selectedImage;

  final AiRecordingController _recordingController = AiRecordingController.instance;
  final List<double> _waveformHistory = [];
  bool _isTranscribing = false;

  // Optional customisation (T024) — never blocks sending if left unset (FR-026).
  String? _selectedContentType;
  String? _selectedTone;
  String? _selectedLanguage;
  String? _selectedLength;

  static const List<MapEntry<String, String>> _contentTypes = [
    MapEntry('reel_script', 'Reel Script'),
    MapEntry('youtube_script', 'YouTube Script'),
    MapEntry('caption', 'Caption'),
    MapEntry('advertisement', 'Advertisement'),
    MapEntry('product_description', 'Product Description'),
    MapEntry('whatsapp_message', 'WhatsApp Message'),
    MapEntry('email', 'Email'),
    MapEntry('blog', 'Blog'),
    MapEntry('story', 'Story'),
    MapEntry('voiceover_script', 'Voice-over Script'),
    MapEntry('sales_script', 'Sales Script'),
    MapEntry('custom', 'Custom'),
  ];

  static const List<MapEntry<String, String>> _tones = [
    MapEntry('friendly', 'Friendly'),
    MapEntry('funny', 'Funny'),
    MapEntry('professional', 'Professional'),
    MapEntry('emotional', 'Emotional'),
    MapEntry('motivational', 'Motivational'),
    MapEntry('casual', 'Casual'),
    MapEntry('luxury', 'Luxury'),
    MapEntry('energetic', 'Energetic'),
    MapEntry('simple', 'Simple'),
    MapEntry('bold', 'Bold'),
    MapEntry('sales_focused', 'Sales-focused'),
    MapEntry('custom', 'Custom'),
  ];

  static const List<MapEntry<String, String>> _languages = [
    MapEntry('english', 'English'),
    MapEntry('tamil', 'Tamil'),
    MapEntry('thanglish', 'Thanglish'),
    MapEntry('hindi', 'Hindi'),
    MapEntry('auto', 'Auto Detect'),
  ];

  static const List<MapEntry<String, String>> _lengths = [
    MapEntry('short', 'Short'),
    MapEntry('medium', 'Medium'),
    MapEntry('long', 'Long'),
  ];

  // Mirrors admin-app/services/savedContentService.js's VALID_CATEGORIES.
  static const List<MapEntry<String, String>> _saveCategories = [
    MapEntry('social_media', 'Social Media'),
    MapEntry('advertisement', 'Advertisement'),
    MapEntry('business', 'Business'),
    MapEntry('personal', 'Personal'),
    MapEntry('video_script', 'Video Script'),
    MapEntry('email', 'Email'),
    MapEntry('other', 'Other'),
  ];

  static const List<_SuggestionCard> _suggestionCards = [
    _SuggestionCard(Icons.movie_creation_outlined, 'Create a Reel Script', 'Create a Reel script for '),
    _SuggestionCard(Icons.camera_alt_outlined, 'Write an Instagram Caption', 'Write an Instagram caption for '),
    _SuggestionCard(Icons.campaign_outlined, 'Generate an Ad Copy', 'Generate an ad copy for '),
    _SuggestionCard(Icons.ondemand_video_outlined, 'Create a YouTube Script', 'Create a YouTube script about '),
    _SuggestionCard(Icons.mail_outline_rounded, 'Write a Professional Message', 'Write a professional message about '),
    _SuggestionCard(Icons.sentiment_very_satisfied_outlined, 'Make It Funny', 'Make this funny: '),
    _SuggestionCard(Icons.image_outlined, 'Create Content from Image', 'Create content based on this: '),
    _SuggestionCard(Icons.mic_none_rounded, 'Convert Voice Idea into Script', 'Convert this idea into a script: '),
  ];

  static const List<MapEntry<String, String>> _quickActions = [
    MapEntry('Make Shorter', 'Make this shorter.'),
    MapEntry('Make Longer', 'Make this longer with more detail.'),
    MapEntry('Make Friendly', 'Rewrite this in a more friendly tone.'),
    MapEntry('Make Funny', 'Rewrite this in a funnier, more humorous tone.'),
    MapEntry('Make Professional', 'Rewrite this in a more professional tone.'),
    MapEntry('Add Emojis', 'Add suitable emojis to this.'),
    MapEntry('Remove Emojis', 'Remove all emojis from this.'),
    MapEntry('Create Another Version', 'Give me another version of this with a different approach.'),
  ];

  @override
  void initState() {
    super.initState();
    _recordingController.onCapReached = _onRecordingCapReached;
  }

  @override
  void dispose() {
    _recordingController.onCapReached = null;
    if (_recordingController.state != AiRecordingState.idle) {
      _recordingController.cancelRecording();
    }
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startNewChat() {
    if (_isSending) _activeCancelToken?.cancel();
    setState(() {
      _messages.clear();
      _conversationId = null;
      _isSending = false;
      _activeCancelToken = null;
    });
  }

  Future<void> _openChatHistory() async {
    final selectedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AiChatHistoryScreen()),
    );
    if (selectedId != null) {
      await _loadConversation(selectedId);
    }
  }

  /// Resumes an existing conversation, replacing the current message list
  /// with its full history (FR-031) — used when returning from Chat History.
  Future<void> _loadConversation(String conversationId) async {
    if (_isSending) _activeCancelToken?.cancel();
    setState(() {
      _messages.clear();
      _conversationId = conversationId;
      _isSending = false;
      _activeCancelToken = null;
    });
    try {
      final history = await _service.getMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history.map((m) => {
              'sender': m['sender'] as String,
              'message': (m['message'] as String?) ?? '',
              'status': 'sent',
              if (m['image_url'] != null) 'imageUrl': m['image_url'] as String,
            }));
      });
      _scrollToBottom();
    } on AIContentServiceException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    }
  }

  Future<void> _sendMessage(String rawText, {String inputType = 'text', File? image}) async {
    final text = rawText.trim();
    // FR-002 empty guard (text OR an attached image counts as content) + FR-037 duplicate-tap guard.
    if ((text.isEmpty && image == null) || _isSending) return;

    final userMsgIndex = _messages.length;
    setState(() {
      _messages.add({
        'sender': 'user',
        'message': text,
        'status': 'sending',
        if (image != null) 'imagePath': image.path,
      });
      _isSending = true;
    });
    _textController.clear();
    setState(() => _selectedImage = null);
    _scrollToBottom();

    final cancelToken = AICancelToken();
    _activeCancelToken = cancelToken;

    try {
      final result = await _service.createContent(
        message: text,
        inputType: image != null ? 'image' : inputType,
        image: image,
        contentType: _selectedContentType,
        tone: _selectedTone,
        language: _selectedLanguage,
        length: _selectedLength,
        conversationId: _conversationId,
        cancelToken: cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _messages[userMsgIndex]['status'] = 'sent';
        _conversationId = result['conversationId'] as String?;
        _messages.add({
          'sender': 'assistant',
          'message': result['content'] as String,
        });
        _isSending = false;
        _activeCancelToken = null;
      });
      _scrollToBottom();
    } on AIContentServiceException catch (e) {
      if (!mounted) return;
      if (e.conversationId != null) _conversationId = e.conversationId;
      setState(() {
        _messages[userMsgIndex]['status'] = e.code == 'cancelled' ? 'cancelled' : 'failed';
        _messages[userMsgIndex]['errorMessage'] = e.message;
        _isSending = false;
        _activeCancelToken = null;
      });
      // FR-035: the inline bubble only shows a generic "Failed. Tap to
      // retry." (it can't fit the distinct per-cause message without
      // redesigning the bubble) — surface the actual friendly reason here,
      // e.g. "no internet" vs "image too large" vs "usage limit reached"
      // read genuinely differently. Not shown for a user-initiated Stop.
      if (e.code != 'cancelled') _showSnack(e.message);
    }
  }

  void _retryMessage(int index) {
    final text = _messages[index]['message'] as String;
    final imagePath = _messages[index]['imagePath'] as String?;
    setState(() => _messages.removeAt(index));
    _sendMessage(text, image: imagePath != null ? File(imagePath) : null);
  }

  void _stopGeneration() {
    _activeCancelToken?.cancel();
  }

  void _insertSuggestion(String prompt) {
    _textController.text = prompt;
    _textController.selection = TextSelection.collapsed(offset: prompt.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied!');
  }

  void _shareMessage(String text) {
    Share.share(text);
  }

  // ── Save (Phase F, T038) ────────────────────────────────────────────────

  Future<void> _showSaveDialog(String content) async {
    final defaultTitle = content.trim().length > 40 ? '${content.trim().substring(0, 40)}…' : content.trim();
    final titleController = TextEditingController(text: defaultTitle);
    String selectedCategory = 'other';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text('Save Content', style: TextStyle(color: context.textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: context.subTextColor),
                ),
              ),
              const SizedBox(height: 12.0),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: context.cardBg,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: context.subTextColor),
                ),
                style: TextStyle(color: context.textColor),
                items: _saveCategories.map((c) => DropdownMenuItem(value: c.key, child: Text(c.value))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'other'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save', style: TextStyle(color: _kAiRed)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('Please enter a title.');
      return;
    }
    try {
      await _service.saveContent(
        conversationId: _conversationId,
        title: title,
        content: content,
        category: selectedCategory,
      );
      _showSnack('Saved!');
    } on AIContentServiceException catch (e) {
      _showSnack(e.message);
    }
  }

  void _editRequest(int assistantIndex) {
    // Find the user message that produced this response (immediately before it).
    for (int i = assistantIndex - 1; i >= 0; i--) {
      if (_messages[i]['sender'] == 'user') {
        _insertSuggestion(_messages[i]['message'] as String);
        return;
      }
    }
  }

  Future<void> _pickOption(String title, List<MapEntry<String, String>> options, String? current, ValueChanged<String?> onSelected) async {
    // isScrollControlled + a capped-height scrollable ListView (rather than a
    // plain non-scrolling Column) — the longer option lists (e.g. Content
    // Type's 12 entries) otherwise overflow past the sheet's bounds on
    // small screens (confirmed on a 320x640 test device: "BOTTOM OVERFLOWED
    // BY 431 PIXELS"). FR-040 requires no overflow on small screens.
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(title,
                      style: TextStyle(color: context.textColor, fontSize: 16.0, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: Text('Any (let AI decide)', style: TextStyle(color: context.subTextColor)),
                  trailing: current == null ? const Icon(Icons.check, color: _kAiRed) : null,
                  onTap: () {
                    onSelected(null);
                    Navigator.pop(sheetContext);
                  },
                ),
                ...options.map((opt) => ListTile(
                      title: Text(opt.value, style: TextStyle(color: context.textColor)),
                      trailing: current == opt.key ? const Icon(Icons.check, color: _kAiRed) : null,
                      onTap: () {
                        onSelected(opt.key);
                        Navigator.pop(sheetContext);
                      },
                    )),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      resizeToAvoidBottomInset: true, // keeps input above the keyboard (FR-038)
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.themeGradients,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
              ),
              _buildFilterChips(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kAiRed, size: 20.0),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 38.0,
            height: 38.0,
            decoration: const BoxDecoration(color: _kAiRed, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20.0),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Content Buddy AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textColor, fontSize: 15.5, fontWeight: FontWeight.bold)),
                Text('Your creative content assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.subTextColor, fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Saved Content',
            icon: Icon(Icons.bookmark_border_rounded, color: context.textColor, size: 22.0),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSavedContentScreen()),
            ),
          ),
          IconButton(
            tooltip: 'New Chat',
            icon: Icon(Icons.add_comment_outlined, color: context.textColor, size: 22.0),
            onPressed: _startNewChat,
          ),
          IconButton(
            tooltip: 'Chat History',
            icon: Icon(Icons.history_rounded, color: context.textColor, size: 22.0),
            onPressed: _openChatHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12.0),
          Center(
            child: Container(
              width: 64.0,
              height: 64.0,
              decoration: const BoxDecoration(color: _kAiRed, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32.0),
            ),
          ),
          const SizedBox(height: 18.0),
          Text(
            'Hi! Naan unga Content Buddy AI. Neenga voice-la sollalam, text-la type pannalam, illa image upload pannalam. '
            'Ungalukku thevaiyana script, caption, post, ad copy, message ellame create panniduven.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textColor, fontSize: 14.5, height: 1.5),
          ),
          const SizedBox(height: 24.0),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12.0,
            crossAxisSpacing: 12.0,
            childAspectRatio: 1.35,
            children: _suggestionCards
                .map((card) => _buildSuggestionCard(card))
                .toList(),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(_SuggestionCard card) {
    return Semantics(
      button: true,
      label: card.title,
      child: GestureDetector(
      onTap: () => _insertSuggestion(card.prompt),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: context.borderCol, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(card.icon, color: _kAiRed, size: 24.0),
            const SizedBox(height: 8.0),
            Text(
              card.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textColor, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMessageList() {
    // FR-034: a distinct "generating" vs "analyzing image" loading bubble
    // while a request is in flight — the last message is always the
    // 'sending' user turn that triggered it (see _sendMessage).
    final showLoading = _isSending && _messages.isNotEmpty && _messages.last['status'] == 'sending';
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      itemCount: _messages.length + (showLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (showLoading && index == _messages.length) {
          final hasImage = _messages.last['imagePath'] != null || _messages.last['imageUrl'] != null;
          return _buildLoadingBubble(hasImage ? _kLoadingAnalyzingImage : _kLoadingSending);
        }
        final item = _messages[index];
        if (item['sender'] == 'user') {
          return _buildUserBubble(item, index);
        }
        return _buildAssistantBubble(item, index);
      },
    );
  }

  Widget _buildLoadingBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
          border: Border.all(color: context.borderCol, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14.0,
              height: 14.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: _kAiRed),
            ),
            const SizedBox(width: 10.0),
            Flexible(child: Text(text, style: TextStyle(color: context.textColor, fontSize: 13.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(Map<String, dynamic> item, int index) {
    final status = item['status'] as String?;
    final isFailed = status == 'failed' || status == 'cancelled';
    final imagePath = item['imagePath'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    final message = item['message'] as String;
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(8.0),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isFailed ? _kAiRed.withOpacity(0.15) : _kAiRed,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomLeft: Radius.circular(16.0),
              ),
              border: isFailed ? Border.all(color: _kAiRed, width: 1.0) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // A freshly-attached image is a local File (imagePath); an
                // image loaded from a resumed conversation's history (T037)
                // only has the server's public Storage URL (imageUrl) — no
                // local file exists for it.
                if (imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.file(File(imagePath), width: 180.0, height: 180.0, fit: BoxFit.cover),
                  )
                else if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.network(imageUrl, width: 180.0, height: 180.0, fit: BoxFit.cover),
                  ),
                if ((imagePath != null || imageUrl != null) && message.isNotEmpty) const SizedBox(height: 8.0),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    child: Text(
                      message,
                      style: TextStyle(color: isFailed ? _kAiRed : Colors.white, fontSize: 14.0),
                    ),
                  ),
              ],
            ),
          ),
          if (status == 'sending')
            Padding(
              padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
              child: SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: context.subTextColor),
              ),
            ),
          if (isFailed)
            Padding(
              padding: const EdgeInsets.only(right: 4.0, bottom: 8.0),
              child: GestureDetector(
                onTap: () => _retryMessage(index),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: _kAiRed, size: 13.0),
                    const SizedBox(width: 4.0),
                    Text(
                      status == 'cancelled' ? 'Stopped. Tap to retry.' : 'Failed. Tap to retry.',
                      style: const TextStyle(color: _kAiRed, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(Map<String, dynamic> item, int index) {
    final message = item['message'] as String;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
          border: Border.all(color: context.borderCol, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message, style: TextStyle(color: context.textColor, fontSize: 14.0, height: 1.4)),
            const SizedBox(height: 10.0),
            Row(
              children: [
                _iconAction(Icons.copy_rounded, 'Copy', () => _copyMessage(message)),
                _iconAction(Icons.share_outlined, 'Share', () => _shareMessage(message)),
                _iconAction(Icons.bookmark_border_rounded, 'Save', () => _showSaveDialog(message)),
                _iconAction(Icons.refresh_rounded, 'Regenerate',
                    () => _sendMessage('Please provide a different variation of your previous response.')),
                _iconAction(Icons.edit_outlined, 'Edit Request', () => _editRequest(index)),
              ],
            ),
            const SizedBox(height: 6.0),
            SizedBox(
              height: 32.0,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._quickActions.map((qa) => _quickActionChip(qa.key, qa.value)),
                  _translateChip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18.0, color: context.subTextColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34.0, minHeight: 34.0),
      onPressed: onTap,
    );
  }

  Widget _quickActionChip(String label, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        backgroundColor: context.cardBg,
        side: BorderSide(color: context.borderCol),
        labelStyle: TextStyle(color: context.textColor),
        onPressed: () => _sendMessage(instruction),
      ),
    );
  }

  Widget _translateChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: const Text('Translate', style: TextStyle(fontSize: 11.5)),
        backgroundColor: context.cardBg,
        side: BorderSide(color: context.borderCol),
        labelStyle: TextStyle(color: context.textColor),
        onPressed: () async {
          await _pickOption('Translate to', _languages, null, (value) {
            if (value == null) return;
            final label = _languages.firstWhere((l) => l.key == value).value;
            _sendMessage('Translate this to $label.');
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    Widget chip(String label, String? selectedKey, List<MapEntry<String, String>> options, ValueChanged<String?> onSelected) {
      final display = selectedKey == null
          ? label
          : options.firstWhere((o) => o.key == selectedKey, orElse: () => MapEntry('', label)).value;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
          label: Text(display, style: const TextStyle(fontSize: 12.0)),
          selected: selectedKey != null,
          selectedColor: _kAiRed.withOpacity(0.18),
          backgroundColor: context.cardBg,
          side: BorderSide(color: selectedKey != null ? _kAiRed : context.borderCol),
          labelStyle: TextStyle(color: selectedKey != null ? _kAiRed : context.textColor),
          onSelected: (_) => _pickOption(label, options, selectedKey, onSelected),
        ),
      );
    }

    return SizedBox(
      height: 42.0,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        scrollDirection: Axis.horizontal,
        children: [
          chip('Content Type', _selectedContentType, _contentTypes, (v) => setState(() => _selectedContentType = v)),
          chip('Tone', _selectedTone, _tones, (v) => setState(() => _selectedTone = v)),
          chip('Language', _selectedLanguage, _languages, (v) => setState(() => _selectedLanguage = v)),
          chip('Length', _selectedLength, _lengths, (v) => setState(() => _selectedLength = v)),
        ],
      ),
    );
  }

  // ── Image attach (Phase D) ──────────────────────────────────────────────

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8.0),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: context.textColor),
                title: Text('Choose from Gallery', style: TextStyle(color: context.textColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: context.textColor),
                title: Text('Take Photo', style: TextStyle(color: context.textColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8.0),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      // FR-011: compress at pick time (resize + re-encode) so we never even
      // build a multipart request from an oversized/raw file. The backend
      // (imageUploadService.js) compresses again regardless — this is a
      // bandwidth/UX nicety, not the only safeguard.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final ext = picked.path.toLowerCase().substring(picked.path.lastIndexOf('.'));
    if (!_kAllowedImageExtensions.contains(ext)) {
      _showSnack('Please attach a JPG, PNG, or WEBP image.'); // FR-010
      return;
    }
    final file = File(picked.path);
    final size = await file.length();
    if (size > _kMaxImageBytes) {
      _showSnack('That image is too large. Please attach an image under 8MB.'); // FR-010
      return;
    }

    setState(() => _selectedImage = file);
  }

  void _removeSelectedImage() {
    setState(() => _selectedImage = null);
  }

  // ── Voice input (Phase E) ───────────────────────────────────────────────

  Future<void> _onMicPressed() async {
    if (_isSending) return;
    final alreadyGranted = await Permission.microphone.status;
    if (alreadyGranted.isGranted) {
      await _beginRecording();
      return;
    }
    final result = await Permission.microphone.request(); // FR-004
    if (!mounted) return;
    if (result.isGranted) {
      await _beginRecording();
    } else {
      _showSnack(_kMicPermissionDeniedMessage); // FR-005
    }
  }

  Future<void> _beginRecording() async {
    _waveformHistory.clear();
    final started = await _recordingController.start();
    if (!mounted) return;
    if (!started) {
      // speech_to_text itself couldn't initialize (e.g. no recognizer
      // available on this device/emulator, or the OS-level prompt it
      // separately triggers was denied) — same required copy applies.
      _showSnack(_kMicPermissionDeniedMessage);
    }
  }

  void _cancelRecording() {
    _waveformHistory.clear();
    _recordingController.cancelRecording();
  }

  void _togglePauseResume() {
    if (_recordingController.isPaused) {
      _recordingController.resume();
    } else {
      _recordingController.pause();
    }
  }

  Future<void> _finishRecording() async {
    setState(() => _isTranscribing = true); // FR-034: transcribing-phase loading copy
    final transcript = await _recordingController.stopAndFinish();
    _recordingController.reset();
    _waveformHistory.clear();
    if (!mounted) return;
    setState(() => _isTranscribing = false);
    if (transcript.trim().isEmpty) {
      _showSnack('No speech was recognized. Please try again.');
      return;
    }
    // FR-007: transcript goes into the same editable text field used for
    // typed input — reusing the existing text-send pipeline, never sent
    // silently (T033).
    setState(() {
      _textController.text = transcript;
      _textController.selection = TextSelection.collapsed(offset: transcript.length);
    });
    _inputFocusNode.requestFocus();
  }

  void _onRecordingCapReached() {
    _showSnack('Maximum recording length reached (3 minutes).');
    _finishRecording();
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 0.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.file(_selectedImage!, width: 72.0, height: 72.0, fit: BoxFit.cover),
            ),
            Positioned(
              // Outer box is 44x44 (adequate tap target, FR-039) with the
              // same 22x22 red circle visually centered where it was before.
              top: -19.0,
              right: -19.0,
              child: Semantics(
                button: true,
                label: 'Remove image',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _removeSelectedImage,
                  child: SizedBox(
                    width: 44.0,
                    height: 44.0,
                    child: Center(
                      child: Container(
                        width: 22.0,
                        height: 22.0,
                        decoration: const BoxDecoration(color: _kAiRed, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 15.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return AnimatedBuilder(
      animation: _recordingController,
      builder: (context, _) {
        final recState = _recordingController.state;
        final isRecording = recState == AiRecordingState.listening || recState == AiRecordingState.paused;
        if (isRecording) {
          _waveformHistory.add(_recordingController.soundLevel);
          if (_waveformHistory.length > 28) _waveformHistory.removeAt(0);
        }
        return Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            border: Border(top: BorderSide(color: context.borderCol, width: 1.0)),
          ),
          child: SafeArea(
            top: false,
            child: _isTranscribing
                ? _buildTranscribingPanel()
                : (isRecording ? _buildRecordingPanel() : _buildTextInputRow()),
          ),
        );
      },
    );
  }

  Widget _buildTranscribingPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          const SizedBox(
            width: 16.0,
            height: 16.0,
            child: CircularProgressIndicator(strokeWidth: 2.0, color: _kAiRed),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(_kLoadingTranscribing, style: TextStyle(color: context.textColor, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPanel() {
    final seconds = _recordingController.elapsedSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final isPaused = _recordingController.isPaused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fiber_manual_record_rounded,
                  color: isPaused ? context.subTextColor : _kAiRed, size: 14.0),
              const SizedBox(width: 8.0),
              Text('$mm:$ss',
                  style: TextStyle(color: context.textColor, fontSize: 14.0, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12.0),
              Expanded(child: _buildWaveform()),
              const SizedBox(width: 8.0),
              Text(isPaused ? 'Paused' : 'Listening…',
                  style: TextStyle(color: context.subTextColor, fontSize: 12.0)),
            ],
          ),
          const SizedBox(height: 14.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _recordingControl(Icons.close_rounded, 'Cancel', _cancelRecording, context.subTextColor),
              _recordingControl(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                isPaused ? 'Resume' : 'Pause',
                _togglePauseResume,
                context.textColor,
              ),
              _recordingControl(Icons.check_circle_rounded, 'Stop', _finishRecording, _kAiRed, filled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 28.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _waveformHistory.isEmpty
            ? [Container(height: 3.0, color: context.borderCol)]
            : _waveformHistory.map((level) {
                // speech_to_text's sound-level range/units differ per
                // platform (see its onSoundLevelChange docs) — this is a
                // rough visual heuristic, not a calibrated meter.
                final normalized = ((level + 2.0) / 12.0).clamp(0.08, 1.0);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.0),
                    height: 24.0 * normalized,
                    decoration: BoxDecoration(
                      color: _kAiRed.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Widget _recordingControl(IconData icon, String label, VoidCallback onTap, Color color, {bool filled = false}) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: filled ? _kAiRed : context.scaffoldBg,
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: context.borderCol),
            ),
            child: Icon(icon, color: filled ? Colors.white : color, size: 22.0),
          ),
          const SizedBox(height: 4.0),
          Text(label, style: TextStyle(color: context.subTextColor, fontSize: 11.0)),
        ],
      ),
      ),
    );
  }

  Widget _buildTextInputRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePreview(),
        Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
          child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach image',
                    icon: Icon(Icons.image_outlined, color: context.subTextColor),
                    onPressed: _showImageSourceSheet,
                  ),
                  IconButton(
                    tooltip: 'Record voice',
                    icon: Icon(Icons.mic_none_rounded, color: context.subTextColor),
                    onPressed: _onMicPressed,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: context.scaffoldBg,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _inputFocusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(color: context.textColor, fontSize: 14.0),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Tell me what content you want to create…',
                          hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.5),
                        ),
                        onSubmitted: (_) => _sendMessage(_textController.text, image: _selectedImage),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  _isSending
                      ? IconButton(
                          tooltip: 'Stop',
                          icon: const Icon(Icons.stop_circle_rounded, color: _kAiRed, size: 32.0),
                          onPressed: _stopGeneration,
                        )
                      : IconButton(
                          tooltip: 'Send',
                          icon: const Icon(Icons.send_rounded, color: _kAiRed, size: 26.0),
                          onPressed: () => _sendMessage(_textController.text, image: _selectedImage),
                        ),
                ],
              ),
            ),
          ],
        );
  }
}

class _SuggestionCard {
  final IconData icon;
  final String title;
  final String prompt;
  const _SuggestionCard(this.icon, this.title, this.prompt);
}
