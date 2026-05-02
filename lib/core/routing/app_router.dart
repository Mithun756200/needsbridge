import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/heat_map_widget.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../features/dashboard/views/admin_screen.dart';
import '../../features/dashboard/views/executive_dashboard.dart';
import '../../features/issues/views/public_report_screen.dart';
import '../../features/issues/views/report_screen.dart';

// Re-export providers so existing code keeps working
export '../../core/providers/app_providers.dart';
export '../../core/theme/app_theme.dart';

// ── GoRouter ──────────────────────────────────────────────────────────────────
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final roleAsync = ref.read(userRoleProvider);
      if (authState.isLoading || roleAsync.isLoading) {
        return state.matchedLocation == '/' ? null : '/';
      }
      final isLoggedIn = authState.value != null;
      final loc = state.matchedLocation;
      if (!isLoggedIn) {
        if (loc == '/public-report') return null;
        return loc == '/login' ? null : '/login';
      }
      final role = roleAsync.value ?? 'management'; // Default to management for easy testing
      if (loc == '/login' || loc == '/' || loc == '/public-report') {
        return switch (role) {
          'board'       => '/board',
          'executive'   => '/executive',
          'field_staff' => '/field',
          'volunteer'   => '/volunteer',
          _             => '/management',
        };
      }
      // Temporarily disabled strict role locks for hackathon testing
      // if (loc.startsWith('/board')      && role != 'board')       return '/';
      // if (loc.startsWith('/executive')  && role != 'executive')   return '/';
      // if (loc.startsWith('/management') && role != 'management')  return '/';
      // if (loc.startsWith('/volunteer')  && role != 'volunteer')   return '/';
      // if (loc.startsWith('/field')      && role != 'field_staff') return '/';
      // if (loc.startsWith('/admin')      && role != 'management')  return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/',             builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login',        builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/public-report',builder: (_, __) => const PublicReportScreen()),
      GoRoute(path: '/board',        builder: (_, __) => const BoardDashboardScreen()),
      GoRoute(path: '/executive',    builder: (_, __) => const ExecutiveDashboardScreen()),
      GoRoute(path: '/management',   builder: (_, __) => const ManagementDashboardScreen()),
      GoRoute(path: '/field',        builder: (_, __) => const FieldStaffDashboardScreen()),
      GoRoute(path: '/volunteer',    builder: (_, __) => const VolunteerDashboardScreen()),
      GoRoute(path: '/report',       builder: (_, __) => const ReportScreen()),
      GoRoute(path: '/admin',        builder: (_, __) => const AdminScreen()),
    ],
  );
  ref.listen(authStateProvider, (_, __) => router.refresh());
  ref.listen(userRoleProvider,  (_, __) => router.refresh());
  return router;
});

// ── Login Screen ──────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      UserCredential cred;
      if (kIsWeb) {
        cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
        cred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // ── Save display name, email, photo to Firestore (fixes "Unknown") ──
      final user = cred.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': user.displayName ?? user.email ?? 'Staff Member',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // FCM token (mobile only)
        if (!kIsWeb) {
          final messaging = FirebaseMessaging.instance;
          await messaging.requestPermission();
          final token = await messaging.getToken();
          Future<void> saveToken(String t) async {
            await FirebaseFirestore.instance
                .collection('users').doc(user.uid)
                .collection('fcmTokens').doc(t)
                .set({'token': t, 'updatedAt': FieldValue.serverTimestamp()},
                    SetOptions(merge: true));
          }
          if (token != null) await saveToken(token);
          messaging.onTokenRefresh.listen(saveToken);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ThemeToggleButton(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub_rounded, size: 64, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text('NeedsBridge', style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Connecting communities to help',
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                  ? NbColors.darkMuted : NbColors.lightMuted)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => _signIn(context, ref),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Staff Sign In (Google)'),
          ),
          const SizedBox(height: 16),
          const Text('or', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/public-report'),
            icon: const Icon(Icons.campaign_rounded),
            label: const Text('Report a Community Issue'),
          ),
        ]),
      ))),
    );
  }
}

// ── Management Dashboard ───────────────────────────────────────────────────────
class ManagementDashboardScreen extends ConsumerWidget {
  const ManagementDashboardScreen({super.key});

