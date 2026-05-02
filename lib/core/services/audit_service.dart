import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  /// Appends a history entry to needs/{docId}/history subcollection.
  static Future<void> log(String docId, String action) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('needs')
        .doc(docId)
        .collection('history')
        .add({
      'action': action,
      'by': user?.displayName ?? user?.email ?? 'System',
      'byUid': user?.uid,
      'at': FieldValue.serverTimestamp(),
    });
  }
}
