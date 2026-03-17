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

const kDeepMilk   = Color(0xFFF5F1E9);
const kWhiteGlass = Color(0xFFFFFFFF);
const kGold       = Color(0xFFC9973A);
const kGoldDark   = Color(0xFFA07828);
const kText       = Color(0xFF2C1A00);

final _auth = FirebaseAuth.instance;
final _db = FirebaseFirestore.instance;
final AudioPlayer _audioPlayer = AudioPlayer();

// MODERN CONSTRUCTOR FIX
final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      theme: ThemeData(scaffoldBackgroundColor: kDeepMilk),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData) return const MainShell();
          return const LoginScreen(); // REMOVED 'const' HERE TO FIX YOUR ERROR
        },
      ),
    );
  }
}

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
    
    // SYNC TO MITOCHONDRIA
    await _db.collection('users').doc(result.user!.uid).set({
      'uid': result.user!.uid,
      'name': result.user!.displayName,
      'photo': result.user!.photoURL,
      'bio': 'Member of the Lifestones family ✝',
    }, SetOptions(merge: true));
    
    return result.user;
  } catch (e) {
    debugPrint("Auth Error: $e");
    return null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _loading ? null : () async {
            setState(() => _loading = true);
            await signInWithGoogle();
            if(mounted) setState(() => _loading = false);
          },
          child: _loading ? const CircularProgressIndicator() : const Text('Continue with Google'),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _screens = [
    const DiscoverTab(),
    const Center(child: Text('Meetings')),
    const MinistersTab(),
    const Center(child: Text('Messages')),
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
        selectedItemColor: kGold,
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

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifestones', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)), backgroundColor: kDeepMilk, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _FloatingCard(
              height: 120,
              child: const Center(child: Text('Scripture Slider Placeholder', style: TextStyle(fontStyle: FontStyle.italic))),
            ),
          ],
        ),
      ),
    );
  }
}

class MinistersTab extends StatelessWidget {
  const MinistersTab({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            var user = snap.data!.docs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _FloatingCard(
                child: ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(user['photo'] ?? '')),
                  title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(user['bio'], maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 50),
              CircleAvatar(radius: 50, backgroundImage: NetworkImage(data['photo'] ?? '')),
              const SizedBox(height: 20),
              Text(data['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _FloatingCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('YOUR BIO', style: TextStyle(fontSize: 10, letterSpacing: 2, color: kGold)),
                      const SizedBox(height: 10),
                      Text(data['bio'], textAlign: TextAlign.center),
                      TextButton(onPressed: () => _updateBio(context, data['bio']), child: const Text('Edit Bio'))
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(onPressed: () => _auth.signOut(), child: const Text('Sign Out')),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  void _updateBio(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet(context: context, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Describe yourself...')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () {
          _db.collection('users').doc(_auth.currentUser!.uid).update({'bio': ctrl.text});
          Navigator.pop(ctx);
        }, child: const Text('Update Mitochondria')),
      ]),
    ));
  }
}

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
      child: const Center(child: Text('Audio Player Placeholder', style: TextStyle(color: kGold))),
    );
  }
}
