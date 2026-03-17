import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  
  // REQUIRED IN v7.0.0+: You must initialize the singleton instance
  await GoogleSignIn.instance.initialize();
  
  runApp(const LifestonesApp());
}

class LifestonesApp extends StatelessWidget {
  const LifestonesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _login(BuildContext context) async {
    try {
      // 1. The Singleton update
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      
      // 2. signIn() is gone. We must use authenticate()
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      
      if (googleUser == null) return;
      
      // 3. Get the authentication object
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 4. Firebase only needs the idToken now (accessToken was removed)
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
      
    } catch (e) {
      debugPrint("Login error: $e");
    }
  }

  void _joinMeeting() {
    var options = JitsiMeetConferenceOptions(
      room: "LifestonesMainSanctuary",
      configOverrides: {
        "startWithAudioMuted": true,
        "startWithVideoMuted": true,
      },
      featureFlags: { "unwelcome.page.enabled": false },
    );
    var jitsiMeet = JitsiMeet();
    jitsiMeet.join(options);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lifestones Church")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: () => _login(context), child: const Text("Login with Google")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _joinMeeting, child: const Text("Join Service")),
          ],
        ),
      ),
    );
  }
}
