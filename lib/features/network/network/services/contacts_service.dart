import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/network_user.dart';

class ContactsService {
  final _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream the current user's contact uid list
  Stream<List<String>> streamContactIds() {
    return _db.collection('users').doc(_uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return [];
      return List<String>.from(data['contacts'] ?? []);
    });
  }

  /// Fetch a single user document by uid
  Future<NetworkUser?> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return NetworkUser.fromFirestore(doc);
  }

  /// Search users by email prefix, excluding self and existing contacts
  Future<List<NetworkUser>> searchByEmail(
      String query, List<String> existingContactIds) async {
    if (query.trim().isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('email',
            isGreaterThanOrEqualTo: query.trim().toLowerCase())
        .where('email',
            isLessThanOrEqualTo: '${query.trim().toLowerCase()}\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map(NetworkUser.fromFirestore)
        .where((u) => u.uid != _uid && !existingContactIds.contains(u.uid))
        .toList();
  }

  /// Add a contact uid to the current user's contacts array
  Future<void> addContact(String contactUid) async {
    await _db.collection('users').doc(_uid).set({
      'contacts': FieldValue.arrayUnion([contactUid]),
    }, SetOptions(merge: true));
  }

  /// Remove a contact uid from the current user's contacts array
  Future<void> removeContact(String contactUid) async {
    await _db.collection('users').doc(_uid).update({
      'contacts': FieldValue.arrayRemove([contactUid]),
    });
  }
}