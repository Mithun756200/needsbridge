import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/theme/app_theme.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [const ThemeToggleButton()],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Users & Roles'),
            Tab(icon: Icon(Icons.volunteer_activism), text: 'Volunteer Roster'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_UsersTab(), _VolunteersTab()],
      ),
    );
  }
}

// ── Tab 1: Users & Roles ──────────────────────────────────────────────────────
class _UsersTab extends ConsumerWidget {
  const _UsersTab();
  static const roles = ['field_staff','management','volunteer','executive'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return const EmptyState(icon: Icons.people_outline, message: 'No users yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final u = users[i];
            final uid = u['uid'] as String;
            final role = u['role'] as String? ?? 'field_staff';
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  CircleAvatar(
                    backgroundImage: u['photoURL'] != null ? NetworkImage(u['photoURL']) : null,
                    child: u['photoURL'] == null ? Text((u['displayName'] ?? '?')[0].toUpperCase()) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['displayName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(u['email'] ?? uid,
                          style: TextStyle(fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? NbColors.darkMuted : NbColors.lightMuted)),
                    ],
                  )),
                  DropdownButton<String>(
                    value: roles.contains(role) ? role : 'field_staff',
                    underline: const SizedBox(),
                    items: roles.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.toUpperCase(), style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    onChanged: (newRole) async {
                      if (newRole == null || newRole == role) return;
                      try {
                        await FirebaseFirestore.instance.collection('users').doc(uid)
                            .set({'role': newRole}, SetOptions(merge: true));
                        await AuditService.log('admin', 'Changed role of $uid to $newRole');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Role updated to ${newRole.toUpperCase()}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                        // Force provider refresh
                        ref.invalidate(allUsersProvider);
                        // If changing own role, trigger router refresh
                        if (uid == ref.read(authStateProvider).value?.uid) {
                          ref.invalidate(userRoleProvider);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to change role: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                  ),
                ]),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Tab 2: Volunteer Roster ───────────────────────────────────────────────────
class _VolunteersTab extends ConsumerWidget {
  const _VolunteersTab();

  void _showVolunteerDialog(BuildContext context, {Map<String, dynamic>? existing}) {
    final nameC = TextEditingController(text: existing?['name'] ?? '');
    final locC  = TextEditingController(text: existing?['location'] ?? '');
    final phC   = TextEditingController(text: existing?['phone'] ?? '');
    final skillC= TextEditingController(text: existing?['skills'] ?? '');
    bool available = existing?['available'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Add Volunteer' : 'Edit Volunteer'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name *')),
          const SizedBox(height: 10),
          TextField(controller: locC,  decoration: const InputDecoration(labelText: 'Location / Area')),
          const SizedBox(height: 10),
          TextField(controller: phC,   decoration: const InputDecoration(labelText: 'Phone Number')),
          const SizedBox(height: 10),
          TextField(controller: skillC,decoration: const InputDecoration(labelText: 'Skills (comma-separated)')),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Available'),
            value: available,
            onChanged: (v) => setState(() => available = v),
            contentPadding: EdgeInsets.zero,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty) return;
              final data = {
                'name': nameC.text.trim(),
                'location': locC.text.trim(),
                'phone': phC.text.trim(),
                'skills': skillC.text.trim(),
                'available': available,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              final col = FirebaseFirestore.instance.collection('staff_volunteers');
              if (existing != null) {
                await col.doc(existing['id']).update(data);
              } else {
                await col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volsAsync = ref.watch(staffVolunteersProvider);
    return Scaffold(
      body: volsAsync.when(
        data: (vols) {
          if (vols.isEmpty) return const EmptyState(
              icon: Icons.volunteer_activism, message: 'No volunteers yet.\nTap + to add one.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vols.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = vols[i];
              final available = v['available'] as bool? ?? false;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: available ? NbColors.low.withAlpha(40) : Colors.grey.withAlpha(40),
                    child: Icon(Icons.person, color: available ? NbColors.low : Colors.grey),
                  ),
                  title: Text(v['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((v['location'] ?? '').isNotEmpty) Text('📍 ${v['location']}'),
                    if ((v['phone'] ?? '').isNotEmpty) Text('📞 ${v['phone']}'),
                    if ((v['skills'] ?? '').isNotEmpty)
                      Text('🛠 ${v['skills']}', style: const TextStyle(fontSize: 11)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (available ? NbColors.low : Colors.grey).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(available ? 'Available' : 'Unavailable',
                          style: TextStyle(fontSize: 11,
                              color: available ? NbColors.low : Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () =>
                        _showVolunteerDialog(context, existing: v)),
                    IconButton(icon: const Icon(Icons.delete_rounded, color: NbColors.high),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete Volunteer?'),
                              content: Text('Remove ${v['name']} from the roster?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await FirebaseFirestore.instance
                                .collection('staff_volunteers').doc(v['id']).delete();
                          }
                        }),
                  ]),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVolunteerDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Volunteer'),
      ),
    );
  }
}
