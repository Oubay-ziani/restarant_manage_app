import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getAdminProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    // Authenticate email and password
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // Verify user profile role in Firestore to enforce "Admin login only"
    final profile = await getAdminProfile(cred.user!.uid);
    if (profile == null || profile.role != 'admin') {
      // If profile doesn't exist, create a default admin profile for convenience (or reject)
      if (profile == null) {
        final newAdmin = UserModel(
          uid: cred.user!.uid,
          email: email,
          name: email.split('@').first.toUpperCase(),
          role: 'admin',
        );
        await _db.collection('users').doc(cred.user!.uid).set(newAdmin.toMap());
      } else {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-authorized',
          message: 'Access Denied: Only Admin credentials can sign in.',
        );
      }
    }
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Riverpod Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentAdminUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;
  return ref.watch(authRepositoryProvider).getAdminProfile(authState.uid);
});
