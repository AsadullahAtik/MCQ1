import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livemcq_app/api.dart';
import 'package:livemcq_app/messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalizeBaseUrl adds http:// and removes the trailing slash', () {
    expect(normalizeBaseUrl('192.168.1.107:8080'), 'http://192.168.1.107:8080');
    expect(normalizeBaseUrl(' https://exam.example.com/ '), 'https://exam.example.com');
    expect(normalizeBaseUrl(''), '');
  });

  test('login stores the token and later calls send it', () async {
    final seen = <String>[];
    final api = Api(
      baseUrl: 'http://srv',
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path} auth=${req.headers['Authorization']}');
        if (req.url.path == '/api/auth/login') {
          return jsonResponse({'token': 'T1', 'tokenType': 'Bearer', 'expiresInSeconds': 3600, 'user': {'id': 1, 'role': 'STUDENT'}});
        }
        return jsonResponse([]);
      }),
    );
    final user = await api.login('demo', '1001', 'pw');
    expect(user['role'], 'STUDENT');
    expect(api.token, 'T1');
    await api.exams();
    expect(seen.last, 'GET /api/student/exams auth=Bearer T1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('livemcq.token'), 'T1');
  });

  test('a network failure becomes NETWORK with the technical reason', () async {
    final api = Api(baseUrl: 'http://srv', client: MockClient((req) async => throw Exception('Connection refused')));
    try {
      await api.exams();
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.code, 'NETWORK');
      expect(e.detail, contains('Connection refused'));
    }
  });

  test('server error codes are carried over', () async {
    final api = Api(baseUrl: 'http://srv', client: MockClient((req) async => jsonResponse({'code': 'TOO_MANY_ATTEMPTS'}, 429)));
    try {
      await api.login('demo', '1', 'x');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 429);
      expect(e.code, 'TOO_MANY_ATTEMPTS');
      expect(errorMessage(e), contains('অনেকবার'));
    }
  });

  test('401 UNAUTHENTICATED clears the token and signs the app out', () async {
    var signedOut = false;
    final api = Api(baseUrl: 'http://srv', client: MockClient((req) async => jsonResponse({'code': 'UNAUTHENTICATED'}, 401)));
    api.token = 'old';
    api.onSignedOut = () => signedOut = true;
    await expectLater(api.exams(), throwsA(isA<ApiException>()));
    expect(signedOut, isTrue);
    expect(api.token, isNull);
  });

  test('release and publish use POST to turn on and DELETE to turn off', () async {
    final calls = <String>[];
    final api = Api(baseUrl: 'http://srv', client: MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      return http.Response('', 200);
    }));
    await api.setReleased(5, true);
    await api.setReleased(5, false);
    await api.setPublished(5, true);
    await api.setPublished(5, false);
    expect(calls, [
      'POST /api/admin/exams/5/release',
      'DELETE /api/admin/exams/5/release',
      'POST /api/admin/exams/5/publish',
      'DELETE /api/admin/exams/5/publish',
    ]);
  });

  test('probe says null when the server is UP and explains otherwise', () async {
    final up = Api(baseUrl: 'http://srv', client: MockClient((req) async => jsonResponse({'status': 'UP'})));
    expect(await up.probe(), isNull);
    final down = Api(baseUrl: 'http://srv', client: MockClient((req) async => throw Exception('No route to host')));
    expect(await down.probe(), contains('No route to host'));
  });

  test('the saved server address survives a restart', () async {
    final a = Api(baseUrl: 'http://one', client: MockClient((req) async => jsonResponse([])));
    await a.setBaseUrl('192.168.0.9:8080');
    final b = Api(baseUrl: 'http://one', client: MockClient((req) async => jsonResponse([])));
    await b.restore();
    expect(b.baseUrl, 'http://192.168.0.9:8080');
  });
}
