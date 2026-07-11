import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'profile.dart';
import 'ebook_service.dart';

const Color _kEbookRed = Color(0xFFD30814);

// ────────────────────────────────────────────────────────────────
// Shared building blocks (loading/empty/error states, cover image
// with a themed fallback, category chip) reused across every
// E-book screen so the look stays identical everywhere.
// ────────────────────────────────────────────────────────────────

Widget buildEbookLoadingState(BuildContext context) {
  return Center(
      child: CircularProgressIndicator(color: _kEbookRed.withOpacity(0.85)));
}

Widget buildEbookEmptyState(BuildContext context, String message,
    {IconData icon = Icons.menu_book_rounded}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 40.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64.0,
          height: 64.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kEbookRed.withOpacity(0.08),
            border: Border.all(color: _kEbookRed.withOpacity(0.3)),
          ),
          child: Icon(icon, color: _kEbookRed, size: 28.0),
        ),
        const SizedBox(height: 14.0),
        Text(message,
            style: TextStyle(
                color: context.subTextColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget buildEbookErrorState(
  BuildContext context,
  String message,
  VoidCallback onRetry, {
  String retryLabel = 'Retry',
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.0,
            height: 64.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kEbookRed.withOpacity(0.08),
              border: Border.all(color: _kEbookRed.withOpacity(0.3)),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: _kEbookRed, size: 28.0),
          ),
          const SizedBox(height: 14.0),
          Text('Something went wrong',
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6.0),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subTextColor, fontSize: 12.5)),
          const SizedBox(height: 18.0),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kEbookRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
            ),
            child: Text(retryLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

Widget buildEbookCategoryChip(
    BuildContext context, String label, bool isSelected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isSelected ? _kEbookRed : context.cardBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
            color: isSelected ? Colors.transparent : context.borderCol),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : context.textColor,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

List<Color> _coverPaletteFor(String seed) {
  const palettes = [
    [Color(0xFF220304), Color(0xFF110101)],
    [Color(0xFF1E293B), Color(0xFF0F172A)],
    [Color(0xFF111827), Color(0xFF030712)],
    [Color(0xFF0F172A), Color(0xFF020617)],
    [Color(0xFF065F46), Color(0xFF022C22)],
  ];
  final index = seed.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length;
  return palettes[index];
}

/// Network book cover with a themed gradient+title fallback for missing or
/// broken images — replaces the old bundled `assets/images/ebook covers/*`
/// artwork now that covers come from the admin panel.
class EbookCover extends StatelessWidget {
  final String? url;
  final String title;
  final double width;
  final double height;
  final double radius;

  const EbookCover({
    super.key,
    required this.url,
    required this.title,
    required this.width,
    required this.height,
    this.radius = 8.0,
  });

  Widget _fallback() {
    final colors = _coverPaletteFor(title.isEmpty ? 'Book' : title);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[0].withOpacity(0.9), colors[1]],
        ),
      ),
      padding: const EdgeInsets.all(10.0),
      alignment: Alignment.bottomLeft,
      child: Text(
        title.toUpperCase(),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.w900,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (url == null || url!.isEmpty)
          ? _fallback()
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                color: Colors.grey.withOpacity(0.15),
              ),
              errorWidget: (context, url, error) => _fallback(),
            ),
    );
  }
}

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  DateTime? dt;
  if (raw is String) dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