  // AI Advanced Match Scoring: 60% Skills, 40% Proximity
  List<String> _getAiSuggestions(WidgetRef ref, int needed, String issueTitle, String issueLocation) {
    final vols = ref.read(staffVolunteersProvider).value ?? [];
    if (vols.isEmpty) return [];
    final available = vols.where((v) => v['available'] as bool? ?? true).toList();
    if (available.isEmpty) return vols.take(needed).map((v) => v['name'] as String? ?? '').toList();
    final keywords = issueTitle.toLowerCase();
    final issueLocLower = issueLocation.toLowerCase();

    List<Map<String, dynamic>> scoredVols = available.map((v) {
      final skills = (v['skills'] as String? ?? '').toLowerCase();
      final loc = (v['location'] as String? ?? '').toLowerCase();
      double score = 0;
      // Broader skill matching
      if (keywords.contains('fire') && (skills.contains('rescue') || skills.contains('fire') || skills.contains('first aid') || skills.contains('emergency'))) score += 60;
      if (keywords.contains('flood') && (skills.contains('rescue') || skills.contains('water') || skills.contains('sanitation') || skills.contains('swimming') || skills.contains('emergency'))) score += 60;
      if (keywords.contains('medical') || keywords.contains('injur') || keywords.contains('hospital')) {
        if (skills.contains('medical') || skills.contains('doctor') || skills.contains('nurse') || skills.contains('first aid') || skills.contains('health')) score += 60;
      }
      if (keywords.contains('food') && (skills.contains('food') || skills.contains('cook') || skills.contains('nutrition'))) score += 60;
      if (keywords.contains('road') || keywords.contains('infrastructure')) {
        if (skills.contains('engineer') || skills.contains('construction') || skills.contains('repair')) score += 60;
      }
      // Proximity match — check if any word in volunteer location appears in issue location
      if (loc.isNotEmpty && issueLocLower.isNotEmpty) {
        for (final word in loc.split(' ')) {
          if (word.length > 2 && issueLocLower.contains(word)) { score += 40; break; }
        }
      }
      // If no skill match at all, give base score so we always fill slots
      if (score == 0) score = 10;
      return {...v, 'matchScore': score};
    }).toList();

    scoredVols.sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));
    return scoredVols.take(needed).map((v) => v['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
  }

  // Assign volunteers — AI pre-selects, management approves
  Future<void> _assignVolunteers(
      BuildContext ctx, WidgetRef ref, String docId, int needed,
      String issueTitle, String issueLocation) async {
    // Force fresh read from Firestore
    final snapshot = await FirebaseFirestore.instance.collection('staff_volunteers').get();
    final vols = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    
    if (vols.isEmpty) {
      await showDialog(context: ctx, builder: (_) => AlertDialog(
        title: const Text('No Volunteers Available'),
        content: const Text('Please add volunteers in the Admin Panel first.\n\nGo to Admin Panel > Volunteer Roster tab to add volunteers with their skills and locations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ));
      return;
    }
    
    final available = vols.where((v) => v['available'] as bool? ?? true).toList();
    final showList = available.isEmpty ? vols : available;
    final aiPicked = _getAiSuggestions(ref, needed, issueTitle, issueLocation);

    // Score all volunteers for display
    final keywords = issueTitle.toLowerCase();
    final issueLocLower = issueLocation.toLowerCase();
    final scoredList = showList.map((v) {
      final skills = (v['skills'] as String? ?? '').toLowerCase();
      final loc = (v['location'] as String? ?? '').toLowerCase();
      double score = 10;
      if (keywords.contains('fire') && (skills.contains('rescue') || skills.contains('fire') || skills.contains('first aid') || skills.contains('emergency'))) score = 100;
      else if (keywords.contains('flood') && (skills.contains('rescue') || skills.contains('water') || skills.contains('sanitation') || skills.contains('emergency'))) score = 100;
      else if ((keywords.contains('medical') || keywords.contains('injur')) && (skills.contains('medical') || skills.contains('nurse') || skills.contains('first aid'))) score = 100;
      if (loc.isNotEmpty && issueLocLower.isNotEmpty) {
        for (final word in loc.split(' ')) {
          if (word.length > 2 && issueLocLower.contains(word)) { score += 40; break; }
        }
      }
      return {...v, 'matchScore': score};
    }).toList()
      ..sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));

    List<String> selected = List.from(aiPicked);
    String filter = '';

    await showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (ctx, setState) {
        final filtered = scoredList.where((v) =>
            filter.isEmpty ||
            (v['location'] ?? '').toLowerCase().contains(filter.toLowerCase()) ||
            (v['name'] ?? '').toLowerCase().contains(filter.toLowerCase())).toList();
        return AlertDialog(
          title: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Assign Volunteers  (Need: $needed)'),
            if (aiPicked.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('AI pre-selected ${aiPicked.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.amber)),
                ]),
              ),
          ]),
          content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Search by name or area',
                  prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => filter = v),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(12),
                  child: Text('No volunteers match.'))
            else Flexible(child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final v = filtered[i];
                final name = v['name'] as String? ?? '';
                final isAiPick = aiPicked.contains(name);
                return CheckboxListTile(
                  dense: true,
                  title: Row(children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (isAiPick) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.amber),
                    ],
                  ]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${v['location'] ?? ''}'
                        '${(v['skills'] ?? '').isNotEmpty ? '  •  ${v['skills']}' : ''}',
                        style: const TextStyle(fontSize: 11)),
                    if (v['matchScore'] != null && (v['matchScore'] as double) > 0)
                      Text('Match Score: ${(v['matchScore'] as double).toInt()}%',
                          style: TextStyle(fontSize: 10, color: (v['matchScore'] as double) > 80 ? Colors.green : Colors.orange)),
                  ]),
                  value: selected.contains(name),
                  onChanged: (val) => setState(() =>
                      val == true ? selected.add(name) : selected.remove(name)),
                );
              },
            )),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty ? null : () async {
                await FirebaseFirestore.instance.collection('needs').doc(docId).update(
                    {'status': 'Assigned', 'assignedTo': selected.join(', ')});
                await AuditService.log(docId,
                    'Volunteers approved by management: ${selected.join(', ')}'
                    '${aiPicked.isNotEmpty ? ' (AI suggested: ${aiPicked.join(", ")})' : ''}');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Approve & Assign (${selected.length})'),
            ),
          ],
        );
      },
    ));
  }

  Future<void> _advancePhase(String docId, String currentStatus) async {
    final next = switch(currentStatus) {
      'Response' => 'Relief',
      'Relief' => 'Rehabilitation',
      _ => 'Resolved',
    };
    await FirebaseFirestore.instance.collection('needs').doc(docId).update({'status': next});
    await AuditService.log(docId, 'Phase advanced to: $next');
  }

  bool _isOverdue(Map<String, dynamic> n) {
    if (n['status'] != 'Response') return false;
    final createdAt = n['createdAt'] as Timestamp?;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt.toDate()).inHours > 4; // Simulated 4h limit
  }

  Future<void> _deleteTask(BuildContext ctx, String docId) async {
    final ok = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
      title: const Text('Delete Task?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      await FirebaseFirestore.instance.collection('needs').doc(docId).delete();
    }
  }

  Future<void> _showNewsMonitorDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.newspaper_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text('Real-Time News Monitor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('needs')
                      .where('source', isEqualTo: 'news_auto')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No news alerts available',
                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('${snapshot.error}',
                                style: const TextStyle(fontSize: 10, color: Colors.red)),
                          ],
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No news alerts available',
                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('News monitoring runs every 10 minutes',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    
                    // Sort by createdAt manually
                    final sortedDocs = docs.toList();
                    sortedDocs.sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                    });
                    
                    return ListView.separated(
                      itemCount: sortedDocs.take(20).length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final data = sortedDocs[i].data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Unknown';
                        final location = data['location'] ?? 'Unknown';
                        final priority = data['priority'] as int? ?? 3;
                        final category = data['category'] ?? 'Other';
                        final newsLink = data['newsLink'] as String?;
                        final createdAt = data['createdAt'] as Timestamp?;
                        final timeAgo = createdAt != null
                            ? _formatTimeAgo(DateTime.now().difference(createdAt.toDate()))
                            : 'Just now';
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: priority == 1
                                ? NbColors.high.withAlpha(40)
                                : priority == 2
                                    ? NbColors.medium.withAlpha(40)
                                    : NbColors.low.withAlpha(40),
                            child: Icon(
                              Icons.newspaper,
                              size: 20,
                              color: priority == 1
                                  ? NbColors.high
                                  : priority == 2
                                      ? NbColors.medium
                                      : NbColors.low,
                            ),
                          ),
                          title: Text(title, style: const TextStyle(fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📍 $location  •  $category',
                                  style: const TextStyle(fontSize: 11)),
                              Text(timeAgo,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          trailing: newsLink != null
                              ? IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  onPressed: () async {
                                    final url = Uri.parse(newsLink);
                                    if (await canLaunchUrl(url)) await launchUrl(url);
                                  },
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAsync = ref.watch(needsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management'),
        actions: [
          IconButton(icon: const Icon(Icons.newspaper_rounded, color: Colors.indigo),
              onPressed: () => _showNewsMonitorDialog(context), tooltip: 'News Monitor'),
          IconButton(icon: const Icon(Icons.admin_panel_settings_rounded),
              onPressed: () => context.push('/admin'), tooltip: 'Admin Panel'),
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: needsAsync.when(
        data: (needs) {
          if (needs.isEmpty) return const EmptyState(icon: Icons.list_alt_rounded, message: 'No tasks yet.');
          
          final resolvedCount = needs.where((n) => n['status'] == 'Resolved').length;
          final activeCount = needs.length - resolvedCount;
          
          // Sort so overdue/escalated items are at the top
          final sortedNeeds = List<Map<String, dynamic>>.from(needs);
          sortedNeeds.sort((a, b) {
            final aOverdue = _isOverdue(a) ? 1 : 0;
            final bOverdue = _isOverdue(b) ? 1 : 0;
            if (aOverdue != bOverdue) return bOverdue.compareTo(aOverdue);
            final aResolved = a['status'] == 'Resolved' ? 1 : 0;
            final bResolved = b['status'] == 'Resolved' ? 1 : 0;
            return aResolved.compareTo(bResolved);
          });

          return Column(children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Theme.of(context).cardColor,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _Stat('Active', '$activeCount', NbColors.medium),
                const SizedBox(width: 1, height: 24, child: VerticalDivider()),
                _Stat('Resolved', '$resolvedCount', NbColors.low),
                const SizedBox(width: 1, height: 24, child: VerticalDivider()),
                _Stat('Total', '${needs.length}', NbColors.info),
              ]),
            ),
            const HeatMapButton(),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sortedNeeds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = sortedNeeds[i];
                final docId = n['id'] as String;
                final status = n['status'] as String? ?? 'Response';
                final isResolved = status == 'Resolved';
                final isOverdue = _isOverdue(n);
                final priority = n['priority'] as int? ?? 3;
                final assignee = n['assignedTo'] as String?;
                final imageUrl = n['imageUrl'] as String?;

                final reportCount = n['reportCount'] as int? ?? 1;
                return Card(
                  elevation: isOverdue ? 8 : 1,
                  shadowColor: isOverdue ? Colors.redAccent.withAlpha(150) : null,
                  shape: isOverdue ? RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.redAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ) : null,
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (imageUrl != null && imageUrl.startsWith('https'))
                        ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover)),
                      if (imageUrl != null) const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['title'] ?? 'Unknown',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                                  decoration: isResolved ? TextDecoration.lineThrough : null)),
                          if (reportCount > 1)
                            Text('⚠️ $reportCount people reported this',
                                style: const TextStyle(fontSize: 11, color: Colors.orange)),
                        ],
                      )),
                      PriorityBadge(priority),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      StatusChip(status),
                      if (n['category'] != null) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(n['category'], style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.indigo.withAlpha(50),
                          side: BorderSide.none,
                        ),
                      ],
                      if (n['source'] == 'public') ...[
                        const SizedBox(width: 6),
                        const Chip(
                          label: Text('Public', style: TextStyle(fontSize: 10)),
                          avatar: Icon(Icons.people_rounded, size: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      if (isOverdue) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                          child: const Text('ESCALATED', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      ]
                    ]),
                    if (assignee != null) Text('👥 Volunteers: $assignee',
                        style: const TextStyle(fontSize: 12))
                    else if (_getAiSuggestions(ref, n['volunteersNeeded'] as int? ?? 1, n['title'] as String? ?? '', n['location'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('🤖 AI Suggests: ${_getAiSuggestions(ref, n['volunteersNeeded'] as int? ?? 1, n['title'] as String? ?? '', n['location'] as String? ?? '').join(', ')}',
                          style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text('⚠️ No volunteers available. Add volunteers in Admin Panel.',
                          style: TextStyle(fontSize: 11, color: Colors.orange)),
                    ],
                    if (n['location'] != null) Text('📍 ${n['location']}',
                        style: const TextStyle(fontSize: 12)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('needs')
                          .doc(docId)
                          .collection('field_reports')
                          .orderBy('submittedAt', descending: true)
                          .limit(3)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                        final reports = snapshot.data!.docs;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withAlpha(60)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.description_rounded, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text('Field Reports (${reports.length})', 
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ]),
                              const SizedBox(height: 4),
                              ...reports.take(2).map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final report = data['report'] as String? ?? '';
                                final by = data['submittedBy'] as String? ?? 'Staff';
                                final time = data['submittedAt'] as Timestamp?;
                                final timeStr = time != null 
                                    ? _formatTimeAgo(DateTime.now().difference(time.toDate()))
                                    : 'Just now';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('• $report\n  — $by, $timeStr',
                                      style: const TextStyle(fontSize: 10)),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (!isResolved) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.group_add_rounded, size: 16),
                          label: Text(assignee != null ? 'Edit Volunteers' : 'Review AI Suggestions'),
                          onPressed: () => _assignVolunteers(
                              ctx, ref, docId,
                              n['volunteersNeeded'] as int? ?? 1,
                              n['title'] as String? ?? '',
                              n['location'] as String? ?? ''),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.forward_rounded, size: 16),
                          label: Text(status == 'Rehabilitation' ? 'Resolve' : 'Advance Phase'),
                          onPressed: () => _advancePhase(docId, status),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 18, color: NbColors.high),
                        onPressed: () => _deleteTask(ctx, docId),
                      ),
                    ]),
                  ]),
                ));
              },
            )),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);
}

