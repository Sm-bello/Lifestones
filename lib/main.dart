import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ── COLORS ───────────────────────────────────
const kMilk     = Color(0xFFFDF6E3);
const kMilkDark = Color(0xFFF5ECD7);
const kGold     = Color(0xFFC9973A);
const kGoldLight= Color(0xFFE2B96F);
const kGoldDark = Color(0xFFA07828);
const kText     = Color(0xFF2C1A00);
const kTextLight= Color(0xFF8B6914);
const kWhite    = Color(0xFFFFFFFF);
const kRed      = Color(0xFFD32F2F);

// ── GOOGLE SIGN-IN (v6 API) ───────────────────
final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
final FirebaseAuth _auth = FirebaseAuth.instance;

Future<User?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
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

// ── MAIN ─────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: kMilk,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LifestonesApp());
}

class LifestonesApp extends StatelessWidget {
  const LifestonesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lifestones',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kMilk,
        colorScheme: const ColorScheme.light(primary: kGold),
      ),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: kMilk,
              body: Center(
                child: CircularProgressIndicator(color: kGold),
              ),
            );
          }
          if (snapshot.hasData) return const HomeScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  LOGIN SCREEN
// ══════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String _error = '';

  Future<void> _handleSignIn() async {
    setState(() { _loading = true; _error = ''; });
    final user = await signInWithGoogle();
    if (user == null) {
      setState(() {
        _error = 'Sign-in cancelled or failed. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilk,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kMilk, kMilkDark],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [kGoldLight, kGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kGold.withOpacity(0.4),
                        blurRadius: 24, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('✝',
                      style: TextStyle(fontSize: 44, color: kWhite)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Lifestones',
                  style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w800,
                    color: kGold, letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('DISCIPLESHIP · COMMUNITY · FAITH',
                  style: TextStyle(
                    fontSize: 10, letterSpacing: 3.5,
                    color: kTextLight.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kGold.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: kGold.withOpacity(0.1),
                        blurRadius: 24, spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('Welcome to the Family',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Sign in to join discipleship classes',
                        style: TextStyle(
                          fontSize: 14,
                          color: kTextLight.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (_error.isNotEmpty) ...[
                        Text(_error,
                          style: const TextStyle(
                            color: kRed, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _handleSignIn,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    color: kWhite, strokeWidth: 2),
                                )
                              : const Text('G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: kWhite,
                                  )),
                          label: Text(
                            _loading ? 'Signing in...' : 'Continue with Google',
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGold,
                            foregroundColor: kWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: kGold.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  HOME SCREEN (after login)
// ══════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomCtrl = TextEditingController();
  bool _isHost = false;
  bool _loading = false;
  String _error = '';
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _joinMeeting() async {
    final room = _roomCtrl.text.trim().toUpperCase();
    if (room.isEmpty) {
      setState(() => _error = 'Please enter a room code');
      return;
    }
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      setState(() => _error = 'No internet connection');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final jitsi = JitsiMeet();
      var options = JitsiMeetConferenceOptions(
        room: "Lifestones-$room",
        userInfo: JitsiMeetUserInfo(
          displayName: _user?.displayName ?? 'Member',
          email: _user?.email,
        ),
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "disableDeepLinking": true,
          "prejoinPageEnabled": false,
          "p2p.enabled": true,
          "channelLastN": 10,
        },
        featureFlags: {
          "recording.enabled": _isHost,
          "live-streaming.enabled": false,
          "raise-hand.enabled": true,
          "chat.enabled": true,
          "pip.enabled": true,
          "toolbox.alwaysVisible": true,
        },
      );
      await jitsi.join(options);
    } catch (e) {
      setState(() => _error = 'Could not connect. Check internet.');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilk,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kMilk, kMilkDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildCard(),
                const SizedBox(height: 16),
                Text(
                  'Enter the room code your Pastor shares before class',
                  style: TextStyle(
                    color: kTextLight.withOpacity(0.6), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kGoldLight, kGold],
            ),
          ),
          child: const Center(
            child: Text('✝',
              style: TextStyle(fontSize: 24, color: kWhite)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lifestones',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: kGold,
                ),
              ),
              Text(
                'Welcome, ${_user?.displayName?.split(' ').first ?? 'Member'}',
                style: TextStyle(
                  fontSize: 13,
                  color: kTextLight.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            await signOut();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: kGold.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Sign out',
              style: TextStyle(
                color: kTextLight, fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kGold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: kGold.withOpacity(0.1),
            blurRadius: 24, spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('ROOM CODE'),
          TextField(
            controller: _roomCtrl,
            style: const TextStyle(
              color: kText, fontSize: 22,
              letterSpacing: 6, fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            onChanged: (v) => _roomCtrl.value = _roomCtrl.value.copyWith(
              text: v.toUpperCase(),
              selection: TextSelection.collapsed(offset: v.length),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. FRIDAY',
              hintStyle: TextStyle(
                color: kTextLight.withOpacity(0.4),
                letterSpacing: 2, fontSize: 16,
              ),
              filled: true,
              fillColor: kMilk,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGold.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGold.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kGold, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          _label('I AM JOINING AS'),
          Row(children: [
            _roleBtn('🎤', 'Pastor', 'Records session', true),
            const SizedBox(width: 10),
            _roleBtn('🙏', 'Member', 'Listen & participate', false),
          ]),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_error,
              style: const TextStyle(color: kRed, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _joinMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: kGold.withOpacity(0.4),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                        color: kWhite, strokeWidth: 2),
                    )
                  : const Text('Join Class →',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
      style: TextStyle(
        color: kTextLight.withOpacity(0.8),
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    ),
  );

  Widget _roleBtn(String icon, String name, String desc, bool hostRole) {
    final selected = _isHost == hostRole;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isHost = hostRole),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kGold.withOpacity(0.08) : kMilk,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kGold : kGold.withOpacity(0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(name,
              style: TextStyle(
                color: selected ? kGoldDark : kTextLight,
                fontWeight: FontWeight.w700, fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(desc,
              style: TextStyle(
                color: selected
                    ? kGold.withOpacity(0.7)
                    : kTextLight.withOpacity(0.5),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}
