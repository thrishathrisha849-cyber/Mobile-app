import 'package:flutter/material.dart';

import 'main.dart';
import 'ai_content_service.dart';

const Color _kAiRed = Color(0xFFE50914);

/// Lists the user's Content Buddy AI conversations — most-recent-first,
/// with search, rename, and delete (FR-030). Tapping a conversation pops
/// this screen and returns its id so `ai_content_screen.dart` can resume it
/// (T037) — this screen owns no chat state of its own.
class AiChatHistoryScreen extends StatefulWidget {
  const AiChatHistoryScreen({super.key});

  @override
  State<AiChatHistoryScreen> createState() => _AiChatHistoryScreenState();
}

class _AiChatHistoryScreenState extends State<AiChatHistoryScreen> {
  final AIContentService _service = AIContentService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.listConversations(search: search);
      if (!mounted) return;
      setState(() {
        _conversations = data;
        _loading = false;
      });
    } on AIContentServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _rename(Map<String, dynamic> conversation) async {
    final controller = TextEditingController(text: conversation['title'] as String? ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Rename Conversation', style: TextStyle(color: context.textColor)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.textColor),
          decoration: InputDecoration(
            hintText: 'Conversation title',
            hintStyle: TextStyle(color: context.subTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: _kAiRed)),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty) return;
    try {
      await _service.renameConversation(conversation['id'] as String, newTitle);
      await _load(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
    } on AIContentServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Delete Conversation?', style: TextStyle(color: context.textColor)),
        content: Text(
          'This will permanently delete this conversation and its messages. This cannot be undone.',
          style: TextStyle(color: context.subTextColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: _kAiRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteConversation(conversation['id'] as String);
      if (!mounted) return;
      setState(() => _conversations.removeWhere((c) => c['id'] == conversation['id']));
    } on AIContentServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
              _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kAiRed, size: 20.0),
            onPressed: () => Navigator.pop(context),
          ),
          Text('Chat History', style: TextStyle(color: context.textColor, fontSize: 17.0, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: context.borderCol),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.subTextColor, size: 20.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.textColor, fontSize: 14.0),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search conversations…',
                  hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.5),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _load(search: value.trim().isEmpty ? null : value.trim()),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.subTextColor, size: 18.0),
                onPressed: () {
                  _searchController.clear();
                  _load();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kAiRed));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: context.subTextColor)),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Text('No conversations yet.', style: TextStyle(color: context.subTextColor)),
      );
    }
    return RefreshIndicator(
      color: _kAiRed,
      onRefresh: () => _load(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim()),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        itemCount: _conversations.length,
        itemBuilder: (context, index) => _buildTile(_conversations[index]),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> conversation) {
    final title = (conversation['title'] as String?)?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: context.borderCol),
      ),
      child: ListTile(
        leading: Container(
          width: 36.0,
          height: 36.0,
          decoration: const BoxDecoration(color: _kAiRed, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18.0),
        ),
        title: Text(
          (title == null || title.isEmpty) ? 'New Conversation' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.w600, fontSize: 14.0),
        ),
        subtitle: Text(
          _formatDate(conversation['updated_at'] as String?),
          style: TextStyle(color: context.subTextColor, fontSize: 11.5),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.subTextColor),
          color: context.cardBg,
          onSelected: (value) {
            if (value == 'rename') _rename(conversation);
            if (value == 'delete') _delete(conversation);
          },
          itemBuilder: (menuContext) => [
            PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: context.textColor))),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: context.textColor))),
          ],
        ),
        onTap: () => Navigator.pop(context, conversation['id'] as String),
      ),
    );
  }
}
