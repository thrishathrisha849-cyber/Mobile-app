import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'community.dart';
import 'connections_service.dart';

/// Profile's "Connections" list — every user the current logged-in (device)
/// user follows, backed by the same `user_connections` table/service used by
/// Community's Follow button and Profile's Connections count
/// ([ConnectionsService]). No separate follow system, no mock data: each row
/// is resolved from a real post authored by that name (the only per-author
/// identity this app's backend has — see connections_service.dart), or a
/// safe fallback if that author no longer has any visible posts.
class ConnectionsListPage extends StatefulWidget {
  const ConnectionsListPage({super.key});

  @override
  State<ConnectionsListPage> createState() => _ConnectionsListPageState();
}

class _ConnectionsListPageState extends State<ConnectionsListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _connections = [];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  /// Resolves one followed name into a post-shaped map (name/role/badge/
  /// avatarUrl/isFollowing) so it can be rendered with the exact same avatar
  /// logic and passed straight into [showUserProfileSheet]. Prefers the
  /// locally cached feed (`communityPosts`) — already fetched by Community —
  /// and only falls back to a direct Supabase lookup when this device hasn't
  /// loaded that author's post yet (e.g. fresh install before the feed has
  /// ever been fetched).
  Future<Map<String, dynamic>> _resolveConnection(String name) async {
    for (final post in communityPosts) {
      if (post['name'] == name) {
        return {...post, 'isFollowing': true};
      }
    }

    try {
      final rows = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('name', name)
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) {
        final mapped = mapSupabasePostToFeedItem(list.first);
        mapped['isFollowing'] = true;
        return mapped;
      }
    } catch (e) {
      debugPrint('Error resolving connection "$name": $e');
    }

    // Safe fallback for a followed name whose posts are gone (e.g. deleted)
    // — still shown so the list always matches the Connections count.
    return {
      'name': name,
      'role': '',
      'badge': '',
      'badgeColor': const Color(0xFFCC0000),
      'avatarUrl': '',
      'isFollowing': true,
    };
  }

  Future<void> _loadConnections() async {
    if (mounted) setState(() => _loading = true);
    try {
      final followedNames = await ConnectionsService.instance.fetchFollowedNames();
      final names = followedNames.where((n) => n != 'Sakthi (You)').toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final resolved = await Future.wait(names.map(_resolveConnection));

      if (!mounted) return;
      setState(() {
        _connections = resolved;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading connections: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load connections.'),
            action: SnackBarAction(label: 'RETRY', onPressed: _loadConnections),
          ),
        );
      }
    }
  }

  // Mirrors community.dart's `_toggleFollow`, but scoped to this page: also
  // keeps `communityPosts` (the global feed list) in sync so Community shows
  // the correct state on return, and removes the row from this page's own
  // list on unfollow so the visible list always matches the Connections
  // count.
  Future<void> _toggleFollow(Map<String, dynamic> connection) async {
    final name = connection['name'] as String;
    final wasFollowing = connection['isFollowing'] == true;

    setState(() {
      connection['isFollowing'] = !wasFollowing;
      for (final p in communityPosts) {
        if (p['name'] == name) p['isFollowing'] = !wasFollowing;
      }
    });

    try {
      if (wasFollowing) {
        await ConnectionsService.instance.unfollow(name);
      } else {
        await ConnectionsService.instance.follow(name);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connection['isFollowing'] = wasFollowing;
          for (final p in communityPosts) {
            if (p['name'] == name) p['isFollowing'] = wasFollowing;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update follow status. Please try again.'),
            backgroundColor: Color(0xFFCC0000),
          ),
        );
      }
      return;
    }

    await savePostsToLocal();
    if (!mounted) return;

    if (wasFollowing) {
      setState(() {
        _connections.removeWhere((c) => c['name'] == name);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasFollowing ? 'Unfollowed $name' : 'Following $name now!'),
        duration: const Duration(seconds: 1),
        backgroundColor: wasFollowing ? const Color(0xFFCC0000) : const Color(0xFF27AE60),
      ),
    );
  }

  void _showMessage(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat thread with $name...'),
        backgroundColor: const Color(0xFF2F80ED),
      ),
    );
  }

  void _openUserProfile(Map<String, dynamic> connection) {
    showUserProfileSheet(
      context,
      connection,
      onToggleFollow: _toggleFollow,
      onMessage: _showMessage,
    );
  }

  Widget _buildAvatar(Map<String, dynamic> connection) {
    final avatarSrc = resolvePostAvatar(connection);
    final name = (connection['name'] as String?) ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    Widget fallback() => Container(
          color: context.borderCol,
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              color: context.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

    Widget image;
    if (avatarSrc.startsWith('http')) {
      image = Image.network(
        avatarSrc,
        width: 48.0,
        height: 48.0,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } else if (avatarSrc.startsWith('assets/')) {
      image = Image.asset(
        avatarSrc,
        width: 48.0,
        height: 48.0,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } else if (avatarSrc.isEmpty) {
      image = fallback();
    } else {
      image = Image.file(
        File(avatarSrc),
        width: 48.0,
        height: 48.0,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }

    return CircleAvatar(
      radius: 24.0,
      backgroundColor: context.cardBg,
      child: ClipOval(child: image),
    );
  }

  Widget _buildRow(Map<String, dynamic> connection) {
    final name = (connection['name'] as String?) ?? 'Community Member';
    final role = (connection['role'] as String?) ?? '';
    final badge = (connection['badge'] as String?) ?? '';
    final isFollowing = connection['isFollowing'] == true;

    return InkWell(
      onTap: () => _openUserProfile(connection),
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: context.borderCol, width: 1.0),
        ),
        child: Row(
          children: [
            _buildAvatar(connection),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (badge.isNotEmpty) ...[
                        const SizedBox(width: 8.0),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                  color: const Color(0xFFCC0000).withOpacity(0.5)),
                              color: const Color(0xFFCC0000).withOpacity(0.08),
                            ),
                            child: Text(
                              badge,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFFCC0000),
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    memberIdFor(name),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(color: context.subTextColor, fontSize: 12.0),
                  ),
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      role,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(color: context.subTextColor, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              tooltip: isFollowing ? 'Unfollow' : 'Follow',
              icon: Icon(
                isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                color: isFollowing ? Colors.grey : const Color(0xFFCC0000),
              ),
              onPressed: () => _toggleFollow(connection),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = context.textColor;

    return Scaffold(
      body: GlassmorphicBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: textColor, size: 20.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Connections',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48.0),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadConnections,
                        child: _connections.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.6,
                                    child: Center(
                                      child: Text(
                                        'No connections yet',
                                        style: TextStyle(
                                          color: context.subTextColor,
                                          fontSize: 15.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                                itemCount: _connections.length,
                                itemBuilder: (context, index) =>
                                    _buildRow(_connections[index]),
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
