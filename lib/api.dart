import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'messages.dart';

/// The default server address, set at build time:  flutter run --dart-define=API_URL=https://exam.example.com
/// It can also be changed inside the app (login screen, "সার্ভার ঠিকানা"), so a new IP needs no new APK.
const defaultApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080'); // 10.0.2.2 = the PC, seen from the Android emulator

String normalizeBaseUrl(String input) {
  var u = input.trim();
  if (u.isEmpty) return u;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u'; // "192.168.1.107:8080" -> http://...
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// One object for every call to the server. It remembers the server address and the token (on the phone's
/// storage) and tells the app when the token stopped working, so the app can go back to the login screen.
class Api {
  Api({String? baseUrl, http.Client? client})
      : baseUrl = normalizeBaseUrl(baseUrl ?? defaultApiUrl),
        _client = client ?? http.Client();

  String baseUrl;
  final http.Client _client;
  String? token;

  /// Called when the server answers 401 to an authenticated call.
  void Function()? onSignedOut;

  static const _tokenKey = 'livemcq.token';
  static const _urlKey = 'livemcq.serverUrl';

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_tokenKey);
    final saved = p.getString(_urlKey);
    if (saved != null && saved.isNotEmpty) baseUrl = saved;
  }

  Future<void> setBaseUrl(String value) async {
    baseUrl = normalizeBaseUrl(value);
    final p = await SharedPreferences.getInstance();
    await p.setString(_urlKey, baseUrl);
  }

  Future<void> _saveToken(String? value) async {
    token = value;
    final p = await SharedPreferences.getInstance();
    if (value == null) {
      await p.remove(_tokenKey);
    } else {
      await p.setString(_tokenKey, value);
    }
  }

  Future<dynamic> _send(String method, String path, {Object? body, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };
    final payload = body == null ? null : jsonEncode(body);
    const limit = Duration(seconds: 20);
    http.Response r;
    try {
      switch (method) {
        case 'GET':
          r = await _client.get(uri, headers: headers).timeout(limit);
        case 'POST':
          r = await _client.post(uri, headers: headers, body: payload).timeout(limit);
        case 'PUT':
          r = await _client.put(uri, headers: headers, body: payload).timeout(limit);
        case 'PATCH':
          r = await _client.patch(uri, headers: headers, body: payload).timeout(limit);
        case 'DELETE':
          r = await _client.delete(uri, headers: headers).timeout(limit);
        default:
          throw ArgumentError('method $method');
      }
    } catch (e) {
      throw ApiException(0, 'NETWORK', detail: '$e');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    var code = 'HTTP_${r.statusCode}';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['code'] is String) code = j['code'] as String;
    } catch (_) {}
    if (r.statusCode == 401 && auth && code == 'UNAUTHENTICATED') {
      await _saveToken(null);
      onSignedOut?.call();
    }
    throw ApiException(r.statusCode, code);
  }

  bool get signedIn => token != null;

  /// "Can I reach the server at all?" Returns null when it can, otherwise the reason in words.
  Future<String?> probe() async {
    try {
      final r = await _client.get(Uri.parse('$baseUrl/actuator/health')).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && r.body.contains('UP')) return null;
      return 'সার্ভার উত্তর দিয়েছে কিন্তু ঠিক নেই (HTTP ${r.statusCode})';
    } catch (e) {
      return 'পৌঁছানো যায়নি: $e';
    }
  }

  // ---- account
  Future<Map<String, dynamic>> login(String institution, String roll, String password) async {
    final res = await _send('POST', '/api/auth/login',
        body: {'institution': institution.trim(), 'roll': roll.trim(), 'password': password}, auth: false) as Map<String, dynamic>;
    await _saveToken(res['token'] as String);
    return res['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async => await _send('GET', '/api/auth/me') as Map<String, dynamic>;

  /// The server retires every older token and sends a fresh one, which we keep so this phone stays signed in.
  Future<void> changePassword(String current, String next) async {
    final res = await _send('POST', '/api/auth/password', body: {'currentPassword': current, 'newPassword': next}) as Map<String, dynamic>;
    await _saveToken(res['token'] as String);
  }

  Future<void> logout() => _saveToken(null);

  // ---- student: exams
  Future<List<Map<String, dynamic>>> exams() async => _list(await _send('GET', '/api/student/exams'));

  Future<Map<String, dynamic>> start(int examId) async => _map(await _send('POST', '/api/student/exams/$examId/start'));

  Future<void> saveDraft(int examId, List<int?> answers) =>
      _send('PUT', '/api/student/exams/$examId/draft', body: {'answers': answers});

  Future<void> submit(int examId, List<int?> answers) =>
      _send('POST', '/api/student/exams/$examId/submit', body: {'answers': answers});

  Future<Map<String, dynamic>> result(int examId) async => _map(await _send('GET', '/api/student/exams/$examId/result'));

  Future<Map<String, dynamic>> leaderboard(int examId) async => _map(await _send('GET', '/api/student/exams/$examId/leaderboard'));

  Future<Map<String, dynamic>> overall() async => _map(await _send('GET', '/api/student/leaderboard/overall'));

  // ---- staff (admin / teacher): exams
  Future<List<Map<String, dynamic>>> adminExams() async => _list(await _send('GET', '/api/admin/exams'));

  Future<Map<String, dynamic>> adminExam(int id) async => _map(await _send('GET', '/api/admin/exams/$id'));

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> body) async => _map(await _send('POST', '/api/admin/exams', body: body));

  Future<void> deleteExam(int id) => _send('DELETE', '/api/admin/exams/$id');

  /// release = students can take it; publish = results and leaderboard become visible to students.
  Future<void> setReleased(int id, bool on) => _send(on ? 'POST' : 'DELETE', '/api/admin/exams/$id/release');

  Future<void> setPublished(int id, bool on) => _send(on ? 'POST' : 'DELETE', '/api/admin/exams/$id/publish');

  Future<Map<String, dynamic>> adminLeaderboard(int id) async => _map(await _send('GET', '/api/admin/exams/$id/leaderboard'));

  // ---- staff: classes and students
  Future<List<Map<String, dynamic>>> classes() async => _list(await _send('GET', '/api/admin/classes'));

  Future<void> createClass(String name) => _send('POST', '/api/admin/classes', body: {'name': name});

  Future<void> createSection(int classId, String name) => _send('POST', '/api/admin/classes/$classId/sections', body: {'name': name});

  Future<List<Map<String, dynamic>>> students() async => _list(await _send('GET', '/api/admin/students'));

  /// Returns {student: {...}, password: "..."}; the password is shown once.
  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> body) async => _map(await _send('POST', '/api/admin/students', body: body));

  Future<String> resetStudentPassword(int id, {String? password}) async {
    final r = _map(await _send('POST', '/api/admin/students/$id/password', body: {if (password != null && password.isNotEmpty) 'password': password}));
    return r['password'] as String;
  }

  // ---- admin only: staff
  Future<List<Map<String, dynamic>>> staff() async => _list(await _send('GET', '/api/admin/staff'));

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> body) async => _map(await _send('POST', '/api/admin/staff', body: body));

  Future<void> changeStaffRole(int id, String role) => _send('PATCH', '/api/admin/staff/$id', body: {'role': role});

  Future<String> resetStaffPassword(int id) async {
    final r = _map(await _send('POST', '/api/admin/staff/$id/password', body: <String, dynamic>{}));
    return r['password'] as String;
  }

  Future<void> deleteStaff(int id) => _send('DELETE', '/api/admin/staff/$id');

  static List<Map<String, dynamic>> _list(dynamic v) => (v as List).cast<Map<String, dynamic>>();
  static Map<String, dynamic> _map(dynamic v) => v as Map<String, dynamic>;
}