/// A "Your Library" row: cover, title/author, progress bar + status label,
/// and a bookmark toggle. Shared by the Home screen's Your Library section
/// and the standalone Saved Books screen so both look identical.
Widget buildLibraryRow(
  BuildContext context,
  Map<String, dynamic> book, {
  required VoidCallback onTap,
  required Future<void> Function() onBookmarkToggle,
}) {
  final bool completed = book['completed'] == true;
  final int currentPage = (book['currentPage'] as int?) ?? 0;
  final double? percent =
      currentPage > 0 ? (book['progress'] as double?) : null;
  final String label = completed
      ? 'FINISHED'
      : currentPage > 0
          ? '${book['progressPercent']}% READ'
          : 'NOT STARTED';
  final String? pagesLeftText =
      completed ? 'Completed' : (book['pagesLeftText'] as String?);
  final bool showResume = currentPage > 0 && !completed;
  final bool isBookmarked = book['isBookmarked'] == true;

  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          EbookCover(
            url: book['cover'] as String?,
            title: book['title'] as String? ?? '',
            width: 50.0,
            height: 70.0,
            radius: 6.0,
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.textColor,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3.0),
                Text(
                  (book['author'] as String?)?.trim().isNotEmpty == true
                      ? book['author'] as String
                      : 'Unknown Author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.subTextColor, fontSize: 11.5),
                ),
                const SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: label == 'FINISHED'
                            ? const Color(0xFFFCA5A5)
                            : label == 'NOT STARTED'
                                ? context.subTextColor.withOpacity(0.6)
                                : const Color(0xFFEF4444),
                        fontSize: 9.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (pagesLeftText != null && pagesLeftText.isNotEmpty)
                      Text(
                        pagesLeftText,
                        style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                if (percent != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6.0),
                    width: double.infinity,
                    height: 3.0,
                    decoration: BoxDecoration(
                      color: context.subTextColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              completed ? const Color(0xFFFCA5A5) : _kEbookRed,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          if (showResume)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFCA5A5).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                    color: const Color(0xFFFCA5A5).withOpacity(0.3),
                    width: 0.8),
              ),
              child: const Text('Resume',
                  style: TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold)),
            ),
          if (completed)
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFFFCA5A5), size: 18.0),
          const SizedBox(width: 8.0),
          GestureDetector(
            onTap: onBookmarkToggle,
            child: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color:
                  isBookmarked ? const Color(0xFFFCA5A5) : context.subTextColor,
              size: 20.0,
            ),
          ),
        ],
      ),
    ),
  );
}

// ────────────────────────────────────────────────────────────────
// E-book Home — Featured Arrivals, category tabs, Your Library,
// Discover CTA banner.
// ────────────────────────────────────────────────────────────────

class EBooksLibraryScreen extends StatefulWidget {
  const EBooksLibraryScreen({super.key});

  @override
  State<EBooksLibraryScreen> createState() => _EBooksLibraryScreenState();
}

class _EBooksLibraryScreenState extends State<EBooksLibraryScreen> {
  bool _isLoading = true;
  String? _error;
  String? _userId;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _library = [];
  Map<String, dynamic>? _banner;

