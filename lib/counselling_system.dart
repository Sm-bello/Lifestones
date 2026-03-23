import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'sanctuary_livekit.dart';

const Color kCounselBg       = Color(0xFFEEF7FC);
const Color kCounselBlueMid  = Color(0xFFD0EAF7);
const Color kCounselBubbleMe = Color(0xFFB3D9F0);
const Color kCounselBubbleOther = Color(0xFFFFFFFF);
const Color kCounselAccent   = Color(0xFF4A90C4);
const Color kCounselDark     = Color(0xFF1C2B3A);

class DiscoverHeaderSection extends StatelessWidget {
  final String userRole;
  final String userId;
  final String userName;
  final VoidCallback onBibleTap;
  final VoidCallback onHymnsTap;
  final VoidCallback onPrayerTap;

  const DiscoverHeaderSection({
    Key? key,
    required this.userRole,
    required this.userId,
    required this.userName,
    required this.onBibleTap,
    required this.onHymnsTap,
    required this.onPrayerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCounsellingCard(context),
        const SizedBox(height: 14),
        _buildQuickGrid(context),
      ],
    );
  }

  Widget _buildCounsellingCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (userRole == 'pastor') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PastorCounsellingHub(pastorId: userId)));
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => CounsellingConfidentialityDialog(userId: userId, userName: userName),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90C4), Color(0xFF2F6EA5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4A90C4).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.healing_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Counselling', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                  const SizedBox(height: 5),
                  Text(
                    userRole == 'pastor' ? 'View your private counselling sessions' : 'Talk to the Pastor privately about what\'s concerning you',
                    style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.9), size: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context) {
    final items = [
      _QuickItem(emoji: '📖', label: 'Bible',         color: const Color(0xFF7B5A1E), bgColor: const Color(0xFFFFF3DC)),
      _QuickItem(emoji: '🎵', label: 'Hymns',         color: const Color(0xFF2D6A9F), bgColor: const Color(0xFFE3F1FB)),
      _QuickItem(emoji: '🙏', label: 'Prayer',        color: const Color(0xFF6B4FB0), bgColor: const Color(0xFFF2EDFD)),
      _QuickItem(emoji: '📢', label: 'Announcements', color: const Color(0xFFB85C0A), bgColor: const Color(0xFFFFF0E3)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: items.map((item) => _buildGridTile(context, item)).toList(),
    );
  }

  Widget _buildGridTile(BuildContext context, _QuickItem item) {
    return GestureDetector(
      onTap: () {
        switch (item.label) {
          case 'Bible': onBibleTap(); break;
          case 'Hymns': onHymnsTap(); break;
          case 'Prayer': onPrayerTap(); break;
          case 'Announcements': Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementsPage(userRole: userRole, userId: userId))); break;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
          border: Border.all(color: item.color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: item.bgColor, borderRadius: BorderRadius.circular(12)),
              child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 8),
            Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: item.color, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}

class _QuickItem {
  final String emoji, label;
  final Color color, bgColor;
  const _QuickItem({required this.emoji, required this.label, required this.color, required this.bgColor});
}

class CounsellingConfidentialityDialog extends StatelessWidget {
  final String userId, userName;
  const CounsellingConfidentialityDialog({Key? key, required this.userId, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4A90C4), Color(0xFF2F6EA5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('Strictly Confidential', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Text('Everything shared in this space is completely private between you and the Pastor. No one else can see your conversations.\n\nYou are in a safe and confidential space. 🙏', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF68D391).withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF48BB78), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Screenshots & screen recording are disabled inside this space.', style: TextStyle(fontSize: 12, color: Color(0xFF276749), height: 1.4))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CounsellingChatScreen(userId: userId, userName: userName)));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kCounselAccent, padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('I Understand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CounsellingChatScreen extends StatefulWidget {
  final String userId, userName;
  const CounsellingChatScreen({Key? key, required this.userId, required this.userName}) : super(key: key);
  @override
  State<CounsellingChatScreen> createState() => _CounsellingChatScreenState();
}

class _CounsellingChatScreenState extends State<CounsellingChatScreen> {
  static const _platform = MethodChannel('com.lifestones.church/security');
  final _controller     = TextEditingController();
  final _scrollCtrl     = ScrollController();
  final _firestore      = FirebaseFirestore.instance;
  final _storage        = FirebaseStorage.instance;
  final _picker         = ImagePicker();
  final _audioRecorder  = AudioRecorder();
  Map<String, dynamic>? _replyTo;
  bool _isRecording = false;

  @override
  void initState() { super.initState(); _setSecure(true); _ensureChatDocument(); }
  @override
  void dispose() { _setSecure(false); _controller.dispose(); _scrollCtrl.dispose(); _audioRecorder.dispose(); super.dispose(); }

  Future<void> _setSecure(bool secure) async { try { await _platform.invokeMethod('setSecure', {'secure': secure}); } catch (_) {} }
  Future<void> _ensureChatDocument() async {
    final ref = _firestore.collection('counselling_chats').doc(widget.userId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'memberName': widget.userName, 'memberId': widget.userId, 'lastMessage': '', 'lastTimestamp': FieldValue.serverTimestamp(), 'unreadByPastor': 0});
    }
  }

  CollectionReference get _messagesRef => _firestore.collection('counselling_chats').doc(widget.userId).collection('messages');

  Future<void> _sendMessage({String? text, String? imageUrl, String? voiceUrl, String? type}) async {
    final msg = {'senderId': widget.userId, 'senderRole': 'member', 'senderName': widget.userName, 'text': text ?? '', 'imageUrl': imageUrl, 'voiceNoteUrl': voiceUrl, 'type': type ?? 'text', 'replyTo': _replyTo, 'timestamp': FieldValue.serverTimestamp(), 'readByPastor': false};
    setState(() => _replyTo = null);
    _controller.clear();
    await _messagesRef.add(msg);
    await _firestore.collection('counselling_chats').doc(widget.userId).update({'lastMessage': text ?? (type == 'image' ? '📸 Image' : '🎤 Voice note'), 'lastTimestamp': FieldValue.serverTimestamp(), 'unreadByPastor': FieldValue.increment(1)});
    _scrollToBottom();
  }

  void _scrollToBottom() { Future.delayed(const Duration(milliseconds: 200), () { if (_scrollCtrl.hasClients) { _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); } }); }

  Future<void> _pickImage() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xFile == null) return;
    final ref = _storage.ref('counselling/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(xFile.path));
    final url = await ref.getDownloadURL();
    await _sendMessage(imageUrl: url, type: 'image');
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final path = '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    final ref = _storage.ref('counselling/${widget.userId}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await ref.putFile(File(path));
    final url = await ref.getDownloadURL();
    await _sendMessage(voiceUrl: url, type: 'voice');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCounselBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: kCounselDark), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: kCounselAccent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: kCounselAccent, size: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pastor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kCounselDark)), Text('Private & Confidential', style: TextStyle(fontSize: 10, color: Colors.grey))])
        ]),
      ),
      body: Column(
        children: [
          Container(color: const Color(0xFFE8F5E9), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Row(children: const [Icon(Icons.lock_rounded, size: 13, color: Color(0xFF4CAF50)), SizedBox(width: 7), Text('This conversation is private — only you and the Pastor can see it', style: TextStyle(fontSize: 11, color: Color(0xFF388E3C)))] )),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef.orderBy('timestamp').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kCounselAccent));
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.chat_bubble_outline_rounded, size: 52, color: Color(0xFFB0C4D8)), SizedBox(height: 14), Text('Start your conversation with the Pastor.\nYou are safe here. 🙏', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6))]));
                return ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16), itemCount: docs.length, itemBuilder: (_, i) => _buildBubble(docs[i]));
              },
            ),
          ),
          if (_replyTo != null) _buildReplyPreviewBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == widget.userId;
    final type = data['type'] ?? 'text';
    return GestureDetector(
      onLongPress: () => setState(() => _replyTo = {'messageId': doc.id, 'senderName': isMe ? 'You' : 'Pastor', 'text': data['text']?.isNotEmpty == true ? data['text'] : (type == 'image' ? '📸 Image' : '🎤 Voice note')}),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[CircleAvatar(radius: 14, backgroundColor: kCounselAccent.withOpacity(0.15), child: const Icon(Icons.person_rounded, size: 16, color: kCounselAccent)), const SizedBox(width: 8)],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: Container(
                decoration: BoxDecoration(color: isMe ? kCounselBubbleMe : kCounselBubbleOther, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) Padding(padding: const EdgeInsets.only(left: 14, top: 10, right: 14), child: const Text('Pastor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kCounselAccent))),
                    Padding(padding: EdgeInsets.fromLTRB(14, isMe ? 12 : 4, 14, 4), child: _buildMessageContent(data, type)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> data, String type) {
    switch (type) {
      case 'image': return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(data['imageUrl'] ?? '', width: 200, fit: BoxFit.cover));
      case 'voice': return _VoiceNotePlayer(url: data['voiceNoteUrl'] ?? '');
      default: return Text(data['text'] ?? '', style: const TextStyle(fontSize: 15, color: kCounselDark, height: 1.4));
    }
  }

  Widget _buildReplyPreviewBar() {
    return Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(14, 8, 6, 8), child: Row(children: [Container(width: 3, height: 38, decoration: BoxDecoration(color: kCounselAccent, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_replyTo!['senderName'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kCounselAccent)), Text(_replyTo!['text'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)])), IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey), onPressed: () => setState(() => _replyTo = null))]));
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(icon: const Icon(Icons.image_rounded, color: kCounselAccent, size: 26), onPressed: _pickImage),
          Expanded(child: Container(decoration: BoxDecoration(color: kCounselBg, borderRadius: BorderRadius.circular(26), border: Border.all(color: kCounselBlueMid)), child: TextField(controller: _controller, maxLines: null, decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11))))),
          const SizedBox(width: 8),
          GestureDetector(onLongPressStart: (_) => _startRecording(), onLongPressEnd: (_) => _stopRecording(), child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: _isRecording ? Colors.red : kCounselBlueMid, shape: BoxShape.circle), child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.white : kCounselAccent, size: 22))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () { final text = _controller.text.trim(); if (text.isNotEmpty) _sendMessage(text: text); }, child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: kCounselAccent, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 22))),
        ],
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  final String url;
  const _VoiceNotePlayer({required this.url});
  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}
