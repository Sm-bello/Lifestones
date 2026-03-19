import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  // ── USER ─────────────────────────────────────
  static Future<void> createOrUpdateUser({
    String? bio,
    String? photoUrl,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': displayName ?? user.displayName ?? 'Member',
      'email': user.email,
      'photoUrl': photoUrl ?? user.photoURL ?? '',
      'bio': bio ?? '',
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'classesAttended': 0,
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  static Future<void> updatePhone(String phone) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'phone': phone});
  }

  static Future<void> deleteMeeting(String docId) async {
    await _db.collection('meetings').doc(docId).delete();
  }

  static Future<void> updateBio(String bio) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({'bio': bio});
  }

  static Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({'displayName': name});
    await user.updateDisplayName(name);
  }

  static Future<String?> uploadProfilePhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final ref = _storage.ref().child('profiles/${user.uid}.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(user.uid).update({'photoUrl': url});
    await user.updatePhotoURL(url);
    return url;
  }

  static Stream<QuerySnapshot> getAllUsers() {
    return _db.collection('users').orderBy('displayName').snapshots();
  }

  // ── MEETINGS ──────────────────────────────────
  static Future<String> createMeeting({
    required String topic,
    required String starterName,
    required String starterUid,
    required String role,
  }) async {
    final roomCode = DateTime.now().millisecondsSinceEpoch
      .toString().substring(7);
    // Use set() with fixed doc ID so all users see the SAME document instantly
    await _db.collection('meetings').doc('current_live').set({
      'topic': topic,
      'roomCode': roomCode,
      'starterName': starterName,
      'starterUid': starterUid,
      'starterRole': role,
      'startedAt': FieldValue.serverTimestamp(),
      'isLive': true,
      'participants': [starterUid],
    });

    // Notify all users via FCM tokens stored in Firestore
    try {
      final usersSnap = await _db.collection('users').get();
      for (final doc in usersSnap.docs) {
        if (doc.id == starterUid) continue;
        final token = doc.data()['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          await _db.collection('notifications').add({
            'token': token,
            'title': '⛪ Class Starting Now!',
            'body': '\$starterName started "\$topic" — Join now!',
            'type': 'meeting_started',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) { debugPrint('FCM notify error: \$e'); }

    return roomCode;
  }

  static Future<void> endMeeting(String roomCode) async {
    await _db.collection('meetings').doc('current_live').update({
      'isLive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }



  static Stream<QuerySnapshot> getLiveMeetings() {
    return _db
        .collection('meetings')
        .where('isLive', isEqualTo: true)
        .snapshots();
  }

  static Future<void> saveRecording({
    required String localPath,
    required String roomCode,
    required String topic,
    required String starterUid,
    required String starterName,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Recording file not found: \$localPath');
        return;
      }
      final fileName = 'recordings/\$roomCode-\${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      await _db.collection('recordings').add({
        'roomCode': roomCode,
        'topic': topic,
        'starterUid': starterUid,
        'starterName': starterName,
        'downloadUrl': downloadUrl,
        'localPath': localPath,
        'endedAt': FieldValue.serverTimestamp(),
        'duration': 0,
      });
      debugPrint('Recording saved: \$downloadUrl');
    } catch (e) {
      debugPrint('Recording save error: \$e');
    }
  }

  static Stream<QuerySnapshot> getRecordings() {
    return _db
      .collection('recordings')
      .orderBy('endedAt', descending: true)
      .limit(20)
      .snapshots();
  }

  static Stream<QuerySnapshot> getUpcomingMeetings() {
    return _db
        .collection('scheduled_meetings')
        .where('scheduledAt',
            isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('scheduledAt')
        .limit(5)
        .snapshots();
  }

  static Future<void> scheduleMeeting({
    required String topic,
    required DateTime scheduledAt,
    required String createdBy,
  }) async {
    await _db.collection('scheduled_meetings').add({
      'topic': topic,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── MESSAGES ──────────────────────────────────
  static Future<void> sendMessage({
    required String text,
    required String senderName,
    required String senderUid,
    required String senderPhoto,
    Map<String, dynamic>? replyTo,
  }) async {
    final isScripture = _detectScripture(text);
    final isHymn = text.startsWith('🎵') || text.toLowerCase().startsWith('hymn');
    await _db.collection('messages').add({
      'text': text,
      'senderName': senderName,
      'senderUid': senderUid,
      'senderPhoto': senderPhoto,
      'sentAt': FieldValue.serverTimestamp(),
      'replyTo': replyTo,
      'type': isScripture ? 'scripture' : isHymn ? 'hymn' : 'text',
    });
  }

  static bool _detectScripture(String text) {
    final pattern = RegExp(
      r'\b(Genesis|Exodus|Psalms?|Proverbs?|Isaiah|Matthew|Mark|Luke|John|'
      r'Romans|Corinthians|Galatians|Ephesians|Philippians|Colossians|'
      r'Thessalonians|Timothy|Hebrews|James|Peter|Revelation|Acts|'
      r'Gen|Exo|Psa|Pro|Isa|Matt|Rom|Cor|Gal|Eph|Phil|Col|Rev)\s+\d+:\d+',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  static Stream<QuerySnapshot> getMessages() {
    return _db
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static Future<void> deleteMessage(String messageId) async {
    await _db.collection('messages').doc(messageId).delete();
  }
}
