import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isInitialized = false;

  Future<void> _initializeGoogleSignIn() async {
    if (_isInitialized) {
      return;
    }

    await _googleSignIn.initialize();
    _isInitialized = true;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _initializeGoogleSignIn();

      final GoogleSignInAccount googleUser =
      await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final OAuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);

      print('===== FIREBASE GOOGLE LOGIN =====');
      print('UID: ${userCredential.user?.uid}');
      print('Email: ${userCredential.user?.email}');
      print('Name: ${userCredential.user?.displayName}');
      print('=================================');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      return null;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('Sign Out Error: $e');
    }
  }
}