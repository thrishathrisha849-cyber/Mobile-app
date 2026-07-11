import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'podcast_service.dart';

/// Data access layer for the Support module (settings, categories, FAQs,
/// tickets, feedback). Mirrors `ebook_service.dart` / `legal_service.dart`:
/// talks directly to Supabase, returns plain `Map<String, dynamic>` (no
/// model classes), and reuses the app-wide anonymous per-device identity
/// (there is no auth system in this app) to tag submitted tickets/feedback.
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> getOrCreateAnonymousUserId() {
    return PodcastService.instance.getOrCreateAnonymousUserId();
  }

  // ── Settings ──
  Future<Map<String, dynamic>?> fetchSettings() async {
    final row = await _client
        .from('support_settings')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    return {
      'title': row['title'] ?? 'Support Center',
      'subtitle': row['subtitle'] ?? '',
      'whatsappNumber': row['whatsapp_number'],
      'phoneNumber': row['phone_number'],
      'email': row['email'],
      'websiteUrl': row['website_url'],
      'supportTiming': row['support_timing'],
      'address': row['address'],
      'buttonText': row['button_text'] ?? 'Contact Us',
      'bannerImage': row['banner_image'],
    };
  }

  // ── Categories ──
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _client
        .from('support_categories')
        .select()
        .eq('status', 'active')
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      return {
        'id': row['id'],
        'name': row['name'],
        'slug': row['slug'],
        'description': row['description'] ?? '',
        'icon': row['icon'],
      };
    }).toList();
  }

  // ── FAQs ──
  Map<String, dynamic> _normalizeFaq(Map<String, dynamic> row) {
    final category = row['support_categories'] as Map<String, dynamic>?;
    return {
      'id': row['id'],
      'question': row['question'] ?? '',
      'answer': row['answer'] ?? '',
      'categoryId': row['category_id'],
      'categoryName': category != null ? category['name'] : null,
      'sortOrder': row['sort_order'] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> fetchFaqs({
    String? categoryId,
    String search = '',
    int page = 1,
    int limit = 50,
  }) async {
    var query = _client
        .from('support_faqs')
        .select('*, support_categories(id, name, slug)')
        .eq('status', 'active');

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (search.isNotEmpty) {
      query = query.or('question.ilike.%$search%,answer.ilike.%$search%');
    }

    final from = (page - 1) * limit;
    final to = from + limit - 1;

    final rows =
        await query.order('sort_order', ascending: true).range(from, to);
    return List<Map<String, dynamic>>.from(rows).map(_normalizeFaq).toList();
  }

  /// Fetches a single active FAQ by id — used when a notification references
  /// a specific FAQ so it can be highlighted/expanded on the Support page.
  Future<Map<String, dynamic>?> fetchFaqById(String id) async {
    final row = await _client
        .from('support_faqs')
        .select('*, support_categories(id, name, slug)')
        .eq('id', id)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return _normalizeFaq(row);
  }

  // ── Tickets ──
  Future<void> submitTicket({
    required String name,
    required String email,
    String? phone,
    required String subject,
    String? categoryId,
    required String message,
    String? attachmentUrl,
  }) async {
    final row = await _client
        .from('support_tickets')
        .insert({
          'name': name,
          'email': email,
          'phone': (phone == null || phone.isEmpty) ? null : phone,
          'subject': subject,
          'category_id': categoryId,
          'message': message,
          'attachment_url': attachmentUrl,
          'status': 'new',
        })
        .select()
        .single();

    await _notifyAdmin(
      title: 'New Support Ticket',
      message: 'New ticket submitted: $subject',
      type: 'support_ticket',
      referenceId: row['id'] as String?,
      referenceType: 'support_ticket',
    );
  }

  // ── Feedback / Report Issue ──
  Future<void> submitFeedback({
    String? name,
    String? email,
    int? rating,
    required String message,
  }) async {
    final row = await _client
        .from('support_feedback')
        .insert({
          'name': (name == null || name.isEmpty) ? null : name,
          'email': (email == null || email.isEmpty) ? null : email,
          'rating': rating,
          'message': message,
          'status': 'new',
        })
        .select()
        .single();

    await _notifyAdmin(
      title: 'New Feedback Received',
      message: (name == null || name.isEmpty)
          ? 'Anonymous feedback submitted'
          : '$name submitted feedback',
      type: 'support_feedback',
      referenceId: row['id'] as String?,
      referenceType: 'support_feedback',
    );
  }

  /// Creates an admin notification row for a mobile submission. Failures here
  /// must never block the actual ticket/feedback submission, so they're
  /// swallowed silently (the submission itself already succeeded).
  Future<void> _notifyAdmin({
    required String title,
    required String message,
    required String type,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      await _client.from('admin_notifications').insert({
        'title': title,
        'message': message,
        'type': type,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'is_read': false,
      });
    } catch (e) {
      // Notification creation is a side-effect; never block the submission,
      // but log so a failure here is diagnosable instead of fully silent.
      debugPrint('[SupportService] Failed to create admin notification: $e');
    }
  }

  // ── Attachment upload (Supabase Storage) ──
  /// Uploads a local file to the `support-attachments` public bucket and
  /// returns its public URL, or null if the upload fails (e.g. the bucket
  /// doesn't exist yet) — ticket/feedback submission must not be blocked by
  /// a missing/misconfigured bucket since the attachment is optional.
  Future<String?> uploadAttachment(String localFilePath) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${localFilePath.split('/').last}';
      await _client.storage
          .from('support-attachments')
          .upload(fileName, File(localFilePath));
      return _client.storage.from('support-attachments').getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }
}
