import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth ─────────────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) =>
    FirebaseAuth.instance.authStateChanges());

// ─── Role ─────────────────────────────────────────────────────────────────────
final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  if (!doc.exists) return 'field_staff';
  final role = doc.data()?['role'] as String?;
  if (role == 'admin') return 'management';
  if (role == 'coordinator') return 'field_staff';
  return role ?? 'field_staff';
});

// ─── Needs / Tasks ────────────────────────────────────────────────────────────
final needsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('needs').snapshots().map((s) {
    final docs = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    docs.sort((a, b) {
      final aC = a['status'] == 'Completed';
      final bC = b['status'] == 'Completed';
      if (aC && !bC) return 1;
      if (!aC && bC) return -1;
      final aNew = a['status'] == 'Awaiting Field Assignment' ||
          a['status'] == 'Verification Assigned';
      final bNew = b['status'] == 'Awaiting Field Assignment' ||
          b['status'] == 'Verification Assigned';
      if (aNew && !bNew) return -1;
      if (!aNew && bNew) return 1;
      final pA = a['priority'] as int? ?? 3;
      final pB = b['priority'] as int? ?? 3;
      if (pA != pB) return pA.compareTo(pB);
      final tA = a['createdAt'] as Timestamp?;
      final tB = b['createdAt'] as Timestamp?;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });
    return docs;
  });
});

// ─── NGO Data Collections ─────────────────────────────────────────────────────
final financesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        FirebaseFirestore.instance.collection('finances').snapshots().map(
            (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()));

final donorsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        FirebaseFirestore.instance.collection('donors').snapshots().map(
            (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()));

final beneficiariesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        FirebaseFirestore.instance.collection('beneficiaries').snapshots().map(
            (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()));

final staffVolunteersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        FirebaseFirestore.instance
            .collection('staff_volunteers')
            .orderBy('name')
            .snapshots()
            .map((s) =>
                s.docs.map((d) => {'id': d.id, ...d.data()}).toList()));

// ─── All users (admin panel) ──────────────────────────────────────────────────
final allUsersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        FirebaseFirestore.instance.collection('users').snapshots().map(
            (s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList()));
