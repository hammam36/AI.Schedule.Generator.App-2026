import 'package:google_sign_in/google_sign_in.dart';
import 'package:ai_schedule_generator/config/secret.dart';

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: webClientId,
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar',
  ],
);

Future<GoogleSignInAccount?> signInWithGoogle() async {
  return await googleSignIn.signIn();
}

Future<void> signOutFromGoogle() async {
  await googleSignIn.signOut();
}