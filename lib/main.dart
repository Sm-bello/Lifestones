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

// --- THE FRIEND'S EXACT AUTH ENGINE ---
final _googleSignIn = GoogleSignIn(scopes: ['email']);
final _auth = FirebaseAuth.instance;
final _db = FirebaseFirestore.instance;
final AudioPlayer _audioPlayer = AudioPlayer();

Future<User?> signInWithGoogle() async {
  try {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    
    // SYNC TO MITOCHONDRIA
    await _db.collection('users').doc(result.user!.uid).set({
      'uid': result.user!.uid,
      'name': result.user!.displayName,
      'photo': result.user!.photoURL,
      'bio': 'Member of the Lifestones family ✝',
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    return result.user;
  } catch (e) {
    debugPrint('Sign-in error: $e');
    return null;
  }
}

Future<void> signOut() async {
  await _googleSignIn.signOut();
  await _auth.signOut();
}

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGold)));
          }
          if (snapshot.hasData) return const MainShell();
          return LoginScreen(); // Fixed: No 'const' to allow for dynamic state
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepMilk,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✝', style: TextStyle(fontSize: 60, color: kGold)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loading ? null : () async {
                setState(() => _loading = true);
                await signInWithGoogle();
                if(mounted) setState(() => _loading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: _loading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Continue with Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
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

// --- DISCOVER TAB ---
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifestones', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)), backgroundColor: kDeepMilk, elevation: 0),
      body: const Center(child: Text('Smart Dashboard Coming Soon', style: TextStyle(color: kGoldDark))),
    );
  }
}

// --- MINISTERS TAB (DIRECTORY) ---
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
            return Card(
              color: kWhiteGlass,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(user['photo'] ?? '')),
                title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user['bio'], maxLines: 1),
              ),
            );
          },
        );
      },
    );
  }
}

// --- PROFILE TAB (MITOCHONDRIA) ---
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: kWhiteGlass, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    const Text('BIO', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(data['bio'], textAlign: TextAlign.center),
                    TextButton(onPressed: () => _editBio(context, data['bio']), child: const Text('Edit Profile'))
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(onPressed: signOut, child: const Text('Sign Out')),
              const SizedBox(height: 100),
            ],
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
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Update Bio')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () {
          _db.collection('users').doc(_auth.currentUser!.uid).update({'bio': ctrl.text});
          Navigator.pop(ctx);
        }, child: const Text('Save Changes'))
      ]),
    ));
  }
}

class _MiniPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: const Center(child: Text('Lifestones Audio', style: TextStyle(color: kGold))),
    );
  }
}
