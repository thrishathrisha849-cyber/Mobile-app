import 'package:supabase_flutter/supabase_flutter.dart';
import 'podcast_service.dart';

/// Data access layer for the E-book / Book Catalog module.
///
/// Mirrors `podcast_service.dart` exactly: talks directly to Supabase, returns
/// plain `Map<String, dynamic>` (no model classes), and reuses the same
/// anonymous per-device identity (there is no auth system in this app) so
/// "Your Library" / reading progress behave the same way "Continue Listening"
/// does for Podcasts.
class EBookService {
  EBookService._();
  static final EBookService instance = EBookService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const String _bookSelect = '*, ebook_categories(id, name, slug)';

  // ── Anonymous device identity (shared with Podcast — same device, same id) ──
  Future<String> getOrCreateAnonymousUserId() {
    return PodcastService.instance.getOrCreateAnonymousUserId();
  }

  // ── Categories ──
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _client
        .from('ebook_categories')
        .select()
        .eq('status', 'active')
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      return {
        'id': row['id'],
        'name': row['name'],
        'slug': row['slug'],
      };
    }).toList();
  }

  // ── Books ──
  Map<String, dynamic> _normalizeBook(Map<String, dynamic> row) {
    final category = row['ebook_categories'] as Map<String, dynamic>?;
    final totalPages = (row['total_pages'] as num?)?.toInt() ?? 0;

    return {
      'id': row['id'],
      'title': row['title'] ?? '',
      'slug': row['slug'],
      'author': row['author'] ?? '',
      'category': category != null ? category['name'] : 'General',
      'categoryId': row['category_id'],
      'desc': row['description'] ?? '',
      'description': row['description'] ?? '',
      'cover': row['cover_image'] ?? '',
      'pdfUrl': row['pdf_url'],
      'contentUrl': row['content_url'],
      'totalPages': totalPages,
      'pagesLabel': formatPagesLabel(totalPages),
      'readingTime': row['reading_time'],
      'isFeatured': row['is_featured'] ?? false,
      'sortOrder': row['sort_order'] ?? 0,
      'publishDate': row['publish_date'],
    };
  }

  /// Fetches a page of active books, optionally filtered by category id
  /// and/or a title/author search query. Pagination is page-based; the
  /// caller knows it's the last page when fewer than [limit] items come back.
  Future<List<Map<String, dynamic>>> fetchBooks({
    String? categoryId,
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    var query =
        _client.from('ebooks').select(_bookSelect).eq('status', 'active');

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (search.isNotEmpty) {
      query = query.or('title.ilike.%$search%,author.ilike.%$search%');
    }

    final from = (page - 1) * limit;
    final to = from + limit - 1;

    final rows = await query
        .order('sort_order', ascending: true)
        .order('publish_date', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(rows).map(_normalizeBook).toList();
  }

  Future<Map<String, dynamic>?> fetchBookById(String id) async {
    final row = await _client
        .from('ebooks')
        .select(_bookSelect)
        .eq('id', id)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return _normalizeBook(row);
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedBooks(
      {int limit = 10}) async {
    final rows = await _client
        .from('ebooks')
        .select(_bookSelect)
        .eq('status', 'active')
        .eq('is_featured', true)
        .order('sort_order', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows).map(_normalizeBook).toList();
  }

  /// Books related to [categoryId], excluding [excludeBookId] — used for the
  /// "Related books" section on the Book Details page.
  Future<List<Map<String, dynamic>>> fetchRelatedBooks({
    required String categoryId,
    String? excludeBookId,
    int limit = 10,
  }) async {
    var query = _client
        .from('ebooks')
        .select(_bookSelect)
        .eq('status', 'active')
        .eq('category_id', categoryId);

    if (excludeBookId != null) {
      query = query.neq('id', excludeBookId);
    }

    final rows = await query.order('sort_order', ascending: true).limit(limit);
    return List<Map<String, dynamic>>.from(rows).map(_normalizeBook).toList();
  }

  // ── Your Library (bookmarked and/or in-progress books) ──
  Future<List<Map<String, dynamic>>> fetchLibrary(String userId) async {
    final bookmarkRows = await _client
        .from('ebook_bookmarks')
        .select('book_id')
        .eq('user_id', userId);
    final bookmarkedIds = List<Map<String, dynamic>>.from(bookmarkRows)
        .map((r) => r['book_id'] as String)
        .toSet();

    final progressRows = await _client
        .from('ebook_progress')
        .select('book_id, current_page, total_pages, completed, updated_at')
        .eq('user_id', userId)
        .gt('current_page', 0);
    final progressByBook = <String, Map<String, dynamic>>{
      for (final r in List<Map<String, dynamic>>.from(progressRows))
        r['book_id'] as String: r,
    };

    final allIds = <String>{...bookmarkedIds, ...progressByBook.keys};
    if (allIds.isEmpty) return [];

    final bookRows = await _client
        .from('ebooks')
        .select(_bookSelect)
        .eq('status', 'active')
        .inFilter('id', allIds.toList());

    final merged = List<Map<String, dynamic>>.from(bookRows).map((row) {
      final book = _normalizeBook(row);
      final progress = progressByBook[book['id']];
      final currentPage = (progress?['current_page'] as num?)?.toInt() ?? 0;
      final totalPages = (progress?['total_pages'] as num?)?.toInt() ??
          (book['totalPages'] as int? ?? 0);
      final percent =
          totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;
      final pagesLeft =
          (totalPages - currentPage).clamp(0, totalPages > 0 ? totalPages : 0);

      return {
        ...book,
        'isBookmarked': bookmarkedIds.contains(book['id']),
        'currentPage': currentPage,
        'progressTotalPages': totalPages,
        'progress': percent,
        'progressPercent': (percent * 100).round(),
        'pagesLeft': pagesLeft,
        'pagesLeftText': totalPages > 0 ? '$pagesLeft pages left' : '',
        'completed': progress?['completed'] ?? false,
        'showResume': currentPage > 0,
        '_updatedAt': progress?['updated_at'] as String?,
      };
    }).toList();

    merged.sort((a, b) {
      final aUpdated = a['_updatedAt'] as String?;
      final bUpdated = b['_updatedAt'] as String?;
      if (aUpdated != null && bUpdated != null)
        return bUpdated.compareTo(aUpdated);
      if (aUpdated != null) return -1;
      if (bUpdated != null) return 1;
      return (a['sortOrder'] as int).compareTo(b['sortOrder'] as int);
    });

    return merged;
  }

  // ── Bookmarks ──
  Future<bool> isBookmarked(String userId, String bookId) async {
    final row = await _client
        .from('ebook_bookmarks')
        .select('id')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .maybeSingle();
    return row != null;
  }

  /// Toggles the bookmark for [bookId] and returns the new bookmarked state.
  Future<bool> toggleBookmark(String userId, String bookId) async {
    final already = await isBookmarked(userId, bookId);
    if (already) {
      await removeBookmark(userId, bookId);
      return false;
    }
    await _client.from('ebook_bookmarks').upsert({
      'user_id': userId,
      'book_id': bookId,
    }, onConflict: 'user_id,book_id');
    return true;
  }

  Future<void> removeBookmark(String userId, String bookId) async {
    await _client
        .from('ebook_bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  // ── Reading Progress ──
  Future<Map<String, dynamic>?> fetchProgress(
      String userId, String bookId) async {
    final row = await _client
        .from('ebook_progress')
        .select()
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .maybeSingle();
    if (row == null) return null;

    return {
      'currentPage': (row['current_page'] as num?)?.toInt() ?? 0,
      'totalPages': (row['total_pages'] as num?)?.toInt() ?? 0,
      'progressPercentage':
          (row['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      'completed': row['completed'] ?? false,
    };
  }

  Future<void> saveProgress({
    required String userId,
    required String bookId,
    required int currentPage,
    required int totalPages,
    bool completed = false,
  }) async {
    final percentage =
        totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) * 100 : 0.0;
    await _client.from('ebook_progress').upsert({
      'user_id': userId,
      'book_id': bookId,
      'current_page': currentPage,
      'total_pages': totalPages,
      'progress_percentage': percentage,
      'completed': completed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,book_id');
  }

  Future<void> markCompleted({
    required String userId,
    required String bookId,
    required int totalPages,
  }) async {
    await saveProgress(
      userId: userId,
      bookId: bookId,
      currentPage: totalPages,
      totalPages: totalPages,
      completed: true,
    );
  }

  // ── Discover / CTA Banner ──
  Future<Map<String, dynamic>?> fetchBanner() async {
    final row = await _client
        .from('ebook_banners')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _normalizeBanner(row);
  }

  /// Fetches a specific banner by id (there can be more than one row in
  /// `ebook_banners`, unlike [fetchBanner] which only returns the latest
  /// active one) — used when a notification references a specific banner.
  Future<Map<String, dynamic>?> fetchBannerById(String id) async {
    final row = await _client
        .from('ebook_banners')
        .select()
        .eq('id', id)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return _normalizeBanner(row);
  }

  Map<String, dynamic> _normalizeBanner(Map<String, dynamic> row) {
    return {
      'title': (row['title'] as String?) ?? '',
      'subtitle': (row['subtitle'] as String?) ?? '',
      'backgroundImage': (row['background_image'] as String?) ?? '',
      'buttonText': (row['button_text'] as String?) ?? '',
      'buttonLink': (row['button_link'] as String?) ?? '',
    };
  }

  // ── Formatting helpers ──
  static String formatPagesLabel(int pages) =>
      '$pages page${pages == 1 ? '' : 's'}';
}