// ── Field Staff Dashboard ──────────────────────────────────────────────────────
class FieldStaffDashboardScreen extends ConsumerWidget {
  const FieldStaffDashboardScreen({super.key});

  Future<void> _advancePhase(String docId, String currentStatus) async {
    final next = switch(currentStatus) {
      'Response' => 'Relief',
      'Relief' => 'Rehabilitation',
      _ => 'Resolved',
    };
    await FirebaseFirestore.instance.collection('needs').doc(docId).update({'status': next});
    await AuditService.log(docId, 'Field staff advanced phase to: $next');
  }

  Future<void> _navigate(String location) async {
    final parts = location.split(',');
    String query;
    if (parts.length == 2 && double.tryParse(parts[0].trim()) != null) {
      query = '${parts[0].trim()},${parts[1].trim()}';
    } else {
      query = Uri.encodeComponent('$location, Tamil Nadu, India');
    }
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _submitReport(BuildContext ctx, String docId, String issueTitle) async {
    final reportC = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Submit Field Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: $issueTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: reportC,
              decoration: const InputDecoration(
                labelText: 'Report Details',
                hintText: 'Enter observations, progress, or updates...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reportC.text.trim().isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance.collection('needs').doc(docId).collection('field_reports').add({
                'report': reportC.text.trim(),
                'submittedBy': user?.displayName ?? user?.email ?? 'Field Staff',
                'submittedAt': FieldValue.serverTimestamp(),
              });
              await AuditService.log(docId, 'Field report submitted: ${reportC.text.trim().substring(0, reportC.text.length > 50 ? 50 : reportC.text.length)}...');
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('✅ Report submitted to management'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Staff'),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),

      body: ref.watch(needsProvider).when(
        data: (needs) {
          final myTasks = needs.where((n) => n['status'] != 'Resolved').toList();
          return Column(children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withAlpha(60)),
              ),
              child: Row(children: [
                Icon(Icons.report_problem_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('See something in the field?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Tap below to report. AI scores priority instantly.',
                        style: TextStyle(fontSize: 12)),
                  ],
                )),
                ElevatedButton.icon(
                  onPressed: () => context.push('/report'),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Report'),
                ),
              ]),
            ),
            const HeatMapButton(),
            if (myTasks.isEmpty)
              const Expanded(child: EmptyState(
                  icon: Icons.task_alt_rounded, message: 'No active tasks assigned.'))
            else Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: myTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = myTasks[i];
                final docId = n['id'] as String;
                final imageUrl = n['imageUrl'] as String?;
                final location = n['location'] as String?;

