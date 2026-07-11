import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access layer for Legal Pages (Terms & Conditions, Privacy Policy).
///
/// Mirrors `ebook_service.dart` / `podcast_service.dart`: talks directly to
/// Supabase and returns a plain `Map<String, dynamic>` (no model classes).
class LegalService {
  LegalService._();
  static final LegalService instance = LegalService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetches the active legal page for [type] ('terms' or 'privacy').
  /// Returns null if no active page exists.
  Future<Map<String, dynamic>?> fetchPage(String type) async {
    final row = await _client
        .from('legal_pages')
        .select()
        .eq('type', type)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;

    return {
      'title': row['title'] ?? '',
      'content': row['content'] ?? '',
      'updatedAt': row['updated_at'],
    };
  }
}
