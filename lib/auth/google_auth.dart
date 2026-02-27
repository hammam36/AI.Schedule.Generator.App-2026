import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:ai_schedule_generator/config/secret.dart';

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: webClientId,
  scopes: const [
    'email',
    gcal.CalendarApi.calendarScope, // https://www.googleapis.com/auth/calendar
  ],
);

class GoogleApiClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  GoogleApiClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    // debug: lihat header yang dikirim
    // ignore: avoid_print
    print('REQUEST ${request.url} HEADERS: ${request.headers}');
    return _inner.send(request);
  }
}

// Login biasa, dipakai di HomeScreen
Future<GoogleSignInAccount?> signInWithGoogle() async {
  return await googleSignIn.signIn();
}

Future<void> signOutFromGoogle() async {
  await googleSignIn.signOut();
}

/// Client ber-token untuk akses Google Calendar.
/// DI WEB: kita pakai authorizeScopes / authorizationForScope.
Future<http.Client?> getAuthenticatedClient() async {
  // pastikan sudah ada user
  final account = googleSignIn.currentUser ?? await googleSignIn.signIn();
  if (account == null) {
    // ignore: avoid_print
    print('getAuthenticatedClient: account NULL');
    return null;
  }

  const scope = gcal.CalendarApi.calendarScope;

  // cek apakah scope sudah di-authorize dan punya token
  var auth = await account.authorizationForScopes([scope]); // bisa null di web [web:213][web:216]
  if (auth == null || auth.accessToken == null) {
    // minta user authorize scope Calendar (muncul popup sekali lagi)
    // ignore: avoid_print
    print('getAuthenticatedClient: calling authorizeScopes for $scope');
    auth = await account.authorizeScopes([scope]);
  }

  final accessToken = auth.accessToken;
  if (accessToken == null) {
    // ignore: avoid_print
    print('getAuthenticatedClient: accessToken still NULL');
    return null;
  }

  // ignore: avoid_print
  print('getAuthenticatedClient: got accessToken (len=${accessToken.length})');

  final baseClient = http.Client();
  final headers = {
    'Authorization': 'Bearer $accessToken',
  };

  return GoogleApiClient(baseClient, headers);
}