                return Card(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (imageUrl != null && imageUrl.startsWith('https'))
                        ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover))
                      else PriorityBadge(n['priority'] as int? ?? 3),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        StatusChip(n['status'] ?? ''),
                      ])),
                    ]),
                    if (location != null) ...[
                      const SizedBox(height: 6),
                      Text('📍 $location', style: const TextStyle(fontSize: 12)),
                    ],
                    if (n['assignedTo'] != null)
                      Text('👥 ${n['assignedTo']}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (location != null)
                        OutlinedButton.icon(
                          onPressed: () => _navigate(location),
                          icon: const Icon(Icons.navigation_rounded, size: 16, color: NbColors.info),
                          label: const Text('Navigate', style: TextStyle(color: NbColors.info, fontSize: 13)),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _submitReport(ctx, docId, n['title'] ?? 'Issue'),
                        icon: const Icon(Icons.description_rounded, size: 16),
                        label: const Text('Submit Report', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _advancePhase(docId, n['status'] as String? ?? 'Response'),
                        child: Text(n['status'] == 'Rehabilitation' ? 'Resolve' : 'Advance'),
                      ),
                    ]),
                  ]),
                ));
              },
            )),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Volunteer Dashboard ────────────────────────────────────────────────────────
class VolunteerDashboardScreen extends ConsumerWidget {
  const VolunteerDashboardScreen({super.key});