class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  @override
  void initState() { super.initState(); _player.onPlayerComplete.listen((_) => setState(() => _playing = false)); }
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  Future<void> _toggle() async { if (_playing) { await _player.pause(); setState(() => _playing = false); } else { await _player.play(UrlSource(widget.url)); setState(() => _playing = true); } }
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [GestureDetector(onTap: _toggle, child: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, color: kCounselAccent, size: 38)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Voice note', style: TextStyle(fontSize: 13, color: kCounselDark, fontWeight: FontWeight.w500)), Text(_playing ? 'Playing...' : 'Hold mic to record', style: const TextStyle(fontSize: 10, color: Colors.grey))])]);
  }
}

class PastorCounsellingHub extends StatefulWidget {
  final String pastorId;
  const PastorCounsellingHub({Key? key, required this.pastorId}) : super(key: key);
  @override
  State<PastorCounsellingHub> createState() => _PastorCounsellingHubState();
}
class _PastorCounsellingHubState extends State<PastorCounsellingHub> {
  final _pinCtrl    = TextEditingController();
  final _firestore  = FirebaseFirestore.instance;
  bool _authenticated = false, _loading = false, _obscurePin = true;
  String? _error;

  Future<void> _verifyPin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await _firestore.collection('app_config').doc('security').get();
      final correctPin = doc.data()?['counselling_pin']?.toString() ?? '9988';
      if (_pinCtrl.text.trim() == correctPin) setState(() { _authenticated = true; _loading = false; });
      else setState(() { _error = 'Incorrect PIN. Please try again.'; _loading = false; });
    } catch (_) { setState(() { _error = 'Could not verify PIN. Check connection.'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kCounselBg, appBar: AppBar(backgroundColor: Colors.white, elevation: 0.8, title: const Text('Counselling Sessions', style: TextStyle(color: kCounselDark, fontWeight: FontWeight.bold, fontSize: 17)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: kCounselDark), onPressed: () => Navigator.pop(context))), body: _authenticated ? _buildSessionsList() : _buildPinEntry());
  }

  Widget _buildPinEntry() { return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _pinCtrl, keyboardType: TextInputType.number, obscureText: _obscurePin, decoration: InputDecoration(hintText: 'Counselling PIN', errorText: _error)), ElevatedButton(onPressed: _loading ? null : _verifyPin, child: const Text('Enter'))]))); }
  Widget _buildSessionsList() { return const Center(child: Text('Sessions will appear here.')); }
}

class AnnouncementsPage extends StatefulWidget {
  final String userRole, userId;
  const AnnouncementsPage({Key? key, required this.userRole, required this.userId}) : super(key: key);
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}
class _AnnouncementsPageState extends State<AnnouncementsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('📢 Announcements')), body: const Center(child: Text('Announcements feed here')));
  }
}
