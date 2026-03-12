import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/storage_service.dart';
import '../core/services/logger_service.dart';
import '../models/app_user.dart';

/// Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Stream of Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Current AppUser profile from Firestore
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (doc.exists) {
    return AppUser.fromJson(doc.data()!);
  }
  return null;
});

/// Auth actions
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  /// Sign up with email/password and create user profile
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? company,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName(name);

    final appUser = AppUser(
      uid: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      phone: phone,
      company: company,
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(appUser.uid).set(appUser.toJson());

    return appUser;
  }

  /// Sign in with email/password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Update user's country
  Future<void> updateCountry(String uid, String countryCode) async {
    await _db.collection('users').doc(uid).update({
      'country': countryCode,
    });
  }

  /// Update user's profile information
  Future<void> updateProfile({
    required String uid,
    String? name,
    String? phone,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) {
      updates['name'] = name;
      await _auth.currentUser?.updateDisplayName(name);
    }
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }

  /// Update user's password
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw Exception('No user is currently signed in');
    }
  }

  /// Update user's avatar
  Future<String> updateAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileName,
    required StorageService storageService,
  }) async {
    final path = '$uid/$fileName';
    
    // Upload bytes
    final url = await storageService.uploadFile(
      bytes: bytes,
      path: path,
      contentType: 'image/jpeg',
    );
    
    // Update Firestore
    await _db.collection('users').doc(uid).update({
      'avatarUrl': url,
    });
    
    // Update Firebase Auth profile
    await _auth.currentUser?.updatePhotoURL(url);
    
    Log.i('Avatar updated successfully for user $uid. URL: $url');
    return url;
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    db: FirebaseFirestore.instance,
  );
});