  Future<void> _navigate(String location) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Tasks'),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: ref.watch(needsProvider).when(
        data: (needs) {
          final mine = needs.where((n) => n['status'] == 'Assigned').toList();
          if (mine.isEmpty) return const EmptyState(
              icon: Icons.assignment_turned_in_rounded,
              message: 'No tasks assigned to you yet.');
          return Column(children: [
            const HeatMapButton(),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = mine[i];
                final docId = n['id'] as String;
                final imageUrl = n['imageUrl'] as String?;
                return Card(child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: imageUrl != null && imageUrl.startsWith('https')
                      ? ClipRRect(borderRadius: BorderRadius.circular(8),
                          child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover))
                      : const Icon(Icons.assignment_rounded, size: 40, color: NbColors.low),
                  title: Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PriorityBadge(n['priority'] as int? ?? 3),
                    if (n['location'] != null) Text('📍 ${n['location']}',
                        style: const TextStyle(fontSize: 12)),
                    if (n['volunteersNeeded'] != null)
                      Text('Volunteers needed: ${n['volunteersNeeded']}',
                          style: const TextStyle(fontSize: 12)),
                  ]),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.navigation_rounded, color: NbColors.info),
                        onPressed: () => _navigate(n['location'] ?? ''), tooltip: 'Navigate'),
                    IconButton(icon: const Icon(Icons.check_circle_rounded, color: NbColors.low),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('needs').doc(docId).update({'status': 'Completed'});
                          await AuditService.log(docId, 'Marked Completed by volunteer');
                        }, tooltip: 'Mark Complete'),
                  ]),
                ));
              },
            )),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Board Dashboard ────────────────────────────────────────────────────────────
