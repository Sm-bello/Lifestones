import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

// THE JUICY COLOR PALETTE
const kDeepMilk   = Color(0xFFF5F1E9);
const kWhiteGlass = Color(0xFFFFFFFF);
const kGold       = Color(0xFFC9973A);
const kGoldDark   = Color(0xFFA07828);
const kText       = Color(0xFF2C1A00);
const kTextFaded  = Color(0xFF8B6914);

final _googleSignIn = GoogleSignIn(scopes: ['email']);
final _auth = FirebaseAuth.instance;
final _db = FirebaseFirestore.instance;
final AudioPlayer _audioPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LifestonesApp());
}

class LifestonesApp extends StatelessWidget {
  const LifestonesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kDeepMilk,
        fontFamily: 'Inter',
      ),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const MainShell();
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- AUTH ENGINE ---
Future<User?> signInWithGoogle() async {
  try {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(cred);
    
    // Sync to Mitochondria (Profile)
    await _db.collection('users').doc(result.user!.uid).set({
      'uid': result.user!.uid,
      'name': result.user!.displayName,
      'photo': result.user!.photoURL,
      'bio': 'Member of the Lifestones family ✝',
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    return result.user;
  } catch (e) {
    return null;
  }
}

// --- MAIN UI SHELL ---
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _screens = [
    const DiscoverTab(),
    const MeetingsTab(),
    const MinistersTab(),
    const MessagesTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_index],
          Positioned(bottom: 0, left: 0, right: 0, child: _MiniPlayer()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: kGold,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Meetings'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Ministers'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- TAB 1: DISCOVER (SMART DASHBOARD) ---
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final List<String> _verses = [
    "But as for me and my house, we will serve the Lord. — Josh 24:15",
    "Where iron sharpens iron, so one person sharpens another. — Prov 27:17",
    "Faith comes by hearing, and hearing by the word of God. — Rom 10:17"
  ];
  int _verseIndex = 0;
  Timer? _timer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (!_paused) setState(() => _verseIndex = (_verseIndex + 1) % _verses.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard', style: TextStyle(color: kText, fontWeight: FontWeight.bold)), backgroundColor: kDeepMilk, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Smart Scripture Slider
            GestureDetector(
              onLongPressStart: (_) => setState(() => _paused = true),
              onLongPressEnd: (_) => setState(() => _paused = false),
              child: _FloatingCard(
                height: 100,
                child: Center(
                  child: Text(_verses[_verseIndex], textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: kGoldDark)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Meeting Banner
            _FloatingCard(
              child: ListTile(
                title: const Text('Next Fellowship', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Friday • 6:00 PM • The Sanctuary'),
                trailing: IconButton(
                  icon: const Icon(Icons.share, color: kGold),
                  onPressed: () => Share.share("Join us this Friday at 6 PM on the Lifestones App!"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB 5: PROFILE (MITOCHONDRIA) ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var data = snap.data!;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                CircleAvatar(radius: 50, backgroundImage: NetworkImage(data['photo'] ?? '')),
                const SizedBox(height: 20),
                Text(data['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _FloatingCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('BIO', style: TextStyle(fontSize: 10, letterSpacing: 2, color: kGold)),
                          const SizedBox(height: 8),
                          Text(data['bio'], textAlign: TextAlign.center),
                          TextButton(onPressed: () => _editBio(context, data['bio']), child: const Text('Edit Bio'))
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(onPressed: () => _auth.signOut(), child: const Text('Sign Out')),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editBio(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet(context: context, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New Bio')),
        ElevatedButton(onPressed: () {
          _db.collection('users').doc(_auth.currentUser!.uid).update({'bio': ctrl.text});
          Navigator.pop(ctx);
        }, child: const Text('Save'))
      ]),
    ));
  }
}

// --- MINI COMPONENTS ---
class _FloatingCard extends StatelessWidget {
  final Widget child;
  final double? height;
  const _FloatingCard({required this.child, this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhiteGlass,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          const SizedBox(width: 15),
          const Icon(Icons.music_note, color: kGold),
          const SizedBox(width: 15),
          const Expanded(child: Text('Lifestones Radio', style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {}),
          const SizedBox(width: 15),
        ],
      ),
    );
  }
}

// Placeholder Tabs for the next push
class MeetingsTab extends StatelessWidget { const MeetingsTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Meetings Tab')); }
class MinistersTab extends StatelessWidget { const MinistersTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Ministers Tab')); }
class MessagesTab extends StatelessWidget { const MessagesTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Messages Tab')); }
