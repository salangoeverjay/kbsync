import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpResult {
  final UserCredential credential;
  final bool profileSaved;

  const SignUpResult({
    required this.credential,
    required this.profileSaved,
  });
}

class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    var profileSaved = false;
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(fullName.trim());
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': fullName.trim(),
          'email': email.trim(),
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        profileSaved = true;
      } on FirebaseException {
        profileSaved = false;
      }
    }

    return SignUpResult(
      credential: credential,
      profileSaved: profileSaved,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