class BoardDashboardScreen extends ConsumerWidget {
  const BoardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAsync = ref.watch(needsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board of Directors'),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: needsAsync.when(
        data: (needs) {
          final high = needs.where((n) => (n['priority'] as int? ?? 3) == 1 && n['status'] != 'Resolved').length;
          final total = needs.length;
          final done = needs.where((n) => n['status'] == 'Resolved').length;
          
          // Calculate Active Volunteers Deployed
          int activeVols = 0;
          for (final n in needs) {
            if (n['status'] != 'Resolved' && n['assignedTo'] != null) {
              activeVols += (n['assignedTo'] as String).split(',').length;
            }
          }
          
          // Estimate Affected Families (Metrics for FIR/PDNA)
          final familiesAffected = total * 4; // Simulated multiplier

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader('Strategic Overview (FIR / PDNA Data)'),
              Row(children: [
                Expanded(child: KpiCard(label: 'Total Issues', value: '$total',
                    icon: Icons.list_alt_rounded, color: NbColors.info)),
                const SizedBox(width: 12),
                Expanded(child: KpiCard(label: 'Critical', value: '$high',
                    icon: Icons.crisis_alert_rounded, color: NbColors.high)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: KpiCard(label: 'Vols Deployed', value: '$activeVols',
                    icon: Icons.group_rounded, color: NbColors.medium)),
                const SizedBox(width: 12),
                Expanded(child: KpiCard(label: 'Est. Families Affected', value: '$familiesAffected',
                    icon: Icons.family_restroom_rounded, color: Colors.purple)),
              ]),
              const SectionHeader('Geographic Activity'),
              const HeatMapButton(),
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Heat Map Widget (canvas-based, no Google Maps API needed) ──────────────────
// (classes HeatMapButton, _HeatMapDialogContent, _HeatMapCanvas, _HeatMapPainter
//  are defined in lib/core/widgets/heat_map_widget.dart)