  // The DB-backed catalog list shown below the chips (see
  // _refreshCatalogResults) — every active book for "All", or narrowed to
  // one category/search term. Never the user's bookmarked "Your Library"
  // items (that list is usually empty/small and has its own dedicated
  // SavedBooksScreen) — using it here was why "All" looked broken.
  List<Map<String, dynamic>>? _catalogResults;
  bool _catalogLoading = false;

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _initProfileImage();
  }

  // Ensures the top-right avatar shows the real logged-in profile photo
  // even if this page is opened before Profile has ever loaded it — reuses
  // the same shared loader/field every other screen's avatar reads, rather
  // than assuming it was already populated elsewhere first.
  Future<void> _initProfileImage() async {
    await ProfileScreen.ensureProfileImageLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = await EBookService.instance.getOrCreateAnonymousUserId();
      final results = await Future.wait([
        EBookService.instance.fetchCategories(),
        EBookService.instance.fetchFeaturedBooks(),
        EBookService.instance.fetchLibrary(userId),
        EBookService.instance.fetchBanner(),
      ]);
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _categories = results[0] as List<Map<String, dynamic>>;
        _featured = results[1] as List<Map<String, dynamic>>;
        _library = results[2] as List<Map<String, dynamic>>;
        _banner = results[3] as Map<String, dynamic>?;
        _isLoading = false;
      });
      await _refreshCatalogResults();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load e-books. Please try again.';
      });
    }
  }

  Future<void> _toggleBookmark(String bookId) async {
    final userId = _userId;
    if (userId == null) return;
    await EBookService.instance.toggleBookmark(userId, bookId);
    await _loadAll();
  }

  Future<void> _onCategorySelected(String? categoryId) async {
    if (categoryId == _selectedCategoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    await _refreshCatalogResults();
  }

  // Single source of truth for the catalog grid below the chips, for both
  // "All" (categoryId null — fetchBooks applies no category filter, so this
  // returns every active/published book) and a specific category/search.
  // "Your Library" (bookmarks) is intentionally NOT used here anymore — that
  // has its own dedicated SavedBooksScreen — so the "All" chip always shows
  // the real catalog instead of the (often near-empty) personal library.
  Future<void> _refreshCatalogResults() async {
    setState(() => _catalogLoading = true);
    try {
      final books = await EBookService.instance.fetchBooks(
        categoryId: _selectedCategoryId,
        search: _searchQuery,
        limit: 50,
      );
      final bookmarkedIds = _library
          .where((b) => b['isBookmarked'] == true)
          .map((b) => b['id'])
          .toSet();
      // Defensive de-dup by book id — the backend query shouldn't produce
      // duplicates, but this guarantees the list never shows one twice.
      final seenIds = <dynamic>{};
      final deduped = <Map<String, dynamic>>[];
      for (final b in books) {
        if (seenIds.add(b['id'])) {
          deduped.add({...b, 'isBookmarked': bookmarkedIds.contains(b['id'])});
        }
      }
      if (!mounted) return;
      setState(() {
        _catalogResults = deduped;
        _catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogResults = [];
        _catalogLoading = false;
      });
    }
  }

  void _openDetails(Map<String, dynamic> book) {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BookDetailsScreen(book: book)))
        .then((_) => _loadAll());
  }

  void _openReader(Map<String, dynamic> book) {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BookReaderScreen(book: book)))
        .then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final filteredFeatured = _featured.where((b) {
      final matchesSearch = (b['title'] as String? ?? '')
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategoryId == null || b['categoryId'] == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();

    // Always the DB-backed catalog (see _refreshCatalogResults) — "All"
    // fetches with no category filter (every active book), a chip narrows
    // it to that category, and search narrows either. Never the personal
    // "Your Library" list, which has its own dedicated SavedBooksScreen.
    final displayedBooks = _catalogResults ?? const <Map<String, dynamic>>[];

    final String selectedCategoryName = _selectedCategoryId == null
        ? ''
        : _categories.firstWhere((c) => c['id'] == _selectedCategoryId,
            orElse: () => const {'name': ''})['name'] as String;

    final String sectionTitle = _searchQuery.isNotEmpty
        ? 'Search Results'
        : (_selectedCategoryId != null && selectedCategoryName.isNotEmpty)
            ? '$selectedCategoryName Books'
            : 'All Books';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kEbookRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: TextStyle(color: context.textColor, fontSize: 14.0),
                  cursorColor: _kEbookRed,
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    hintStyle:
                        TextStyle(color: context.subTextColor, fontSize: 13.0),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  autofocus: true,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _refreshCatalogResults();
                  },
                ),
              )
            : Text('e-books',
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: _isSearching
            ? [
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: context.textColor, size: 22.0),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                    _refreshCatalogResults();
                  },
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.search_rounded,
                      color: context.textColor, size: 22.0),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: Icon(Icons.bookmark_border_rounded,
                      color: context.textColor, size: 22.0),
                  onPressed: () {
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SavedBooksScreen()))
                        .then((_) => _loadAll());
                  },
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProfileScreen()))
                        .then((_) => setState(() {}));
                  },
                  child: Center(
                    child: Container(
                      width: 28.0,
                      height: 28.0,
                      margin: const EdgeInsets.only(right: 16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15), width: 1.0),
                      ),
                      child: ClipOval(
                        child: ProfileScreen.profileImagePath != null
                            ? Image.file(
                                File(ProfileScreen.profileImagePath!),
                                width: 28.0,
                                height: 28.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person_rounded,
                                        color: Colors.white70, size: 16.0),
                              )
                            : const Icon(Icons.person_rounded,
                                color: Colors.white70, size: 16.0),
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.themeGradients),
        ),
        child: SafeArea(
          child: _isLoading
              ? buildEbookLoadingState(context)
              : _error != null
                  ? buildEbookErrorState(context, _error!, _loadAll)
                  : RefreshIndicator(
                      color: _kEbookRed,
                      onRefresh: _loadAll,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (filteredFeatured.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Featured Arrivals',
                                      style: TextStyle(
                                          color: context.textColor,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.bold)),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const AllBooksCatalogScreen()))
                                          .then((_) => _loadAll());
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('VIEW ALL',
                                        style: TextStyle(
                                            color: _kEbookRed,
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16.0),
                              SizedBox(
                                height: 256.0,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredFeatured.length,
                                  itemBuilder: (context, index) {
                                    final book = filteredFeatured[index];
                                    return _FeaturedBookCard(
                                      book: book,
                                      userId: _userId,
                                      onTap: () => _openDetails(book),
                                      onBookmarkToggle: () =>
                                          _toggleBookmark(book['id'] as String),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16.0),
                            ],
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  buildEbookCategoryChip(
                                      context,
                                      'All',
                                      _selectedCategoryId == null,
                                      () => _onCategorySelected(null)),
                                  ..._categories
                                      .map((cat) => buildEbookCategoryChip(
                                            context,
                                            cat['name'] as String,
                                            _selectedCategoryId == cat['id'],
                                            () => _onCategorySelected(
                                                cat['id'] as String),
                                          )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24.0),
                            Row(
                              children: [
                                Text(
                                  sectionTitle,
                                  style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 3.0),
                                  decoration: BoxDecoration(
                                    color: context.isDark
                                        ? Colors.white12
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Text(
                                    '${displayedBooks.length} Books',
                                    style: TextStyle(
                                        color: context.subTextColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            if (_catalogLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: _kEbookRed)),
                              )
                            else if (displayedBooks.isEmpty)
                              buildEbookEmptyState(context, 'No books found')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedBooks.length,
                                itemBuilder: (context, index) {
                                  final book = displayedBooks[index];
                                  return buildLibraryRow(
                                    context,
                                    book,
                                    onTap: () => _openReader(book),
                                    onBookmarkToggle: () =>
                                        _toggleBookmark(book['id'] as String),
                                  );
                                },
                              ),
                            const SizedBox(height: 28.0),
                            if (_banner != null)
                              _DiscoverBanner(
                                  banner: _banner!,
                                  onRefreshAfterReturn: _loadAll),
                            const SizedBox(height: 20.0),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _FeaturedBookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final String? userId;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  const _FeaturedBookCard({
    required this.book,
    required this.userId,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140.0,
        margin: const EdgeInsets.only(right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8.0,
                      offset: const Offset(3, 3))
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: EbookCover(
                      url: book['cover'] as String?,
                      title: book['title'] as String? ?? '',
                      width: 140.0,
                      height: 200.0,
                    ),
                  ),
                  if (userId != null)
                    Positioned(
                      top: 8.0,
                      right: 8.0,
                      child: FutureBuilder<bool>(
                        future: EBookService.instance
                            .isBookmarked(userId!, book['id'] as String),
                        builder: (context, snapshot) {
                          final isSaved = snapshot.data ?? false;
                          return GestureDetector(
                            onTap: onBookmarkToggle,
                            child: Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle),
                              child: Icon(
                                isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: isSaved
                                    ? const Color(0xFFFCA5A5)
                                    : Colors.white70,
                                size: 16.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
            Text(
              book['title'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2.0),
            Text(
              (book['author'] as String?)?.trim().isNotEmpty == true
                  ? book['author'] as String
                  : 'Unknown Author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.subTextColor, fontSize: 11.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverBanner extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback onRefreshAfterReturn;

  const _DiscoverBanner(
      {required this.banner, required this.onRefreshAfterReturn});

  @override
  Widget build(BuildContext context) {
    final String bg = banner['backgroundImage'] as String? ?? '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(16.0),
        image: bg.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(bg),
                fit: BoxFit.cover,
                opacity: 0.15,
                onError: (exception, stackTrace) {},
              )
            : null,
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.3)
            ],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (banner['title'] as String?) ?? 'Discover your\nNext Obsession',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w900,
                  height: 1.2),
            ),
            const SizedBox(height: 10.0),
            Text(
              (banner['subtitle'] as String?) ?? '',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12.0, height: 1.45),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              height: 40.0,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AllBooksCatalogScreen()))
                      .then((_) => onRefreshAfterReturn());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCA5A5).withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  elevation: 0.0,
                ),
                child: Text(
                  ((banner['buttonText'] as String?)?.isNotEmpty ?? false)
                      ? (banner['buttonText'] as String).toUpperCase()
                      : 'VIEW ALL',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Book Catalog — grid of all active books with search, category
// filter and infinite scroll.
// ────────────────────────────────────────────────────────────────

class AllBooksCatalogScreen extends StatefulWidget {
  const AllBooksCatalogScreen({super.key});

  @override
  State<AllBooksCatalogScreen> createState() => _AllBooksCatalogScreenState();
}

class _AllBooksCatalogScreenState extends State<AllBooksCatalogScreen> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _userId;
  int _page = 1;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _books = [];

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingMore ||
        !_hasMore ||
        _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = await EBookService.instance.getOrCreateAnonymousUserId();
      final categories = await EBookService.instance.fetchCategories();
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _categories = categories;
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load the book catalog. Please try again.';
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _books = [];
    });
    try {
      final books = await EBookService.instance.fetchBooks(
        categoryId: _selectedCategoryId,
        page: 1,
        limit: _pageSize,
        search: _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _books = books;
        _hasMore = books.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load the book catalog. Please try again.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final books = await EBookService.instance.fetchBooks(
        categoryId: _selectedCategoryId,
        page: nextPage,
        limit: _pageSize,
        search: _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _books = [..._books, ...books];
        _hasMore = books.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleBookmark(String bookId) async {
    final userId = _userId;
    if (userId == null) return;
    await EBookService.instance.toggleBookmark(userId, bookId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kEbookRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Container(
                height: 40.0,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20.0)),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  cursorColor: _kEbookRed,
                  decoration: const InputDecoration(
                    hintText: 'Search catalog...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13.0),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  autofocus: true,
                  onChanged: (val) {
                    _searchQuery = val;
                    _reload();
                  },
                ),
              )
            : const Text('Book Catalog',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22.0),
                  onPressed: () {
                    setState(() => _isSearching = false);
                    _searchQuery = '';
                    _reload();
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 22.0),
                  onPressed: () => setState(() => _isSearching = true),
                ),
              ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.themeGradients),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        buildEbookCategoryChip(
                            context, 'All', _selectedCategoryId == null, () {
                          setState(() => _selectedCategoryId = null);
                          _reload();
                        }),
                        ..._categories.map((cat) => buildEbookCategoryChip(
                              context,
                              cat['name'] as String,
                              _selectedCategoryId == cat['id'],
                              () {
                                setState(() =>
                                    _selectedCategoryId = cat['id'] as String);
                                _reload();
                              },
                            )),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? buildEbookLoadingState(context)
                    : _error != null
                        ? buildEbookErrorState(context, _error!, _reload)
                        : RefreshIndicator(
                            color: _kEbookRed,
                            onRefresh: _reload,
                            child: _books.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.5,
                                        child: buildEbookEmptyState(
                                            context, 'No books found'),
                                      ),
                                    ],
                                  )
                                : GridView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 16.0),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics()),
                                    itemCount:
                                        _books.length + (_hasMore ? 1 : 0),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12.0,
                                      mainAxisSpacing: 16.0,
                                      childAspectRatio: 0.56,
                                    ),
                                    itemBuilder: (context, index) {
                                      if (index >= _books.length) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 20.0,
                                            height: 20.0,
                                            child: CircularProgressIndicator(
                                                color: _kEbookRed,
                                                strokeWidth: 2.0),
                                          ),
                                        );
                                      }
                                      final book = _books[index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          BookDetailsScreen(
                                                              book: book)))
                                              .then((_) => setState(() {}));
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 6.0,
                                                        offset:
                                                            const Offset(2, 2)),
                                                  ],
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: EbookCover(
                                                        url: book['cover']
                                                            as String?,
                                                        title: book['title']
                                                                as String? ??
                                                            '',
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                      ),
                                                    ),
                                                    if (_userId != null)
                                                      Positioned(
                                                        top: 4.0,
                                                        right: 4.0,
                                                        child:
                                                            FutureBuilder<bool>(
                                                          future: EBookService
                                                              .instance
                                                              .isBookmarked(
                                                                  _userId!,
                                                                  book['id']
                                                                      as String),
                                                          builder: (context,
                                                              snapshot) {
                                                            final isSaved =
                                                                snapshot.data ??
                                                                    false;
                                                            return GestureDetector(
                                                              onTap: () =>
                                                                  _toggleBookmark(
                                                                      book['id']
                                                                          as String),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        4.0),
                                                                decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .black
                                                                        .withOpacity(
                                                                            0.6),
                                                                    shape: BoxShape
                                                                        .circle),
                                                                child: Icon(
                                                                  isSaved
                                                                      ? Icons
                                                                          .bookmark_rounded
                                                                      : Icons
                                                                          .bookmark_border_rounded,
                                                                  color: isSaved
                                                                      ? const Color(
                                                                          0xFFFCA5A5)
                                                                      : Colors
                                                                          .white,
                                                                  size: 14.0,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6.0),
                                            Text(
                                              book['title'] as String? ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.25),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Book Details — cover, metadata, description, Read / Bookmark /
// Download actions, and Related Books from the same category.
// ────────────────────────────────────────────────────────────────

class BookDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  const BookDetailsScreen({super.key, required this.book});

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  late Map<String, dynamic> _book;
  String? _userId;
  bool _isBookmarked = false;
  bool _isLoadingRelated = true;
  List<Map<String, dynamic>> _related = [];

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Re-fetch this book by id so any admin edit made after the list
    // screen was last loaded (title/cover/description/etc.) is reflected
    // here, instead of showing the possibly-stale Map passed via navigation.
    try {
      final fresh =
          await EBookService.instance.fetchBookById(_book['id'] as String);
      if (mounted && fresh != null) {
        setState(() => _book = fresh);
      }
    } catch (e) {
      // Keep showing the Map passed via navigation if the refetch fails.
    }

    final userId = await EBookService.instance.getOrCreateAnonymousUserId();
    final bookmarked =
        await EBookService.instance.isBookmarked(userId, _book['id'] as String);
    if (mounted) {
      setState(() {
        _userId = userId;
        _isBookmarked = bookmarked;
      });
    }

    final categoryId = _book['categoryId'] as String?;
    if (categoryId == null) {
      if (mounted) setState(() => _isLoadingRelated = false);
      return;
    }
    try {
      final related = await EBookService.instance.fetchRelatedBooks(
          categoryId: categoryId, excludeBookId: _book['id'] as String);
      if (mounted) {
        setState(() {
          _related = related;
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final userId = _userId;
    if (userId == null) return;
    final newState = await EBookService.instance
        .toggleBookmark(userId, _book['id'] as String);
    if (mounted) setState(() => _isBookmarked = newState);
  }

  Future<void> _download() async {
    final url = _book['pdfUrl'] as String?;
    if (url == null || url.isEmpty) return;
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the download link.')));
    }
  }

  void _openReader() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => BookReaderScreen(book: _book)));
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final String? pdfUrl = book['pdfUrl'] as String?;
    final bool hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kEbookRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Book Details',
            style: TextStyle(
                color: context.textColor,
                fontSize: 16.0,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.themeGradients),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 16.0,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: EbookCover(
                      url: book['cover'] as String?,
                      title: book['title'] as String? ?? '',
                      width: 180.0,
                      height: 260.0,
                      radius: 12.0,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  book['title'] as String? ?? '',
                  style: TextStyle(
                      color: context.textColor,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (book['author'] as String?)?.trim().isNotEmpty == true
                            ? book['author'] as String
                            : 'Unknown Author',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.subTextColor, fontSize: 13.0),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: _kEbookRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        book['category'] as String? ?? 'General',
                        style: const TextStyle(
                            color: _kEbookRed,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        color: context.subTextColor, size: 14.0),
                    const SizedBox(width: 6.0),
                    Text(
                        EBookService.formatPagesLabel(
                            (book['totalPages'] as int?) ?? 0),
                        style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600)),
                    if ((book['readingTime'] as String?)?.isNotEmpty ??
                        false) ...[
                      const SizedBox(width: 14.0),
                      Icon(Icons.schedule_rounded,
                          color: context.subTextColor, size: 14.0),
                      const SizedBox(width: 6.0),
                      Text(book['readingTime'] as String,
                          style: TextStyle(
                              color: context.subTextColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (_formatDate(book['publishDate']).isNotEmpty) ...[
                      const SizedBox(width: 14.0),
                      Icon(Icons.event_rounded,
                          color: context.subTextColor, size: 14.0),
                      const SizedBox(width: 6.0),
                      Text(_formatDate(book['publishDate']),
                          style: TextStyle(
                              color: context.subTextColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
                const SizedBox(height: 18.0),
                Text(
                  (book['description'] as String?)?.isNotEmpty ?? false
                      ? book['description'] as String
                      : 'No description available for this book yet.',
                  style: TextStyle(
                      color: context.subTextColor,
                      fontSize: 13.5,
                      height: 1.55),
                ),
                const SizedBox(height: 26.0),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46.0,
                        child: ElevatedButton.icon(
                          onPressed: hasPdf ? _openReader : null,
                          icon: const Icon(Icons.menu_book_rounded,
                              color: Colors.white, size: 18.0),
                          label: const Text('Read',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kEbookRed,
                            disabledBackgroundColor:
                                _kEbookRed.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23.0)),
                            elevation: 0.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    GestureDetector(
                      onTap: _toggleBookmark,
                      child: Container(
                        width: 46.0,
                        height: 46.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.cardBg,
                          border: Border.all(color: context.borderCol),
                        ),
                        child: Icon(
                          _isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isBookmarked ? _kEbookRed : context.textColor,
                          size: 22.0,
                        ),
                      ),
                    ),
                    if (hasPdf) ...[
                      const SizedBox(width: 12.0),
                      GestureDetector(
                        onTap: _download,
                        child: Container(
                          width: 46.0,
                          height: 46.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.cardBg,
                            border: Border.all(color: context.borderCol),
                          ),
                          child: Icon(Icons.download_rounded,
                              color: context.textColor, size: 22.0),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!hasPdf) ...[
                  const SizedBox(height: 10.0),
                  Text('This book has no reading file yet.',
                      style: TextStyle(
                          color: context.subTextColor, fontSize: 11.5)),
                ],
                const SizedBox(height: 30.0),
                if (_isLoadingRelated)
                  buildEbookLoadingState(context)
                else if (_related.isNotEmpty) ...[
                  Text('Related Books',
                      style: TextStyle(
                          color: context.textColor,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14.0),
                  SizedBox(
                    height: 200.0,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _related.length,
                      itemBuilder: (context, index) {
                        final related = _related[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      BookDetailsScreen(book: related)),
                            );
                          },
                          child: Container(
                            width: 120.0,
                            margin: const EdgeInsets.only(right: 14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EbookCover(
                                  url: related['cover'] as String?,
                                  title: related['title'] as String? ?? '',
                                  width: 120.0,
                                  height: 160.0,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  related['title'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// E-book Reader — real PDF rendering with page tracking, resume,
// bookmark and download.
// ────────────────────────────────────────────────────────────────

class BookReaderScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  String? _userId;
  bool _isBookmarked = false;
  int _currentPage = 0;
  int _totalPages = 0;
  int _resumePage = 0;
  bool _loadFailed = false;
  Key _viewerKey = UniqueKey();

  String get _pdfUrl => (widget.book['pdfUrl'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final userId = await EBookService.instance.getOrCreateAnonymousUserId();
    final bookId = widget.book['id'] as String;
    final bookmarked = await EBookService.instance.isBookmarked(userId, bookId);
    final progress = await EBookService.instance.fetchProgress(userId, bookId);
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _isBookmarked = bookmarked;
      _resumePage = (progress?['currentPage'] as int?) ?? 0;
    });
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _currentPage = 1;
    });
    if (_resumePage > 1 && _resumePage <= _totalPages) {
      _pdfController.jumpToPage(_resumePage);
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() => _currentPage = details.newPageNumber);
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    final userId = _userId;
    if (userId == null || _totalPages == 0) return;
    await EBookService.instance.saveProgress(
      userId: userId,
      bookId: widget.book['id'] as String,
      currentPage: _currentPage,
      totalPages: _totalPages,
      completed: _currentPage >= _totalPages,
    );
  }

  Future<void> _toggleBookmark() async {
    final userId = _userId;
    if (userId == null) return;
    final newState = await EBookService.instance
        .toggleBookmark(userId, widget.book['id'] as String);
    if (mounted) setState(() => _isBookmarked = newState);
  }

  Future<void> _download() async {
    if (_pdfUrl.isEmpty) return;
    final ok = await launchUrl(Uri.parse(_pdfUrl),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the download link.')));
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kEbookRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              book['title'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2.0),
            Text(
                (book['author'] as String?)?.trim().isNotEmpty == true
                    ? book['author'] as String
                    : 'Unknown Author',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10.0)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isBookmarked ? _kEbookRed : Colors.white,
              size: 20.0,
            ),
            onPressed: _toggleBookmark,
          ),
          if (_pdfUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: Colors.white, size: 20.0),
              onPressed: _download,
            ),
        ],
      ),
      body: _pdfUrl.isEmpty
          ? buildEbookErrorState(
              context,
              'This book has no PDF file yet. Please check back later.',
              () => Navigator.pop(context),
              retryLabel: 'Go Back',
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _loadFailed
                        ? buildEbookErrorState(context,
                            'Could not load this PDF. Check your connection and try again.',
                            () {
                            setState(() {
                              _loadFailed = false;
                              _viewerKey = UniqueKey();
                            });
                          })
                        : SfPdfViewer.network(
                            _pdfUrl,
                            key: _viewerKey,
                            controller: _pdfController,
                            onDocumentLoaded: _onDocumentLoaded,
                            onPageChanged: _onPageChanged,
                            onDocumentLoadFailed: (details) {
                              if (mounted) setState(() => _loadFailed = true);
                            },
                          ),
                  ),
                  Container(
                    color: const Color(0xFF141416),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.navigate_before_rounded,
                              color: Colors.white70),
                          onPressed: _currentPage > 1
                              ? () => _pdfController.previousPage()
                              : null,
                        ),
                        Text(
                          _totalPages > 0
                              ? 'Page $_currentPage of $_totalPages'
                              : '—',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_next_rounded,
                              color: Colors.white70),
                          onPressed:
                              _totalPages > 0 && _currentPage < _totalPages
                                  ? () => _pdfController.nextPage()
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Saved Books ("Your Library" bookmarks only).
// ────────────────────────────────────────────────────────────────

class SavedBooksScreen extends StatefulWidget {
  const SavedBooksScreen({super.key});

  @override
  State<SavedBooksScreen> createState() => _SavedBooksScreenState();
}

class _SavedBooksScreenState extends State<SavedBooksScreen> {
  bool _isLoading = true;
  String? _error;
  String? _userId;
  List<Map<String, dynamic>> _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = await EBookService.instance.getOrCreateAnonymousUserId();
      final library = await EBookService.instance.fetchLibrary(userId);
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _saved = library.where((b) => b['isBookmarked'] == true).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load saved books. Please try again.';
      });
    }
  }

  Future<void> _toggleBookmark(String bookId) async {
    final userId = _userId;
    if (userId == null) return;
    await EBookService.instance.toggleBookmark(userId, bookId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kEbookRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Saved Books',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.themeGradients),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: _kEbookRed,
            onRefresh: _load,
            child: _isLoading
                ? buildEbookLoadingState(context)
                : _error != null
                    ? buildEbookErrorState(context, _error!, _load)
                    : _saved.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bookmark_border_rounded,
                                    color: Colors.white.withOpacity(0.15),
                                    size: 64.0),
                                const SizedBox(height: 16.0),
                                const Text('No Saved Books yet',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6.0),
                                const Text(
                                    'Tap the bookmark icon on any book to save it here.',
                                    style: TextStyle(
                                        color: Colors.white30, fontSize: 12.0)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 16.0),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _saved.length,
                            itemBuilder: (context, index) {
                              final book = _saved[index];
                              return buildLibraryRow(
                                context,
                                book,
                                onTap: () {
                                  Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  BookReaderScreen(book: book)))
                                      .then((_) => _load());
                                },
                                onBookmarkToggle: () =>
                                    _toggleBookmark(book['id'] as String),
                              );
                            },
                          ),
          ),
        ),
      ),
    );
  }
}
