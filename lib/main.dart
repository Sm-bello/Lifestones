import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // GOOGLE LOGIN LOGIC
  Future<void> _login(BuildContext context) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    await FirebaseAuth.instance.signInWithCredential(cred);
  }

  // INTERNAL JITSI LOGIC (Prevents Play Store redirection)
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
