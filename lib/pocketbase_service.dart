import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PocketBaseService {
  // Change this ONE line when server arrives
  static const String baseUrl = 'http://127.0.0.1:8090';
  
  static String? _token;
  static String? _userId;
  static String? _userEmail;
  static Map<String,dynamic>? _currentUser;

  static Map<String,String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static String? get userId => _userId;
  static Map<String,dynamic>? get currentUser => _currentUser;

  // ── AUTH ─────────────────────────────────────────────
  static Future<Map<String,dynamic>?> signInWithEmail(
      String email, String password) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/users/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': email, 'password': password}));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _token = data['token'];
        _userId = data['record']['id'];
        _userEmail = data['record']['email'];
        _currentUser = data['record'];
        return data['record'];
      }
    } catch (e) { debugPrint('SignIn error: $e'); }
    return null;
  }

  static Future<Map<String,dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'displayName': displayName,
          'role': 'member',
          'chatApproved': false,
          'banned': false,
          'classesAttended': 0,
        }));
      if (r.statusCode == 200) {
        return await signInWithEmail(email, password);
      }
    } catch (e) { debugPrint('Register error: $e'); }
    return null;
  }

  static Future<void> signOut() async {
    // Wipe role on signout
    if (_userId != null) {
      await updateUser(_userId!, {
        'role': '',
        'roleSetAt': '',
        'chatApproved': false,
      });
    }
    _token = null;
    _userId = null;
    _currentUser = null;
  }

  static Future<bool> isBanned() async {
    if (_userId == null) return false;
    final user = await getUser(_userId!);
    return user?['banned'] == true;
  }

  // ── USERS ─────────────────────────────────────────────
  static Future<Map<String,dynamic>?> getUser(String id) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$id'),
        headers: _headers);
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) { debugPrint('GetUser error: $e'); }
    return null;
  }

  static Future<List<dynamic>> getAllUsers() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records?perPage=200&sort=displayName'),
        headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['items'] ?? [];
      }
    } catch (e) { debugPrint('GetUsers error: $e'); }
    return [];
  }

  static Future<bool> updateUser(String id, Map<String,dynamic> data) async {
    try {
      final r = await http.patch(
        Uri.parse('$baseUrl/api/collections/users/records/$id'),
        headers: _headers,
        body: jsonEncode(data));
      if (r.statusCode == 200) {
        _currentUser = jsonDecode(r.body);
        return true;
      }
    } catch (e) { debugPrint('UpdateUser error: $e'); }
    return false;
  }

  static Future<void> setRole(String role) async {
    if (_userId == null) return;
    await updateUser(_userId!, {
      'role': role,
      'roleSetAt': DateTime.now().toIso8601String(),
      'chatApproved': role == 'pastor',
    });
    _currentUser?['role'] = role;
  }

  static Future<void> banUser(String userId) async {
    await updateUser(userId, {
      'banned': true,
      'chatApproved': false,
      'role': '',
      'roleSetAt': '',
    });
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
        headers: _headers);
    } catch (e) { debugPrint('DeleteUser error: $e'); }
  }

  static Future<String?> getPastorPin() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/settings/records?filter=(key="pastor_pin")'),
        headers: _headers);
      if (r.statusCode == 200) {
        final items = jsonDecode(r.body)['items'] as List;
        if (items.isNotEmpty) return items.first['value'];
      }
    } catch (e) { debugPrint('GetPin error: $e'); }
    return '7749';
  }

  // ── MESSAGES ─────────────────────────────────────────
  static Future<List<dynamic>> getMessages({int limit = 50}) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/messages/records?sort=-sentAt&perPage=$limit'),
        headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['items'] ?? [];
      }
    } catch (e) { debugPrint('GetMessages error: $e'); }
    return [];
  }

  static Future<bool> sendMessage({
    required String text,
    required String senderName,
    required String senderUid,
    String senderPhoto = '',
    String type = 'text',
    Map<String,dynamic>? replyTo,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/messages/records'),
        headers: _headers,
        body: jsonEncode({
          'text': text,
          'senderName': senderName,
          'senderUid': senderUid,
          'senderPhoto': senderPhoto,
          'sentAt': DateTime.now().toIso8601String(),
          'type': type,
          'replyTo': jsonEncode(replyTo ?? {}),
          'reactions': '{}',
        }));
      return r.statusCode in [200, 201];
    } catch (e) { debugPrint('SendMessage error: $e'); }
    return false;
  }

  static Future<void> deleteMessage(String id) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/collections/messages/records/$id'),
        headers: _headers);
    } catch (e) { debugPrint('DeleteMessage error: $e'); }
  }

  // ── REAL-TIME POLLING (replaces Firestore streams) ───
  static Stream<List<dynamic>> messagesStream() async* {
    while (true) {
      final msgs = await getMessages();
      yield msgs;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  static Stream<List<dynamic>> usersStream() async* {
    while (true) {
      final users = await getAllUsers();
      yield users;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Stream<Map<String,dynamic>?> liveMeetingStream() async* {
    while (true) {
      final meeting = await getLiveMeeting();
      yield meeting;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // ── MEETINGS ─────────────────────────────────────────
  static Future<Map<String,dynamic>?> getLiveMeeting() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/meetings/records?filter=(isLive=true)&perPage=1'),
        headers: _headers);
      if (r.statusCode == 200) {
        final items = jsonDecode(r.body)['items'] as List;
        return items.isNotEmpty ? items.first : null;
      }
    } catch (e) { debugPrint('GetLive error: $e'); }
    return null;
  }

  static Future<String?> createMeeting({
    required String topic,
    required String starterName,
    required String starterUid,
    required String starterRole,
  }) async {
    try {
      final roomCode = DateTime.now().millisecondsSinceEpoch
        .toString().substring(7);
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/meetings/records'),
        headers: _headers,
        body: jsonEncode({
          'topic': topic,
          'roomCode': roomCode,
          'isLive': true,
          'starterName': starterName,
          'starterUid': starterUid,
          'starterRole': starterRole,
          'startedAt': DateTime.now().toIso8601String(),
          'participants': '[]',
        }));
      if (r.statusCode in [200, 201]) return roomCode;
    } catch (e) { debugPrint('CreateMeeting error: $e'); }
    return null;
  }

  static Future<void> endMeeting(String roomCode) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/meetings/records?filter=(roomCode="$roomCode")'),
        headers: _headers);
      if (r.statusCode == 200) {
        final items = jsonDecode(r.body)['items'] as List;
        if (items.isNotEmpty) {
          final id = items.first['id'];
          await http.patch(
            Uri.parse('$baseUrl/api/collections/meetings/records/$id'),
            headers: _headers,
            body: jsonEncode({
              'isLive': false,
              'endedAt': DateTime.now().toIso8601String(),
            }));
        }
      }
    } catch (e) { debugPrint('EndMeeting error: $e'); }
  }

  // ── RECORDINGS ───────────────────────────────────────
  static Future<List<dynamic>> getRecordings() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/recordings/records?sort=-created&perPage=20'),
        headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['items'] ?? [];
      }
    } catch (e) { debugPrint('GetRecordings error: $e'); }
    return [];
  }

  static Future<bool> saveRecording({
    required String roomCode,
    required String topic,
    required String uploadedBy,
    required String downloadUrl,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/recordings/records'),
        headers: _headers,
        body: jsonEncode({
          'roomCode': roomCode,
          'topic': topic,
          'uploadedBy': uploadedBy,
          'downloadUrl': downloadUrl,
          'endedAt': DateTime.now().toIso8601String(),
          'summary': '',
        }));
      return r.statusCode in [200, 201];
    } catch (e) { debugPrint('SaveRecording error: $e'); }
    return false;
  }

  // ── PRAYER REQUESTS ──────────────────────────────────
  static Future<List<dynamic>> getPrayerRequests() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/prayer_requests/records?sort=-createdAt'),
        headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['items'] ?? [];
      }
    } catch (e) { debugPrint('GetPrayer error: $e'); }
    return [];
  }

  static Future<bool> addPrayerRequest({
    required String text,
    required String name,
    required String uid,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/prayer_requests/records'),
        headers: _headers,
        body: jsonEncode({
          'text': text,
          'name': name,
          'uid': uid,
          'answered': false,
          'createdAt': DateTime.now().toIso8601String(),
        }));
      return r.statusCode in [200, 201];
    } catch (e) { debugPrint('AddPrayer error: $e'); }
    return false;
  }

  // ── ATTENDANCE ───────────────────────────────────────
  static Future<void> recordAttendance({
    required String uid,
    required String name,
    required String roomCode,
    required String topic,
    required String role,
  }) async {
    try {
      // Deduplicate
      final docId = '${roomCode}_$uid';
      final check = await http.get(
        Uri.parse('$baseUrl/api/collections/attendance/records?filter=(uid="$uid"&&roomCode="$roomCode")'),
        headers: _headers);
      if (check.statusCode == 200) {
        final items = jsonDecode(check.body)['items'] as List;
        if (items.isNotEmpty) return; // Already recorded
      }
      await http.post(
        Uri.parse('$baseUrl/api/collections/attendance/records'),
        headers: _headers,
        body: jsonEncode({
          'uid': uid,
          'name': name,
          'roomCode': roomCode,
          'topic': topic,
          'role': role,
          'joinedAt': DateTime.now().toIso8601String(),
        }));
    } catch (e) { debugPrint('Attendance error: $e'); }
  }

  // ── SCHEDULED MEETINGS ────────────────────────────────
  static Future<List<dynamic>> getUpcomingMeetings() async {
    try {
      final now = DateTime.now().toIso8601String();
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/scheduled_meetings/records?filter=(scheduledAt>"$now")&sort=scheduledAt&perPage=5'),
        headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['items'] ?? [];
      }
    } catch (e) { debugPrint('GetScheduled error: $e'); }
    return [];
  }

  static Future<bool> scheduleMeeting({
    required String topic,
    required DateTime scheduledAt,
    required String createdBy,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/scheduled_meetings/records'),
        headers: _headers,
        body: jsonEncode({
          'topic': topic,
          'scheduledAt': scheduledAt.toIso8601String(),
          'createdBy': createdBy,
          'createdAt': DateTime.now().toIso8601String(),
        }));
      return r.statusCode in [200, 201];
    } catch (e) { debugPrint('ScheduleMeeting error: $e'); }
    return false;
  }

  // ── CHAT REQUESTS ─────────────────────────────────────
  static Future<bool> requestChatAccess({
    required String uid,
    required String name,
    String photo = '',
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/collections/chat_requests/records'),
        headers: _headers,
        body: jsonEncode({
          'uid': uid,
          'name': name,
          'photo': photo,
          'status': 'pending',
          'requestedAt': DateTime.now().toIso8601String(),
        }));
      return r.statusCode in [200, 201];
    } catch (e) { debugPrint('ChatRequest error: $e'); }
    return false;
  }

  static Future<void> approveChatRequest(String requestId, String userId) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/api/collections/chat_requests/records/$requestId'),
        headers: _headers,
        body: jsonEncode({'status': 'approved'}));
      await updateUser(userId, {'chatApproved': true});
    } catch (e) { debugPrint('ApproveChat error: $e'); }
  }
}
