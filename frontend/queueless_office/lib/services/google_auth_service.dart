import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Initialize Google Sign-In
      await _googleSignIn.initialize();

      // Start Google authentication
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // Get authentication information
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      return await _firebaseAuth.signInWithCredential(credential);

    } catch (e) {
      print("Office Google Sign-In Error: $e");
      return null;
    }
  }
}
