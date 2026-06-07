import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;

  // Register
  Future<String?> register({
    required String username,
    required String email,
    required String password,
    Uint8List? photoBytes,
    String photoExtension = '.jpg',
  }) async {
    try {
      print('🟡 Step 1: Mencoba buat akun Firebase Auth...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Step 1 berhasil: UID = ${credential.user!.uid}');

      String photoUrl = '';
      if (photoBytes != null) {
        print('🟡 Step 2: Upload foto...');
        photoUrl = await StorageService.uploadProfilePhoto(
          uid: credential.user!.uid,
          bytes: photoBytes,
          extension: photoExtension,
        );
        print('✅ Step 2 berhasil: photoUrl = $photoUrl');
      } else {
        print('⏭️ Step 2: Skip upload foto');
      }

      print('🟡 Step 3: Simpan data user ke Firestore...');
      final user = UserModel(
        uid: credential.user!.uid,
        username: username,
        email: email,
        photoUrl: photoUrl,
        online: true,
        lastSeen: Timestamp.now(),
        contacts: [],
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toMap());
      print('✅ Step 3 berhasil!');

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      print('🔴 FirebaseAuthException: code=${e.code}, message=${e.message}');
      return _authError(e.code);
    } catch (e) {
      print('🔴 General error: $e');
      return e.toString();
    }
  }

  // Login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      print('🔴 Firebase login error code: ${e.code}');
      print('🔴 Firebase login error message: ${e.message}');
      return _authError(e.code);
    } catch (e) {
      print('🔴 General login error: $e');
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _firestore.collection('users').doc(currentUid).update({
        'online': false,
        'lastSeen': Timestamp.now(),
        'inRoom': false,
        'currentRoom': '',
      });
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    if (currentUid == null) return null;
    final doc = await _firestore.collection('users').doc(currentUid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  // Update profile
  Future<String?> updateProfile({
    required String username,
    Uint8List? photoBytes,
    String photoExtension = '.jpg',
  }) async {
    try {
      String? photoUrl;
      if (photoBytes != null) {
        photoUrl = await StorageService.uploadProfilePhoto(
          uid: currentUid!,
          bytes: photoBytes,
          extension: photoExtension,
        );
      }

      final Map<String, dynamic> updateData = {'username': username};
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;

      await _firestore.collection('users').doc(currentUid).update(updateData);

      notifyListeners();
      return null;
    } catch (e) {
      print('🔴 Update profile error: $e');
      return e.toString();
    }
  }

  // Change password (requires re-authentication first)
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not authenticated';
      if (user.email == null) return 'No email associated with this account';

      // Re-authenticate with old password first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Now update password
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Password lama salah.';
      }
      if (e.code == 'weak-password') {
        return 'Password baru terlalu lemah (minimal 6 karakter).';
      }
      return _authError(e.code);
    } catch (e) {
      return e.toString();
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah digunakan.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }
}
