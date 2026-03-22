import 'dart:convert';
import 'package:http/http.dart' as http;

class PocketBaseService {
  // Will be your server URL when VPS arrives
  // For now points to local for testing
  static const String baseUrl = 'http://127.0.0.1:8090';
  static String? _token;
  static String? _userId;

  // ── AUTH ─────────────────────────────────────────────
  static Future<Map<String,dynamic>?> signIn(
      String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/collections/users/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': email, 'password': password}));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      _token = data['token'];
      _userId = data['record']['id'];
      return data['record'];
    }
    return null;
  }

  static Map<String,String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── MESSAGES ─────────────────────────────────────────
  static Future<List<dynamic>> getMessages() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/collections/messages/records?sort=-created&perPage=50'),
      headers: _headers);
    if (r.statusCode == 200) {
      return jsonDecode(r.body)['items'] ?? [];
    }
    return [];
  }

  static Future<bool> sendMessage({
    required String text,
    required String senderName,
    required String senderUid,
    String? senderPhoto,
    Map<String,dynamic>? replyTo,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/collections/messages/records'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'senderName': senderName,
        'senderUid': senderUid,
        'senderPhoto': senderPhoto ?? '',
        'type': 'text',
        'replyTo': replyTo ?? {},
        'reactions': {},
      }));
    return r.statusCode == 200;
  }

  // ── MEETINGS ─────────────────────────────────────────
  static Future<Map<String,dynamic>?> getLiveMeeting() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/collections/meetings/records?filter=(isLive=true)&perPage=1'),
      headers: _headers);
    if (r.statusCode == 200) {
      final items = jsonDecode(r.body)['items'] as List;
      return items.isNotEmpty ? items.first : null;
    }
    return null;
  }

  static Future<String?> createMeeting({
    required String topic,
    required String starterName,
    required String starterUid,
  }) async {
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
        'startedAt': DateTime.now().toIso8601String(),
      }));
    if (r.statusCode == 200) return roomCode;
    return null;
  }

  static Future<void> endMeeting(String roomCode) async {
    // Find and update the live meeting
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
  }

  // ── RECORDINGS ───────────────────────────────────────
  static Future<List<dynamic>> getRecordings() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/collections/recordings/records?sort=-created&perPage=20'),
      headers: _headers);
    if (r.statusCode == 200) {
      return jsonDecode(r.body)['items'] ?? [];
    }
    return [];
  }

  // ── USERS ────────────────────────────────────────────
  static Future<List<dynamic>> getUsers() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/collections/users/records?perPage=100'),
      headers: _headers);
    if (r.statusCode == 200) {
      return jsonDecode(r.body)['items'] ?? [];
    }
    return [];
  }

  static Future<void> banUser(String userId) async {
    await http.patch(
      Uri.parse('$baseUrl/api/collections/users/records/$userId'),
      headers: _headers,
      body: jsonEncode({'banned': true, 'chatApproved': false}));
  }

  // ── PRAYER REQUESTS ──────────────────────────────────
  static Future<List<dynamic>> getPrayerRequests() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/collections/prayer_requests/records?sort=-created'),
      headers: _headers);
    if (r.statusCode == 200) {
      return jsonDecode(r.body)['items'] ?? [];
    }
    return [];
  }
}
