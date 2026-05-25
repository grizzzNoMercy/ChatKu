import 'dart:io';
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
    File? photoFile,
  }) async {
    try {
      print('🟡 Step 1: Mencoba buat akun Firebase Auth...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Step 1 berhasil: UID = ${credential.user!.uid}');

      String photoUrl = '';
      if (photoFile != null) {
        print('🟡 Step 2: Upload foto...');
        photoUrl = await StorageService.uploadProfilePhoto(
          uid: credential.user!.uid,
          file: photoFile,
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
    File? photoFile,
  }) async {
    try {
      String? photoUrl;
      if (photoFile != null) {
        photoUrl = await StorageService.uploadProfilePhoto(
          uid: currentUid!,
          file: photoFile,
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
