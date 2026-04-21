import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpResult {
  final UserCredential credential;
  final bool profileSaved;

  const SignUpResult({required this.credential, required this.profileSaved});
}

class UserVerificationState {
  final String uid;
  final String? role;
  final String verificationStatus;

  const UserVerificationState({
    required this.uid,
    required this.verificationStatus,
    this.role,
  });

  bool get isApproved => verificationStatus.toLowerCase() == 'approved';
}

class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
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
          'verificationStatus': 'pending',
          'isVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        profileSaved = true;
      } on FirebaseException {
        profileSaved = false;
      }
    }

    return SignUpResult(credential: credential, profileSaved: profileSaved);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateVerificationStatus({
    required String uid,
    required String verificationStatus,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'verificationStatus': verificationStatus,
      'isVerified': verificationStatus.toLowerCase() == 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserVerificationState?> getVerificationState({required String uid}) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    return UserVerificationState(
      uid: uid,
      role: data['role'] as String?,
      verificationStatus: (data['verificationStatus'] as String?) ??
          ((data['isVerified'] == true) ? 'approved' : 'pending'),
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
