import 'package:google_sign_in/google_sign_in.dart';

// Ganti string di bawah dengan Web Client ID milikmu
const String webClientId =
    '1057332106363-85f2r4s0e51kl5k94umiagcldpe7gplp.apps.googleusercontent.com';

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: webClientId,
  scopes: [
    'email',
    // nanti kalau sudah aman, tambahkan scope calendar:
    'https://www.googleapis.com/auth/calendar',
  ],
);

Future<GoogleSignInAccount?> signInWithGoogle() async {
  return await googleSignIn.signIn();
}

Future<void> signOutFromGoogle() async {
  await googleSignIn.signOut();
}