import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import 'main.dart';
import 'ai_content_service.dart';

const Color _kAiRed = Color(0xFFE50914);

const List<MapEntry<String, String>> _kSavedCategories = [
  MapEntry('social_media', 'Social Media'),
  MapEntry('advertisement', 'Advertisement'),
  MapEntry('business', 'Business'),
  MapEntry('personal', 'Personal'),
  MapEntry('video_script', 'Video Script'),
  MapEntry('email', 'Email'),
  MapEntry('other', 'Other'),
];

String _categoryLabel(String? key) =>
    _kSavedCategories.firstWhere((c) => c.key == key, orElse: () => const MapEntry('other', 'Other')).value;

/// Lists the user's saved AI content — search, category filter, and
/// copy/share/edit/delete per item (FR-032).
class AiSavedContentScreen extends StatefulWidget {
  const AiSavedContentScreen({super.key});

  @override
  State<AiSavedContentScreen> createState() => _AiSavedContentScreenState();
}

class _AiSavedContentScreenState extends State<AiSavedContentScreen> {
  final AIContentService _service = AIContentService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _errorMessage;
  String? _selectedCategory; // null = All

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.listSaved(
        category: _selectedCategory,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = data;
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(Map<String, dynamic> item) async {
    await Clipboard.setData(ClipboardData(text: item['content'] as String? ?? ''));
    _showSnack('Copied!');
  }

  void _share(Map<String, dynamic> item) {
    Share.share(item['content'] as String? ?? '');
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Delete Saved Item?', style: TextStyle(color: context.textColor)),
        content: Text('This cannot be undone.', style: TextStyle(color: context.subTextColor)),
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
      await _service.deleteSaved(item['id'] as String);
      if (!mounted) return;
      setState(() => _items.removeWhere((i) => i['id'] == item['id']));
    } on AIContentServiceException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final titleController = TextEditingController(text: item['title'] as String? ?? '');
    final contentController = TextEditingController(text: item['content'] as String? ?? '');
    String selectedCategory = (item['category'] as String?) ?? 'other';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text('Edit Saved Content', style: TextStyle(color: context.textColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
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
                  items: _kSavedCategories
                      .map((c) => DropdownMenuItem(value: c.key, child: Text(c.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'other'),
                ),
                const SizedBox(height: 12.0),
                TextField(
                  controller: contentController,
                  maxLines: 6,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: 'Content',
                    labelStyle: TextStyle(color: context.subTextColor),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
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
    if (saved != true) return;
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      _showSnack('Title and content cannot be empty.');
      return;
    }
    try {
      final updated = await _service.updateSaved(
        id: item['id'] as String,
        title: title,
        content: content,
        category: selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((i) => i['id'] == item['id']);
        if (idx != -1) _items[idx] = updated;
      });
    } on AIContentServiceException catch (e) {
      _showSnack(e.message);
    }
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
              _buildCategoryChips(),
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
          Text('Saved Content', style: TextStyle(color: context.textColor, fontSize: 17.0, fontWeight: FontWeight.bold)),
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
                  hintText: 'Search saved content…',
                  hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.5),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
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

  Widget _buildCategoryChips() {
    Widget chip(String label, String? key) {
      final selected = _selectedCategory == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12.0)),
          selected: selected,
          selectedColor: _kAiRed.withOpacity(0.18),
          backgroundColor: context.cardBg,
          side: BorderSide(color: selected ? _kAiRed : context.borderCol),
          labelStyle: TextStyle(color: selected ? _kAiRed : context.textColor),
          onSelected: (_) {
            setState(() => _selectedCategory = key);
            _load();
          },
        ),
      );
    }

    return SizedBox(
      height: 42.0,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null),
          ..._kSavedCategories.map((c) => chip(c.value, c.key)),
        ],
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
    if (_items.isEmpty) {
      return Center(
        child: Text('No saved content yet.', style: TextStyle(color: context.subTextColor)),
      );
    }
    return RefreshIndicator(
      color: _kAiRed,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final title = (item['title'] as String?)?.trim();
    final content = (item['content'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (title == null || title.isEmpty) ? 'Untitled' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: _kAiRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  _categoryLabel(item['category'] as String?),
                  style: const TextStyle(color: _kAiRed, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.subTextColor, fontSize: 13.0, height: 1.4),
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              _iconAction(Icons.copy_rounded, 'Copy', () => _copy(item)),
              _iconAction(Icons.share_outlined, 'Share', () => _share(item)),
              _iconAction(Icons.edit_outlined, 'Edit', () => _edit(item)),
              _iconAction(Icons.delete_outline_rounded, 'Delete', () => _delete(item)),
            ],
          ),
        ],
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
}
