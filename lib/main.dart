import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'notification_service.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';

const kMilk      = Color(0xFFFDF6E3);
const kMilkDark  = Color(0xFFF0E6CC);
const kMilkDeep  = Color(0xFFE8D5B0);
const kGold      = Color(0xFFC9973A);
const kGoldLight = Color(0xFFE2B96F);
const kGoldDark  = Color(0xFFA07828);
const kGoldNeon  = Color(0xFFFFD700);
const kText      = Color(0xFF2C1A00);
const kTextLight = Color(0xFF8B6914);
const kWhite     = Color(0xFFFFFFFF);
const kRed       = Color(0xFFD32F2F);
const kGreen     = Color(0xFF2E7D32);
const kCard      = Color(0xFFFFFFFF);

final _googleSignIn = GoogleSignIn(scopes: ['email']);
final _auth = FirebaseAuth.instance;

Future<User?> signInWithGoogle({BuildContext? context}) async {
  try {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await FirebaseService.createOrUpdateUser();
    // Store FCM token for push notifications
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && result.user != null) {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .update({'fcmToken': token});
      }
    } catch (e) { debugPrint('FCM token error: \$e'); }
    // Immediately check role for new users
    if (result.user != null && context != null && context.mounted) {
      try {
        final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(result.user!.uid).get();
        final data = userDoc.data();
        if (data?['roleSetAt'] == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const RoleSelectionScreen()));
          return result.user;
        }
      } catch (e) { debugPrint('Role check: \$e'); }
    }
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
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: kMilk,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LifestonesApp());
}

void _scheduleDailyBibleNotification() {
  Future.doWhile(() async {
    await Future.delayed(const Duration(hours: 1));
    try {
      final now = DateTime.now();
      if (now.hour == 7 && now.minute < 60) {
        final List<Map<String,String>> plans = [
          {'book': 'Genesis 1-2', 'theme': 'Creation',
           'summary': 'God creates the heavens, earth, and mankind in His image.'},
          {'book': 'Genesis 3-4', 'theme': 'The Fall',
           'summary': 'Sin enters the world through disobedience. The first murder recorded.'},
          {'book': 'Psalm 1', 'theme': 'The Blessed Man',
           'summary': 'The man who meditates on Gods word day and night prospers in all he does.'},
          {'book': 'Proverbs 1', 'theme': 'Wisdom',
           'summary': 'Fear the Lord — the beginning of wisdom. Wisdom calls but fools reject her.'},
          {'book': 'Matthew 1-2', 'theme': 'Birth of Jesus',
           'summary': 'Jesus is born in Bethlehem. Wise men worship Him. Herod seeks to destroy the child.'},
          {'book': 'John 1', 'theme': 'The Word',
           'summary': 'In the beginning was the Word. Jesus becomes flesh and dwells among us.'},
          {'book': 'Romans 8', 'theme': 'Life in the Spirit',
           'summary': 'No condemnation for those in Christ. Nothing separates us from Gods love.'},
        ];
        final today = now.weekday - 1;
        final plan = plans[today % plans.length];
        await NotificationService.showLocalNotification(
          title: '📖 Daily Bible Reading - ${plan["theme"]}',
          body: '${plan["book"]}: ${plan["summary"]}',
        );
      }
    } catch (e) { debugPrint('Bible notify: \$e'); }
    return true;
  });
}

void _checkScheduledMeetings() {
  // Check every minute for upcoming meetings
  Future.doWhile(() async {
    await Future.delayed(const Duration(minutes: 1));
    try {
      final now = DateTime.now();
      final soon = now.add(const Duration(minutes: 30));
      final snap = await FirebaseFirestore.instance
        .collection('meetings')
        .where('isLive', isEqualTo: false)
        .where('scheduledAt', isGreaterThan: Timestamp.fromDate(now))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(soon))
        .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final topic = data['topic'] ?? 'Lifestones Class';
        final scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
        final diff = scheduledAt.difference(now).inMinutes;
        if (diff <= 30 && diff > 28) {
          // 30 min reminder
          await NotificationService.showLocalNotification(
            title: '⛪ Class in 30 minutes!',
            body: '"\$topic" starts at \${DateFormat("h:mm a").format(scheduledAt)}. Get ready!',
          );
        } else if (diff <= 5 && diff > 3) {
          // 5 min alarm
          await NotificationService.showLocalNotification(
            title: '🔔 Class starting NOW!',
            body: '"\$topic" is about to begin! Tap to join.',
          );
        }
      }
    } catch (e) { debugPrint('Schedule check error: \$e'); }
    return true;
  });
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
            return const SplashScreen();
          }
          if (snapshot.hasData) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
              builder: (ctx, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                final data = userSnap.data?.data() as Map<String, dynamic>?;
                // Check if banned - force sign out immediately
                if (data?['banned'] == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await GoogleSignIn().signOut();
                    await FirebaseAuth.instance.signOut();
                  });
                  return const LoginScreen();
                }
                // Check roleSetAt - only users who went through role selection have this
                final roleSet = data?['roleSetAt'] != null;
                if (!roleSet) return const RoleSelectionScreen();
                return const MainShell();
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kMilk,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✝', style: TextStyle(fontSize: 56, color: kGold)),
            SizedBox(height: 16),
            Text('Lifestones',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                color: kGold, letterSpacing: -1)),
            SizedBox(height: 8),
            Text('v1.0.0',
              style: TextStyle(fontSize: 12, color: kTextLight)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: kGold, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _error = '';
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _handleSignIn() async {
    setState(() { _loading = true; _error = ''; });
    final user = await signInWithGoogle(context: context);
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _error = 'Sign-in cancelled. Please try again.';
        _loading = false;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilk,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kMilk, kMilkDark],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [kGoldLight, kGold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(
                        color: kGold.withOpacity(0.5),
                        blurRadius: 32, spreadRadius: 4,
                      )],
                    ),
                    child: const Center(child: Text('✝',
                      style: TextStyle(fontSize: 48, color: kWhite))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Lifestones',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800,
                      color: kGold, letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text('DISCIPLESHIP · COMMUNITY · FAITH',
                    style: TextStyle(fontSize: 10, letterSpacing: 3.5,
                      color: kTextLight.withOpacity(0.6))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withOpacity(0.2)),
                    ),
                    child: Text('"Where iron sharpens iron" — Prov 27:17',
                      style: TextStyle(fontSize: 12,
                        color: kGoldDark.withOpacity(0.8),
                        fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: kGold.withOpacity(0.15)),
                      boxShadow: [BoxShadow(
                        color: kGold.withOpacity(0.12),
                        blurRadius: 32, spreadRadius: 2,
                        offset: const Offset(0, 6),
                      )],
                    ),
                    child: Column(
                      children: [
                        const Text('Welcome to the Family',
                          style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800, color: kText)),
                        const SizedBox(height: 8),
                        Text(
                          'Join thousands growing in faith together.\nSign in to access your discipleship classes.',
                          style: TextStyle(fontSize: 14, height: 1.5,
                            color: kTextLight.withOpacity(0.7)),
                          textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        if (_error.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_error,
                              style: const TextStyle(color: kRed, fontSize: 13),
                              textAlign: TextAlign.center),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kWhite,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              shadowColor: kGold.withOpacity(0.5),
                            ),
                            child: _loading
                              ? const SizedBox(height: 22, width: 22,
                                  child: CircularProgressIndicator(
                                    color: kWhite, strokeWidth: 2.5))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('G', style: TextStyle(
                                      color: kWhite,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20)),
                                    SizedBox(width: 12),
                                    Text('Continue with Google',
                                      style: TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kWhite)),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('By signing in, you join the Lifestones family ✝',
                          style: TextStyle(fontSize: 11,
                            color: kTextLight.withOpacity(0.5)),
                          textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = false;

  Future<void> _selectRole(String role) async {
    if (role == 'pastor') {
      final pin = await _showPinDialog();
      if (pin == null || pin.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wrong PIN. Try again.'),
              backgroundColor: kRed));
        }
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
          .collection('users').doc(uid).set({
            'role': role,
            'roleSetAt': FieldValue.serverTimestamp(),
            'chatApproved': role == 'pastor',
          }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Role error: \$e');
    }
    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

    Future<String?> _showPinDialog() async {
    String correctPin = '7749';
    try {
      final doc = await FirebaseFirestore.instance
        .collection('app_config').doc('security').get();
      if (doc.exists && doc.data()?['pastor_pin'] != null) {
        correctPin = doc.data()!['pastor_pin'];
      } else {
        await FirebaseFirestore.instance
          .collection('app_config').doc('security')
          .set({'pastor_pin': '7749'}, SetOptions(merge: true));
      }
    } catch (e) { debugPrint('PIN: \$e'); }
    final ctrl = TextEditingController();
    bool wrongPin = false;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
          title: const Text('Pastor PIN',
            style: TextStyle(fontWeight: FontWeight.w800, color: kText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your Pastor PIN',
                style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter PIN',
                  counterText: '',
                  errorText: wrongPin ? 'Incorrect PIN' : null,
                  filled: true, fillColor: kMilk,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none))),
            ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim() == correctPin) {
                  Navigator.pop(ctx, ctrl.text.trim());
                } else {
                  setS(() => wrongPin = true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
              child: const Text('Confirm')),
          ],
        ),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Security guard - must have Google account + not banned
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return const SplashScreen();
    }
    return Scaffold(
      backgroundColor: kMilk,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kGoldLight, kGold])),
                child: const Center(child: Text('✝',
                  style: TextStyle(fontSize: 40, color: kWhite)))),
              const SizedBox(height: 20),
              const Text('Welcome to Lifestones',
                style: TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 8),
              Text('How are you joining the family?',
                style: TextStyle(fontSize: 14,
                  color: kTextLight.withOpacity(0.7))),
              const SizedBox(height: 48),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _loading ? null : () => _selectRole('pastor'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.3)),
                        boxShadow: [BoxShadow(
                          color: kGoldNeon.withOpacity(0.15),
                          blurRadius: 16)]),
                      child: Column(children: [
                        const Text('🎤', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text('Pastor',
                          style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800, color: kText)),
                        const SizedBox(height: 4),
                        Text('Full access + PIN',
                          style: TextStyle(fontSize: 11,
                            color: kTextLight.withOpacity(0.6)),
                          textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _loading ? null : () => _selectRole('member'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.3)),
                        boxShadow: [BoxShadow(
                          color: kGoldNeon.withOpacity(0.15),
                          blurRadius: 16)]),
                      child: Column(children: [
                        const Text('🙏', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text('Member',
                          style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800, color: kText)),
                        const SizedBox(height: 4),
                        Text('Join & participate',
                          style: TextStyle(fontSize: 11,
                            color: kTextLight.withOpacity(0.6)),
                          textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator(color: kGold),
            ],
          ),
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
  int _tab = 0;
  final _screens = const [
    DiscoverScreen(),
    MeetingsScreen(),
    MembersScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  Widget _buildChatIcon(bool active) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Icon(active
      ? Icons.chat_bubble : Icons.chat_bubble_outline);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users').doc(uid).snapshots(),
      builder: (ctx, userSnap) {
        final userData = userSnap.data?.data() as Map<String,dynamic>?;
        final lastSeen = userData?['lastSeenChat'] as Timestamp?;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
            .collection('messages')
            .orderBy('sentAt', descending: true)
            .limit(1).snapshots(),
          builder: (ctx2, msgSnap) {
            bool hasUnread = false;
            if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
              final m = msgSnap.data!.docs.first.data()
                as Map<String,dynamic>;
              final mt = m['sentAt'] as Timestamp?;
              final sender = m['senderUid'] as String?;
              if (mt != null && sender != uid) {
                if (lastSeen == null ||
                  mt.seconds > lastSeen.seconds) {
                  hasUnread = true;
                }
              }
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(active
                  ? Icons.chat_bubble
                  : Icons.chat_bubble_outline),
                if (hasUnread) Positioned(
                  right: -3, top: -3,
                  child: Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(
                      color: kRed,
                      shape: BoxShape.circle))),
              ]);
          });
      });
  }

  Widget? _buildResourcesFAB(BuildContext context) {
    if (_tab != 0) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'prayer',
          backgroundColor: kGold,
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrayerScreen())),
          child: const Text('🙏', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'hymns',
          backgroundColor: kGold,
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HymnScreen())),
          child: const Text('🎵', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'bible',
          backgroundColor: kGold,
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BibleScreen())),
          child: const Text('📖', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilk,
      body: _screens[_tab],
      floatingActionButton: _buildResourcesFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(
            color: kGold.withOpacity(0.1),
            blurRadius: 20, offset: const Offset(0, -4),
          )],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: kWhite,
          selectedItemColor: kGold,
          unselectedItemColor: kTextLight.withOpacity(0.4),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover'),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getLiveMeetings(),
                builder: (ctx, snap) {
                  final isLive = snap.hasData &&
                    snap.data!.docs.isNotEmpty;
                  return Stack(
                    children: [
                      const Icon(Icons.cell_tower_outlined),
                      if (isLive) Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: kRed,
                            shape: BoxShape.circle))),
                    ],
                  );
                },
              ),
              activeIcon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getLiveMeetings(),
                builder: (ctx, snap) {
                  final isLive = snap.hasData &&
                    snap.data!.docs.isNotEmpty;
                  return Stack(
                    children: [
                      const Icon(Icons.cell_tower),
                      if (isLive) Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: kRed,
                            shape: BoxShape.circle))),
                    ],
                  );
                },
              ),
              label: 'Sanctuary'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Members'),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getMessages(),
                                builder: (ctx, snap) {
                  // If there is data, and we are NOT currently on the Chat tab (_tab == 3)
                  final hasUnread = snap.hasData && snap.data!.docs.isNotEmpty && _tab != 3;
                  
                  if (hasUnread) {
                    return const Badge(
                      backgroundColor: Colors.red,
                      smallSize: 9,
                      child: Icon(Icons.chat_bubble_outline),
                    );
                  }
                  return const Icon(Icons.chat_bubble_outline);
                },
              ),
              activeIcon: const Icon(Icons.chat_bubble),
              label: 'Chat'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final PageController _scriptureCtrl = PageController();
  int _currentPage = 0;
  bool _isPaused = false;

  final List<Map<String, String>> _scriptures = [
    {'verse': '"I can do all things through Christ who strengthens me."', 'ref': 'Philippians 4:13'},
    {'verse': '"The Lord is my shepherd; I shall not want."', 'ref': 'Psalm 23:1'},
    {'verse': '"Trust in the Lord with all your heart."', 'ref': 'Proverbs 3:5'},
    {'verse': '"For I know the plans I have for you, declares the Lord."', 'ref': 'Jeremiah 29:11'},
    {'verse': '"Be still, and know that I am God."', 'ref': 'Psalm 46:10'},
    {'verse': '"The joy of the Lord is your strength."', 'ref': 'Nehemiah 8:10'},
    {'verse': '"With God all things are possible."', 'ref': 'Matthew 19:26'},
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted || _isPaused) { _startAutoScroll(); return; }
      final next = (_currentPage + 1) % _scriptures.length;
      _scriptureCtrl.animateToPage(next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut);
      setState(() => _currentPage = next);
      _startAutoScroll();
    });
  }

  @override
  void dispose() { _scriptureCtrl.dispose(); super.dispose(); }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: RefreshIndicator(
          color: kGold,
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 20),
                    Text('$_greeting, ${_user?.displayName?.split(' ').first ?? 'Friend'} 🙏',
                      style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800, color: kText)),
                    const SizedBox(height: 4),
                    Text('Welcome back to the family',
                      style: TextStyle(fontSize: 13,
                        color: kTextLight.withOpacity(0.7))),
                    const SizedBox(height: 20),
                    _buildScriptureCarousel(),
                    const SizedBox(height: 20),
                    _buildMeetingsLayer(),
                    const SizedBox(height: 20),
                    _buildBiblePlanLayer(),
                    const SizedBox(height: 20),
                    _buildAudioLayer(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [kGoldLight, kGold])),
          child: const Center(child: Text('✝',
            style: TextStyle(fontSize: 20, color: kWhite)))),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lifestones',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: kGold)),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                .collection('app_config')
                .doc('version')
                .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final data = snap.data?.data() as Map<String, dynamic>?;
                final latest = data?['latest_version'] ?? '1.0.0';
                const current = '1.0.0';
                if (latest != current) {
                  return GestureDetector(
                    onTap: () {
                      final url = data?['download_url'] ?? '';
                      if (url.isNotEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Update v\$latest available! Download from your Pastor.'),
                            backgroundColor: kGold,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('Update v\$latest',
                        style: const TextStyle(
                          color: kWhite, fontSize: 9,
                          fontWeight: FontWeight.w700))),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            final shell = context.findAncestorStateOfType<_MainShellState>();
            shell?.setState(() => shell._tab = 3);
          },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: kWhite,
              border: Border.all(color: kGold.withOpacity(0.2)),
              boxShadow: [BoxShadow(
                color: kGoldNeon.withOpacity(0.15),
                blurRadius: 8, spreadRadius: 1)]),
            child: const Icon(Icons.notifications_outlined,
              color: kGold, size: 20))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final shell = context.findAncestorStateOfType<_MainShellState>();
            shell?.setState(() => shell._tab = 4);
          },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: kGold,
              boxShadow: [BoxShadow(
                color: kGoldNeon.withOpacity(0.3),
                blurRadius: 8, spreadRadius: 1)]),
            child: Center(child: Text(
              (_user?.displayName ?? 'M')[0].toUpperCase(),
              style: const TextStyle(color: kWhite,
                fontWeight: FontWeight.w800, fontSize: 16))))),
      ],
    );
  }

  Widget _buildScriptureCarousel() {
    return Column(
      children: [
        GestureDetector(
          onLongPressStart: (_) => setState(() => _isPaused = true),
          onLongPressEnd: (_) => setState(() => _isPaused = false),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kGold, kGoldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: kGoldNeon.withOpacity(0.3),
                blurRadius: 16, spreadRadius: 2,
                offset: const Offset(0, 4))]),
            child: PageView.builder(
              controller: _scriptureCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _scriptures.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📖', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(_scriptures[i]['verse']!,
                      style: const TextStyle(color: kWhite, fontSize: 14,
                        fontStyle: FontStyle.italic, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(_scriptures[i]['ref']!,
                      style: TextStyle(color: kWhite.withOpacity(0.8),
                        fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_scriptures.length, (i) =>
            Container(
              width: i == _currentPage ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == _currentPage ? kGold : kGold.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3)))),
        ),
      ],
    );
  }

  Widget _buildMeetingsLayer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: kGoldNeon.withOpacity(0.12),
          blurRadius: 16, spreadRadius: 2,
          offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅 Upcoming Classes',
                style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800, color: kText)),
              const Spacer(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getLiveMeetings(),
                builder: (ctx, snap) {
                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(20)),
                      child: const Row(children: [
                        Icon(Icons.circle, color: kWhite, size: 6),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: kWhite,
                          fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                      ]));
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getUpcomingMeetings(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kMilk,
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Text('⛪', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Classes: Friday, Saturday & Sunday · 6:00 PM',
                      style: TextStyle(fontSize: 12,
                        color: kTextLight.withOpacity(0.8)))),
                  ]));
              }
              return Column(
                children: snap.data!.docs.take(2).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dt = (data['scheduledAt'] as Timestamp).toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kMilk,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.2))),
                    child: Row(children: [
                      const Text('📖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['topic'] ?? 'Class',
                            style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: kText)),
                          Text(DateFormat('EEE, MMM d · h:mm a').format(dt),
                            style: TextStyle(fontSize: 11,
                              color: kTextLight.withOpacity(0.7))),
                        ],
                      )),
                    ]));
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRecordingDetail(Map<String, dynamic> data, BuildContext ctx) {
    final summary = data['summary'] ?? '';
    final title = data['title'] ?? 'Class Recording';
    final url = data['downloadUrl'] ?? '';
    final uploadedBy = data['uploadedBy'] ?? 'Pastor';
    final ts = data['endedAt'] as Timestamp?;
    final date = ts != null
      ? DateFormat('EEE, MMM d, yyyy · h:mm a').format(ts.toDate()) : '';

    showModalBottomSheet(
      context: ctx,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.mic, color: kGold, size: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
                    Text('By \$uploadedBy · \$date',
                      style: TextStyle(fontSize: 11,
                        color: kTextLight.withOpacity(0.6))),
                  ],
                )),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _playRecording(url, ctx),
                    icon: Icon(_isPlaying && _currentUrl == url
                      ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying && _currentUrl == url
                      ? 'Pause' : 'Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadRecording(url, title, ctx),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGold,
                      side: const BorderSide(color: kGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kMilk,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGold.withOpacity(0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('🤖 AI Class Summary',
                        style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: kText)),
                      const Spacer(),
                      if (summary.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                          child: Text('Coming soon',
                            style: TextStyle(fontSize: 10,
                              color: kGoldDark))),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      summary.isEmpty
                        ? 'AI summary will appear here after the class recording is processed. '
                          'This gives members who missed the class a quick overview of what was taught.'
                        : summary,
                      style: TextStyle(
                        fontSize: 13, height: 1.6,
                        color: summary.isEmpty
                          ? kTextLight.withOpacity(0.5)
                          : kText.withOpacity(0.85),
                        fontStyle: summary.isEmpty
                          ? FontStyle.italic : FontStyle.normal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentUrl = '';

  Future<void> _playRecording(String url, BuildContext ctx) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Audio not available yet'),
          backgroundColor: kRed));
      return;
    }
    try {
      if (_isPlaying && _currentUrl == url) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
        return;
      }
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      setState(() { _isPlaying = true; _currentUrl = url; });
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      debugPrint('Play error: \$e');
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Playback error: \$e'),
            backgroundColor: kRed));
      }
    }
  }

  Future<void> _downloadRecording(
    String url, String title, BuildContext ctx) async {
    if (url.isEmpty) return;
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) return;
      final dir = await getExternalStorageDirectory();
      final path = '\${dir!.path}/\$title.aac';
      final dio = Dio();
      await dio.download(url, path,
        onReceiveProgress: (received, total) {
          debugPrint('Download: \$received/\$total');
        });
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('✅ Saved to Downloads: \$title'),
            backgroundColor: kGreen,
            duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      debugPrint('Download error: \$e');
    }
  }


  Widget _buildBiblePlanLayer() {
    final List<Map<String,String>> plans = [
      {'day': 'Day 1', 'book': 'Genesis 1-2', 'theme': 'Creation',
       'summary': 'God creates the heavens, earth, and mankind in His image. He rests on the seventh day and calls it holy.'},
      {'day': 'Day 2', 'book': 'Genesis 3-4', 'theme': 'The Fall',
       'summary': 'Adam and Eve disobey God and sin enters the world. Cain kills Abel — the first murder recorded in scripture.'},
      {'day': 'Day 3', 'book': 'Psalm 1', 'theme': 'The Blessed Man',
       'summary': 'The man who meditates on Gods word day and night is like a tree planted by rivers of water. He prospers in all he does.'},
      {'day': 'Day 4', 'book': 'Proverbs 1', 'theme': 'Wisdom',
       'summary': 'Solomon calls us to fear the Lord — the beginning of all wisdom. Wisdom cries out in the streets but fools reject her call.'},
      {'day': 'Day 5', 'book': 'Matthew 1-2', 'theme': 'Birth of Jesus',
       'summary': 'Jesus is born of a virgin in Bethlehem. Wise men follow a star to worship Him. Herod seeks to destroy the child.'},
      {'day': 'Day 6', 'book': 'John 1', 'theme': 'The Word',
       'summary': 'In the beginning was the Word, and the Word was God. Jesus — the light of the world — becomes flesh and dwells among us.'},
      {'day': 'Day 7', 'book': 'Romans 8', 'theme': 'Life in the Spirit',
       'summary': 'There is no condemnation for those in Christ. The Spirit gives life and power. Nothing can separate us from the love of God.'},
    ];
    final today = DateTime.now().weekday - 1;
    final todayPlan = plans[today % plans.length];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: kGoldNeon.withOpacity(0.12),
          blurRadius: 16, spreadRadius: 2,
          offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📖 Bible Reading Plan',
              style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: kText)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Text('Today',
                style: TextStyle(fontSize: 10,
                  color: kGoldDark,
                  fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kGold.withOpacity(0.08),
                  kGold.withOpacity(0.03)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGold.withOpacity(0.2))),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: kGold,
                  borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.menu_book,
                  color: kWhite, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todayPlan['day']!,
                    style: TextStyle(fontSize: 11,
                      color: kGoldDark,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(todayPlan['book']!,
                    style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: kText)),
                  Text(todayPlan['theme']!,
                    style: TextStyle(fontSize: 12,
                      color: kGoldDark.withOpacity(0.8),
                      fontWeight: FontWeight.w600)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kMilk,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold.withOpacity(0.15))),
            child: Text(
              todayPlan['summary'] ?? '',
              style: TextStyle(fontSize: 12,
                color: kText.withOpacity(0.75),
                height: 1.6,
                fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: plans.asMap().entries.map((e) {
              final isToday = e.key == today % plans.length;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: isToday ? kGold : kGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2))));
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            '${today % plans.length + 1} of ${plans.length} days this week',
            style: TextStyle(fontSize: 11,
              color: kTextLight.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildAudioLayer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: kGoldNeon.withOpacity(0.12),
          blurRadius: 16, spreadRadius: 2,
          offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎙️ Past Recordings',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: kText)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
              .collection('recordings')
              .orderBy('endedAt', descending: true)
              .limit(20)
              .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kMilk,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGold.withOpacity(0.1))),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: kGold,
                        borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.mic, color: kWhite, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No recordings yet',
                          style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: kText)),
                        Text('Past classes will appear here',
                          style: TextStyle(fontSize: 11,
                            color: kTextLight.withOpacity(0.6))),
                      ],
                    )),
                  ]),
                );
              }
              final validDocs = snap.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['downloadUrl'] ?? '').toString().isNotEmpty;
                  }).toList();
              if (validDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kMilk,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGold.withOpacity(0.1))),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: kGold,
                        borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.mic,
                        color: kWhite, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No recordings yet',
                          style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: kText)),
                        Text('Past classes will appear here',
                          style: TextStyle(fontSize: 11,
                            color: kTextLight.withOpacity(0.6))),
                      ],
                    )),
                  ]),
                );
              }
              return Column(
                children: validDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['endedAt'] as Timestamp?;
                  final date = ts != null
                    ? DateFormat('EEE, MMM d · h:mm a').format(ts.toDate())
                    : 'Recent';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kMilk,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.15))),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: kGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.mic, color: kGold, size: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['title'] ?? 'Class Recording',
                            style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: kText)),
                          Text(date,
                            style: TextStyle(fontSize: 11,
                              color: kTextLight.withOpacity(0.6))),
                        ],
                      )),
                      Row(children: [
                        GestureDetector(
                          onTap: () => _playRecording(
                            data['downloadUrl'] ?? '', ctx),
                          child: const Icon(Icons.play_circle_outline,
                            color: kGold, size: 28)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _downloadRecording(
                            data['downloadUrl'] ?? '',
                            data['title'] ?? 'recording', ctx),
                          child: const Icon(Icons.download_outlined,
                            color: kGold, size: 24)),
                      ]),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _currentTopic;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording(String roomCode) async {
    final micStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();
    if (!micStatus.isGranted) return;
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '\${dir.path}/recording_\$roomCode\_\${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder!.openRecorder();
    await _recorder!.startRecorder(
      toFile: _recordingPath,
      codec: Codec.aacADTS,
    );
    setState(() => _isRecording = true);
    debugPrint('Recording started: \$_recordingPath');
  }

  Future<void> _stopRecordingAndUpload(String roomCode) async {
    if (!_isRecording || _recorder == null) return;
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    if (_recordingPath == null) return;
    final file = File(_recordingPath!);
    if (!await file.exists()) return;

    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance
        .ref('recordings/\$roomCode/\${DateTime.now().millisecondsSinceEpoch}.aac');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save to Firestore
      // Get topic from live meeting
      String meetingTopic = 'Lifestones Class';
      try {
        final doc = await FirebaseFirestore.instance
          .collection('meetings').doc('current_live').get();
        meetingTopic = doc.data()?['topic'] ?? 'Lifestones Class';
      } catch (e) { debugPrint('Topic fetch error: \$e'); }

      await FirebaseFirestore.instance.collection('recordings').add({
        'roomCode': roomCode,
        'downloadUrl': downloadUrl,
        'title': meetingTopic,
        'duration': '',
        'uploadedBy': _user?.displayName ?? 'Pastor',
        'uploadedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'summary': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recording saved for all members!'),
            backgroundColor: kGreen,
            duration: Duration(seconds: 4)));
      }
    } catch (e) {
      debugPrint('Upload error: \$e');
    }
  }

  void _showRoleDialog({required bool isStarting, String? roomCode}) {
    String selectedRole = 'member';
    final topicCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(isStarting ? 'Starting a Class' : 'Joining the Class',
                style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 6),
              Text('How are you joining today?',
                style: TextStyle(fontSize: 14,
                  color: kTextLight.withOpacity(0.7))),
              const SizedBox(height: 16),
              if (isStarting) ...[
                TextField(
                  controller: topicCtrl,
                  decoration: InputDecoration(
                    hintText: 'Class topic or theme (e.g. Faith, Prayer)...',
                    filled: true, fillColor: kMilk,
                    prefixIcon: const Icon(Icons.book_outlined, color: kGold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kGold.withOpacity(0.3))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kGold.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGold, width: 2))),
                ),
                const SizedBox(height: 16),
              ],
              Row(children: [
                _roleOption(setModal, '🎤', 'Pastor',
                  'Lead the session', selectedRole == 'pastor',
                  () async {
                    final pinCtrl = TextEditingController();
                    final verified = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: kWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                        title: const Text('Pastor Verification',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kText)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Enter your Pastor PIN to continue',
                              style: TextStyle(
                                color: kTextLight.withOpacity(0.7),
                                fontSize: 13)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: pinCtrl,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 8,
                                color: kText),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••',
                                hintStyle: TextStyle(
                                  color: kTextLight.withOpacity(0.3),
                                  letterSpacing: 8),
                                filled: true,
                                fillColor: kMilk,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: kGold.withOpacity(0.3))),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: kGold.withOpacity(0.3))),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: kGold, width: 2))),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                              style: TextStyle(
                                color: kTextLight.withOpacity(0.6)))),
                          ElevatedButton(
                            onPressed: () async {
                              final doc = await FirebaseFirestore.instance
                                .collection('app_config')
                                .doc('security').get();
                              final pin = doc.data()?['pastor_pin'] ?? '7749';
                              if (pinCtrl.text == pin) {
                                Navigator.pop(ctx, true);
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Wrong PIN. Try again.'),
                                    backgroundColor: kRed));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                            child: const Text('Verify',
                              style: TextStyle(
                                fontWeight: FontWeight.w700))),
                        ],
                      ),
                    );
                    if (verified == true) {
                      setModal(() => selectedRole = 'pastor');
                    }
                  }),
                const SizedBox(width: 10),
                _roleOption(setModal, '🙏', 'Member',
                  'Join & participate', selectedRole == 'member',
                  () => setModal(() => selectedRole = 'member')),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (isStarting) {
                      final topic = topicCtrl.text.trim().isEmpty
                        ? 'Lifestones Class'
                        : topicCtrl.text.trim();
                      await _startMeeting(selectedRole, topic: topic);
                    } else {
                      await _joinMeeting(roomCode!, selectedRole);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                  child: Text(isStarting ? 'Start Class 🔴' : 'Join Class →',
                    style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleOption(StateSetter setModal, String icon, String title,
    String desc, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kGold.withOpacity(0.08) : kMilk,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kGold : kGold.withOpacity(0.2),
              width: selected ? 2 : 1)),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(
              color: selected ? kGoldDark : kTextLight,
              fontWeight: FontWeight.w700, fontSize: 14)),
            Text(desc, style: TextStyle(
              color: selected ? kGold.withOpacity(0.7)
                : kTextLight.withOpacity(0.5),
              fontSize: 10), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Future<void> _startMeeting(String role, {String topic = 'Lifestones Class'}) async {
    final roomCode = await FirebaseService.createMeeting(
      topic: topic,
      starterName: _user?.displayName ?? 'Member',
      starterUid: _user?.uid ?? '',
      role: role,
    );
    await NotificationService.sendMeetingStarted(
      _user?.displayName ?? 'Someone');
    if (role == 'pastor') {
      await _startRecording(roomCode);
    }
    await _joinMeeting(roomCode, role);
  }

  Future<void> _endMeetingAndRecord(String roomCode) async {
    final user = FirebaseAuth.instance.currentUser;
    // Stop recording and upload to Firebase Storage
    try {
      if (_isRecording) {
        final path = await _recorder!.stopRecorder();
        setState(() => _isRecording = false);
        if (path != null && path.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading recording...'),
              duration: Duration(seconds: 2)));
          await FirebaseService.saveRecording(
            localPath: path,
            roomCode: roomCode,
            topic: 'Lifestones Class',
            starterUid: user?.uid ?? '',
            starterName: user?.displayName ?? 'Pastor',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording saved to Past Recordings'),
                backgroundColor: kGreen));
          }
        }
      }
    } catch (e) {
      debugPrint('Recording upload error: \$e');
    }
    // Stop recording and upload
    try {
      if (_isRecording) {
        final path = await _recorder?.stopRecorder();
        setState(() => _isRecording = false);
        if (path != null && path.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Uploading recording...')));
          }
          await FirebaseService.saveRecording(
            localPath: path,
            roomCode: roomCode,
            topic: _currentTopic ?? 'Lifestones Class',
            starterUid: _user?.uid ?? '',
            starterName: _user?.displayName ?? 'Pastor',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording saved!'),
                backgroundColor: kGreen));
          }
        }
      }
    } catch (e) { debugPrint('Recording error: \$e'); }
    await FirebaseService.endMeeting(roomCode);
  }

  Future<void> _joinMeeting(String roomCode, String role) async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet'),
          backgroundColor: kRed));
      return;
    }
    try {
      final jitsi = JitsiMeet();
      // Track attendance
      try {
        final meetDoc = await FirebaseFirestore.instance
          .collection('meetings').doc('current_live').get();
        final meetData = meetDoc.data();
        if (meetData != null) {
          final attRoom = meetData['roomCode'] ?? roomCode;
          final attUid = _user?.uid ?? 'unknown';
          final attDocId = '\${attRoom}_\$attUid';
          final attRef = FirebaseFirestore.instance
            .collection('attendance').doc(attDocId);
          final attSnap = await attRef.get();
          if (!attSnap.exists) {
            await attRef.set({
              'uid': attUid,
              'name': _user?.displayName ?? 'Member',
              'roomCode': attRoom,
              'topic': meetData['topic'] ?? 'Lifestones Class',
              'joinedAt': FieldValue.serverTimestamp(),
              'role': role,
            });
          }
        }
      } catch (e) { debugPrint('Attendance error: \$e'); }

      await jitsi.join(JitsiMeetConferenceOptions(
        serverURL: "https://meet.ffmuc.net",
        room: 'Lifestones-$roomCode',
        userInfo: JitsiMeetUserInfo(
          displayName: _user?.displayName ?? 'Member',
          email: _user?.email,
        ),
        configOverrides: {
          'startWithAudioMuted': false,
          'startWithVideoMuted': true,
          'disableDeepLinking': true,
          'prejoinPageEnabled': false,
          'lobby.enabled': false,
          'p2p.enabled': true,
          'channelLastN': 10,
        },
        featureFlags: {
          'recording.enabled': role == 'pastor',
          'live-streaming.enabled': false,
          'raise-hand.enabled': true,
          'chat.enabled': true,
          'pip.enabled': true,
          'toolbox.alwaysVisible': true,
          'invite.enabled': false,
          'video-mute.enabled': false,
          'meeting-password.enabled': false,
        },
      ));
    } catch (e) { debugPrint('Join error: $e'); }
  }

  void _shareLink(String roomCode) {
    final link = 'https://sm-bello.github.io/Lifestones/?room=\$roomCode';
    final msg = '🔴 A Lifestones class is LIVE right now.\n\n'
      'You do not need to download anything. '
      'Just tap the link below, come with a hungry spirit, '
      'and be blessed by the Word of God:\n\n'
      '\$link\n\n'
      '"Where iron sharpens iron" — Proverbs 27:17 🙏';
    Share.share(msg, subject: '⛪ Join Lifestones Class LIVE');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: RefreshIndicator(
          color: kGold,
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('The Sanctuary',
                style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.w800, color: kText,
                  letterSpacing: -0.5)),
              Text('Powered by the Lifestones Data Saver Engine',
                style: TextStyle(fontSize: 13,
                  color: kTextLight.withOpacity(0.6))),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getLiveMeetings(),
                builder: (ctx, snap) {
                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    final data = snap.data!.docs.first.data()
                      as Map<String, dynamic>;
                    return _buildLiveCard(data);
                  }
                  return _buildEmptySanctuary();
                },
              ),
              const SizedBox(height: 20),
              _buildStartButton(),
              const SizedBox(height: 20),
              _buildScheduleSection(),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(_user?.uid)
        .snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final isPastor = data?['role'] == 'pastor';
        if (!isPastor) return const SizedBox();
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showRoleDialog(isStarting: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: kGoldNeon.withOpacity(0.4)),
            child: const Text('Start a Class 🔴',
              style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800)),
          ),
        );
      },
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> data) {
    final isLive = data['isLive'] == true; // isLive == true
    if (!isLive) return const SizedBox();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1.02),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      onEnd: () => setState(() {}),
      builder: (ctx, scale, child) => Transform.scale(
        scale: scale, child: child),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kGold, kGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99FFD700),
            blurRadius: 32, spreadRadius: 6),
          BoxShadow(
            color: Color(0x66C9973A),
            blurRadius: 16, spreadRadius: 2),
        ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kRed, borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.circle, color: kWhite, size: 6),
                SizedBox(width: 4),
                Text('LIVE', style: TextStyle(color: kWhite,
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ])),
            const Spacer(),
            GestureDetector(
              onTap: () => _shareLink(data['roomCode'] ?? ''),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.share, color: kWhite, size: 14),
                  SizedBox(width: 4),
                  Text('Share', style: TextStyle(color: kWhite,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                ]))),
          ]),
          const SizedBox(height: 12),
          Text(data['topic'] ?? 'Lifestones Class',
            style: const TextStyle(color: kWhite, fontSize: 20,
              fontWeight: FontWeight.w800)),
          Text('Started by ${data['starterName'] ?? 'Member'}',
            style: TextStyle(color: kWhite.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showRoleDialog(
                  isStarting: false, roomCode: data['roomCode']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kWhite,
                  foregroundColor: kGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: const Text('Join Live Service',
                  style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800)),
              ),
            ),
            if (data['starterUid'] == _user?.uid) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await _endMeetingAndRecord(data['roomCode']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('End Class',
                        style: TextStyle(color: kWhite,
                          fontWeight: FontWeight.w800, fontSize: 12)),
                      Text('saves recording',
                        style: TextStyle(color: Colors.white70, fontSize: 9)),
                    ]),
              ),
            ],
          ]),
        ],
      ),
    ));
  }

  Widget _buildEmptySanctuary() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users').doc(_user?.uid).snapshots(),
      builder: (ctx, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final isPastor = userData?['role'] == 'pastor';
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getLiveMeetings(),
          builder: (ctx, liveSnap) {
            final hasLive = liveSnap.hasData &&
              liveSnap.data!.docs.isNotEmpty;
            return Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kGold.withOpacity(0.15)),
                boxShadow: [BoxShadow(
                  color: kGoldNeon.withOpacity(0.1),
                  blurRadius: 16, spreadRadius: 2)]),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasLive
                      ? kGold.withOpacity(0.15)
                      : kGold.withOpacity(0.1)),
                  child: Icon(
                    hasLive ? Icons.wifi_tethering : Icons.cell_tower,
                    color: kGold, size: 36)),
                const SizedBox(height: 16),
                Text(
                  hasLive ? '🔴 Class is Live!' : 'The Sanctuary',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: hasLive ? kGoldDark : kText)),
                const SizedBox(height: 8),
                Text(
                  hasLive
                    ? 'A class is in session.\nTap Join Live Service above!'
                    : isPastor
                      ? 'No class is live.\nTap "Start a Class" to begin.'
                      : '⛪ Waiting for your Pastor to begin.\nPull down to refresh anytime.',
                  style: TextStyle(fontSize: 13, height: 1.5,
                    color: kTextLight.withOpacity(0.7)),
                  textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (!hasLive) Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: kMilk,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withOpacity(0.2))),
                  child: Text('⬇️ Pull down to refresh',
                    style: TextStyle(fontSize: 11,
                      color: kTextLight.withOpacity(0.6)))),
              ]),
            );
          },
        );
      },
    );
  }



  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: kGoldNeon.withOpacity(0.1),
          blurRadius: 16, spreadRadius: 1)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Schedule a Class',
              style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: kText)),
            const Spacer(),
            GestureDetector(
              onTap: _showScheduleDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kGold,
                  borderRadius: BorderRadius.circular(20)),
                child: const Text('+ New',
                  style: TextStyle(color: kWhite, fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          ]),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getUpcomingMeetings(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Text('No classes scheduled yet.',
                  style: TextStyle(fontSize: 13,
                    color: kTextLight.withOpacity(0.6)));
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dt = (data['scheduledAt'] as Timestamp).toDate();
                  final topic = data['topic'].toString();
                  final roomCode = topic.toUpperCase()
                    .replaceAll(' ', '')
                    .substring(0, topic.length > 8 ? 8 : topic.length);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kMilk,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.2))),
                    child: Row(children: [
                      const Text('📖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topic, style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: kText)),
                          Text(DateFormat('EEE, MMM d · h:mm a').format(dt),
                            style: TextStyle(fontSize: 11,
                              color: kTextLight.withOpacity(0.7))),
                        ],
                      )),
                      Row(children: [
                        GestureDetector(
                          onTap: () => _shareLink(roomCode),
                          child: const Icon(Icons.share,
                            color: kGold, size: 18)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            await FirebaseService.deleteMeeting(doc.id);
                          },
                          child: const Icon(Icons.delete_outline,
                            color: kRed, size: 18)),
                      ]),
                    ]));
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    final topicCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Schedule a Class',
                style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 20),
              TextField(
                controller: topicCtrl,
                decoration: InputDecoration(
                  hintText: 'Class topic...',
                  filled: true, fillColor: kMilk,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kGold.withOpacity(0.3))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kGold.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGold, width: 2)))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setModal(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kMilk,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.3))),
                    child: Text(
                      selectedDate != null
                        ? DateFormat('MMM d, yyyy').format(selectedDate!)
                        : 'Pick date',
                      style: TextStyle(color: selectedDate != null
                        ? kText : kTextLight.withOpacity(0.4)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 18, minute: 0));
                    if (t != null) setModal(() => selectedTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kMilk,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.3))),
                    child: Text(
                      selectedTime != null
                        ? selectedTime!.format(ctx)
                        : 'Pick time',
                      style: TextStyle(color: selectedTime != null
                        ? kText : kTextLight.withOpacity(0.4)))))),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (topicCtrl.text.isEmpty || selectedDate == null ||
                      selectedTime == null) return;
                    final dt = DateTime(
                      selectedDate!.year, selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour, selectedTime!.minute);
                    await FirebaseService.scheduleMeeting(
                      topic: topicCtrl.text,
                      scheduledAt: dt,
                      createdBy: _user?.displayName ?? 'Member');
                    if (mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                  child: const Text('Schedule Class',
                    style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Members',
                    style: TextStyle(fontSize: 28,
                      fontWeight: FontWeight.w800, color: kText,
                      letterSpacing: -0.5)),
                  Text('The Lifestones family',
                    style: TextStyle(fontSize: 14,
                      color: kTextLight.withOpacity(0.6))),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: const Icon(Icons.search, color: kGold),
                      filled: true, fillColor: kWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: kGold.withOpacity(0.2))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: kGold.withOpacity(0.2))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kGold, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12))),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getAllUsers(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(
                      color: kGold));
                  }
                  final members = snap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['displayName'] ?? '').toLowerCase();
                    return _search.isEmpty || name.contains(_search);
                  }).toList();
                  if (members.isEmpty) {
                    return Center(child: Text('No members found',
                      style: TextStyle(color: kTextLight.withOpacity(0.5))));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: members.length,
                    itemBuilder: (_, i) {
                      final data = members[i].data() as Map<String, dynamic>;
                      final uid = members[i].id;
                      final isCurrentUser = uid == FirebaseAuth.instance.currentUser?.uid;
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                        builder: (ctx, pastorSnap) {
                          final pastorData = pastorSnap.data?.data()
                            as Map<String, dynamic>?;
                          final isPastor = pastorData?['role'] == 'pastor';
                          if (isPastor && !isCurrentUser) {
                            return Dismissible(
                              key: Key(uid),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: kRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.person_remove,
                                      color: kRed, size: 28),
                                    const SizedBox(height: 4),
                                    const Text('Remove',
                                      style: TextStyle(
                                        color: kRed, fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: kWhite,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                    title: Text('Remove ${data["displayName"] ?? "Member"}?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: kText)),
                                    content: const Text(
                                      'This will sign them out and remove their access. They can rejoin by logging in again.',
                                      style: TextStyle(fontSize: 13)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kRed,
                                          foregroundColor: kWhite,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10))),
                                        child: const Text('Remove')),
                                    ],
                                  ),
                                ) ?? false;
                              },
                              onDismissed: (_) async {
                                // Remove roleSetAt so they must re-select role
                                // First set banned flag
                              // Delete entirely from database
                              await FirebaseFirestore.instance
                                  .collection('users').doc(uid).delete();
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('${data["displayName"] ?? "Member"} removed'),
                                      backgroundColor: kRed));
                                }
                              },
                              child: _buildMemberCard(data),
                            );
                          }
                          return _buildMemberCard(data);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> data) {
    final name = data['displayName'] ?? 'Member';
    final bio = data['bio'] ?? '';
    final role = data['role'] ?? 'member';
    final photo = data['photoUrl'] ?? '';
    return GestureDetector(
      onTap: () => _showMemberProfile(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGold.withOpacity(0.12)),
          boxShadow: [BoxShadow(
            color: kGoldNeon.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 3))]),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                border: Border.all(color: kGold.withOpacity(0.3), width: 2)),
              child: photo.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: photo, fit: BoxFit.cover))
                : Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: kWhite,
                      fontWeight: FontWeight.w800, fontSize: 20)))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name, style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: kText)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: role == 'pastor'
                          ? kGold.withOpacity(0.15) : kMilk,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        role == 'pastor' ? '🎤 Pastor' : '🙏 Member',
                        style: TextStyle(fontSize: 10,
                          color: role == 'pastor' ? kGoldDark : kTextLight,
                          fontWeight: FontWeight.w600))),
                  ]),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(bio, style: TextStyle(fontSize: 12,
                      color: kTextLight.withOpacity(0.7)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if ((data['phone'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📞 ${data['phone']}',
                      style: TextStyle(fontSize: 11,
                        color: kGold.withOpacity(0.8))),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
              color: kGold.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  void _showMemberProfile(Map<String, dynamic> data) {
    final name = data['displayName'] ?? 'Member';
    final bio = data['bio'] ?? 'No bio yet.';
    final role = data['role'] ?? 'member';
    final photo = data['photoUrl'] ?? '';
    final email = data['email'] ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                border: Border.all(color: kGold, width: 2),
                boxShadow: [BoxShadow(
                  color: kGoldNeon.withOpacity(0.3),
                  blurRadius: 16, spreadRadius: 2)]),
              child: photo.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: photo, fit: BoxFit.cover))
                : Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: kWhite,
                      fontWeight: FontWeight.w800, fontSize: 32)))),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(role == 'pastor' ? '🎤 Pastor' : '🙏 Member',
                style: const TextStyle(color: kGoldDark,
                  fontWeight: FontWeight.w700, fontSize: 13))),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kMilk,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGold.withOpacity(0.15))),
              child: Text(bio, style: TextStyle(fontSize: 14,
                color: kText.withOpacity(0.8), height: 1.5))),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(email, style: TextStyle(fontSize: 12,
                color: kTextLight.withOpacity(0.5))),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  Map<String, dynamic>? _replyTo;

  void _onTypingChanged(String val) {
    final typing = val.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      FirebaseFirestore.instance
        .collection('typing')
        .doc(_user?.uid)
        .set({
          'name': _user?.displayName ?? 'Member',
          'isTyping': typing,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    }
  }

  Future<bool> _checkChatApproval() async {
    final doc = await FirebaseFirestore.instance
      .collection('users').doc(_user?.uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['chatApproved'] == true;
  }

  Future<void> _requestChatAccess() async {
    await FirebaseFirestore.instance
      .collection('chat_requests').doc(_user?.uid).set({
        'uid': _user?.uid,
        'name': _user?.displayName ?? 'Member',
        'photo': _user?.photoURL ?? '',
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Request sent! Wait for Pastor approval.'),
          backgroundColor: kGold,
          duration: Duration(seconds: 4)));
    }
  }

  Future<void> _sendMessage() async {
    final approved = await _checkChatApproval();
    if (!approved) {
      await _requestChatAccess();
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _isTyping = false;
    FirebaseFirestore.instance
      .collection('typing')
      .doc(_user?.uid)
      .set({'isTyping': false, 'name': _user?.displayName ?? 'Member',
            'updatedAt': FieldValue.serverTimestamp()});
    final reply = _replyTo;
    setState(() => _replyTo = null);
    await FirebaseService.sendMessage(
      text: text,
      senderName: _user?.displayName ?? 'Member',
      senderUid: _user?.uid ?? '',
      senderPhoto: _user?.photoURL ?? '',
      replyTo: reply,
    );
    // Notify all other users via stored FCM tokens
    try {
      final usersSnap = await FirebaseFirestore.instance
        .collection('users').get();
      for (final doc in usersSnap.docs) {
        if (doc.id == _user?.uid) continue;
        final token = doc.data()['fcmToken'] as String?;
        if (token != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'token': token,
            'title': _user?.displayName ?? 'Member',
            'body': text.length > 50 ? '\${text.substring(0, 50)}...' : text,
            'type': 'chat',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) { debugPrint('Notify error: \$e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Text('Community Chat',
                    style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w800, color: kText,
                      letterSpacing: -0.5)),
                  const Spacer(),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                      .collection('users').doc(_user?.uid).snapshots(),
                    builder: (ctx, snap) {
                      final data = snap.data?.data() as Map<String, dynamic>?;
                      final isPastor = data?['role'] == 'pastor';
                      if (!isPastor) return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGreen.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(Icons.circle, color: kGreen, size: 7),
                          const SizedBox(width: 4),
                          Text('Live', style: TextStyle(color: kGreen,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                        ]));
                      return GestureDetector(
                        onTap: _showChatRequests,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGold.withOpacity(0.3))),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                              .collection('chat_requests')
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                            builder: (ctx, reqSnap) {
                              final count = reqSnap.data?.docs.length ?? 0;
                              return Row(children: [
                                const Icon(Icons.manage_accounts,
                                  color: kGold, size: 14),
                                const SizedBox(width: 4),
                                Text('Manage${count > 0 ? " ($count)" : ""}',
                                  style: const TextStyle(color: kGoldDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                              ]);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getMessages(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(
                      color: kGold));
                  }
                  final messages = snap.data!.docs;
                  if (messages.isEmpty) {
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                        .collection('users').doc(_user?.uid).snapshots(),
                      builder: (ctx, userSnap) {
                        final data = userSnap.data?.data()
                          as Map<String, dynamic>?;
                        final approved = data?['chatApproved'] == true;
                        final role = data?['role'] ?? 'member';
                        if (!approved && role != 'pastor') {
                          return Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🔒',
                                style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text('Chat Access Required',
                                style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kText)),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40),
                                child: Text(
                                  'Tap the send button to request '
                                  'chat access from your Pastor.',
                                  style: TextStyle(fontSize: 13,
                                    color: kTextLight.withOpacity(0.6)),
                                  textAlign: TextAlign.center)),
                            ],
                          ));
                        }
                        return Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🕊️',
                              style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('Be the first to say hello!',
                              style: TextStyle(fontSize: 16,
                                color: kTextLight.withOpacity(0.6))),
                          ],
                        ));
                      },
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final data = messages[i].data()
                        as Map<String, dynamic>;
                      final isMe = data['senderUid'] == _user?.uid;
                      return _buildMessage(data, isMe, messages[i].id);
                    },
                  );
                },
              ),
            ),
            _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> data,
    bool isMe, String docId) {
    final type = data['type'] ?? 'text';
    final text = data['text'] ?? '';
    final name = data['senderName'] ?? 'Member';
    final photo = data['senderPhoto'] ?? '';
    final ts = data['sentAt'] as Timestamp?;
    final time = ts != null
      ? DateFormat('h:mm a').format(ts.toDate()) : '';

    if (type == 'scripture') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            kGold.withOpacity(0.12), kGold.withOpacity(0.06)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withOpacity(0.3)),
          boxShadow: [BoxShadow(
            color: kGoldNeon.withOpacity(0.15),
            blurRadius: 8, spreadRadius: 1)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('📖 ', style: TextStyle(fontSize: 14)),
              Text('Scripture shared by $name',
                style: TextStyle(fontSize: 11,
                  color: kGoldDark, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(fontSize: 14,
              color: kText.withOpacity(0.85), height: 1.5,
              fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(fontSize: 10,
              color: kTextLight.withOpacity(0.5))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
          ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kGoldLight, kGold])),
              child: photo.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: photo, fit: BoxFit.cover))
                : Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: kWhite,
                      fontSize: 12, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: kWhite,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20))),
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['👍','🙏','❤️','😂','🔥','😮'].map((emoji) =>
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  await FirebaseFirestore.instance
                                    .collection('messages').doc(docId)
                                    .update({'reactions.$uid': emoji});
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(emoji,
                                  style: const TextStyle(fontSize: 30))))).toList(),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.reply, color: kGold),
                          title: const Text('Reply'),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _replyTo = data);
                          }),
                        if (isMe) ListTile(
                          leading: const Icon(Icons.delete, color: kRed),
                          title: const Text('Delete'),
                          onTap: () {
                            FirebaseService.deleteMessage(docId);
                            Navigator.pop(context);
                          }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? kGold : kWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18)),
                  boxShadow: [BoxShadow(
                    color: isMe
                      ? kGoldNeon.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                    blurRadius: 6, offset: const Offset(0, 2))]),
                child: Column(
                  crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(name, style: TextStyle(fontSize: 11,
                        color: kGoldDark, fontWeight: FontWeight.w700)),
                    if (data['replyTo'] != null) Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isMe
                          ? kWhite.withOpacity(0.15)
                          : kGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(left: BorderSide(
                          color: isMe ? kWhite : kGold, width: 2))),
                      child: Text(
                        () {
                          final t = data['replyTo']['text']?.toString() ?? '';
                          return t.length > 40 ? t.substring(0, 40) + '...' : t;
                        }(),
                        style: TextStyle(fontSize: 11,
                          color: isMe
                            ? kWhite.withOpacity(0.8)
                            : kTextLight.withOpacity(0.7)))),
                    Text(text, style: TextStyle(
                      color: isMe ? kWhite : kText,
                      fontSize: 14, height: 1.4)),
                    const SizedBox(height: 2),
                    if ((data['reactions'] as Map?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: ((data['reactions'] as Map?) ?? {})
                            .values.toSet().map((emoji) {
                              final count = ((data['reactions'] as Map?) ?? {})
                                .values.where((e) => e == emoji).length;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: kGold.withOpacity(0.3))),
                                child: Text(
                                  count > 1 ? '$emoji $count' : emoji,
                                  style: const TextStyle(fontSize: 12)));
                            }).toList(),
                        )),
                    Text(time, style: TextStyle(fontSize: 10,
                      color: isMe
                        ? kWhite.withOpacity(0.6)
                        : kTextLight.withOpacity(0.4))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatRequests() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('Chat Access Requests',
                  style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w800, color: kText)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, color: kGold)),
              ])),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection('chat_requests')
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Text('No pending requests',
                        style: TextStyle(
                          color: kTextLight.withOpacity(0.5))));
                  }
                  return ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snap.data!.docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'pending';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kMilk,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: status == 'pending'
                              ? kGold.withOpacity(0.3)
                              : kGreen.withOpacity(0.3))),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kGold.withOpacity(0.15)),
                            child: Center(child: Text(
                              (data['name'] ?? 'M')[0].toUpperCase(),
                              style: const TextStyle(
                                color: kGold, fontWeight: FontWeight.w800,
                                fontSize: 16)))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['name'] ?? 'Member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: kText)),
                              Text(status == 'approved'
                                ? '✅ Approved'
                                : status == 'rejected'
                                  ? '❌ Rejected'
                                  : '⏳ Pending',
                                style: TextStyle(fontSize: 11,
                                  color: kTextLight.withOpacity(0.6))),
                            ],
                          )),
                          if (status == 'pending') Row(children: [
                            GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                  .collection('users').doc(doc.id)
                                  .update({'chatApproved': true});
                                await doc.reference.update({
                                  'status': 'approved'});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kGreen,
                                  borderRadius: BorderRadius.circular(10)),
                                child: const Text('Approve',
                                  style: TextStyle(color: kWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)))),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                  .collection('users').doc(doc.id)
                                  .update({'chatApproved': false});
                                await doc.reference.update({
                                  'status': 'rejected'});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kRed,
                                  borderRadius: BorderRadius.circular(10)),
                                child: const Text('Reject',
                                  style: TextStyle(color: kWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)))),
                          ]) else if (status == 'approved')
                            GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                  .collection('users').doc(doc.id)
                                  .update({'chatApproved': false});
                                await doc.reference.update({
                                  'status': 'rejected'});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: kRed.withOpacity(0.3))),
                                child: const Text('Remove',
                                  style: TextStyle(color: kRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)))),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('typing')
        .where('isTyping', isEqualTo: true)
        .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final typers = snap.data!.docs
          .where((d) => d.id != _user?.uid)
          .map((d) => (d.data() as Map)['name'] as String? ?? 'Someone')
          .toList();
        if (typers.isEmpty) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            '${typers.join(', ')} ${typers.length == 1 ? 'is' : 'are'} typing...',
            style: TextStyle(fontSize: 11,
              color: kTextLight.withOpacity(0.6),
              fontStyle: FontStyle.italic),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyTo != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: kGold.withOpacity(0.08),
          child: Row(children: [
            Container(
              width: 3, height: 36,
              color: kGold,
              margin: const EdgeInsets.only(right: 8)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to ${_replyTo!["senderName"] ?? "Member"}',
                  style: const TextStyle(
                    fontSize: 11, color: kGoldDark,
                    fontWeight: FontWeight.w700)),
                Text(
                  (_replyTo!["text"] ?? "").toString().length > 40
                    ? (_replyTo!["text"] ?? "").toString().substring(0, 40) + "..."
                    : (_replyTo!["text"] ?? "").toString(),
                  style: TextStyle(fontSize: 12,
                    color: kTextLight.withOpacity(0.7))),
              ])),
            GestureDetector(
              onTap: () => setState(() => _replyTo = null),
              child: const Icon(Icons.close, size: 18, color: kGoldDark)),
          ])),
        Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: kWhite,
        boxShadow: [BoxShadow(
          color: kGold.withOpacity(0.08),
          blurRadius: 12, offset: const Offset(0, -3))]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              style: const TextStyle(color: kText, fontSize: 15),
              onChanged: _onTypingChanged,
              decoration: InputDecoration(
                hintText: 'Say hi, share a scripture... 🙏',
                hintStyle: TextStyle(color: kTextLight.withOpacity(0.4),
                  fontSize: 14),
                filled: true, fillColor: kMilk,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10))),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kGold, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: kGoldNeon.withOpacity(0.3),
                  blurRadius: 8, spreadRadius: 1)]),
              child: const Icon(Icons.send, color: kWhite, size: 20))),
        ],
      ),
      ),
      ],
    );
  }
}



// ══════════════════════════════════════════════
//  BIBLE SCREEN
// ══════════════════════════════════════════════
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});
  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  String _selectedVersion = 'kjv';
  String _selectedBook = 'Genesis';
  int _selectedChapter = 1;
  bool _isLoading = false;
  String _passageText = '';
  String _errorText = '';
  List<Map<String, dynamic>> _verses = [];

  final List<Map<String,String>> _versions = [
    {'label': 'KJV', 'value': 'kjv'},
    {'label': 'Amplified', 'value': 'amp'},
    {'label': 'NIV', 'value': 'niv'},
    {'label': 'NLT', 'value': 'nlt'},
  ];

  final List<String> _books = [
    'Genesis','Exodus','Leviticus','Numbers','Deuteronomy',
    'Joshua','Judges','Ruth','1+Samuel','2+Samuel',
    '1+Kings','2+Kings','1+Chronicles','2+Chronicles','Ezra',
    'Nehemiah','Esther','Job','Psalms','Proverbs',
    'Ecclesiastes','Song+of+Solomon','Isaiah','Jeremiah','Lamentations',
    'Ezekiel','Daniel','Hosea','Joel','Amos',
    'Obadiah','Jonah','Micah','Nahum','Habakkuk',
    'Zephaniah','Haggai','Zechariah','Malachi',
    'Matthew','Mark','Luke','John','Acts',
    'Romans','1+Corinthians','2+Corinthians','Galatians','Ephesians',
    'Philippians','Colossians','1+Thessalonians','2+Thessalonians',
    '1+Timothy','2+Timothy','Titus','Philemon','Hebrews',
    'James','1+Peter','2+Peter','1+John','2+John',
    '3+John','Jude','Revelation'
  ];

  List<String> get _displayBooks => _books.map((b) => b.replaceAll('+', ' ')).toList();

  Widget _buildVerseDisplay(String text) {
    // Split by verse numbers pattern and display each verse
    final lines = text.split('\n');
    final widgets = <Widget>[];
    int verseNum = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      verseNum++;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text('$verseNum',
                style: TextStyle(
                  fontSize: 11,
                  color: kGold,
                  fontWeight: FontWeight.w800,
                  height: 1.8))),
            Expanded(
              child: Text(trimmed,
                style: const TextStyle(
                  fontSize: 17, height: 1.7, color: kText))),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets);
  }

  int _chapterCount(String book) {
    const counts = {
      'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36,
      'Deuteronomy': 34, 'Joshua': 24, 'Judges': 21, 'Ruth': 4,
      '1 Samuel': 31, '2 Samuel': 24, '1 Kings': 22, '2 Kings': 25,
      '1 Chronicles': 29, '2 Chronicles': 36, 'Ezra': 10, 'Nehemiah': 13,
      'Esther': 10, 'Job': 42, 'Psalms': 150, 'Proverbs': 31,
      'Ecclesiastes': 12, 'Song of Solomon': 8, 'Isaiah': 66,
      'Jeremiah': 52, 'Lamentations': 5, 'Ezekiel': 48, 'Daniel': 12,
      'Hosea': 14, 'Joel': 3, 'Amos': 9, 'Obadiah': 1, 'Jonah': 4,
      'Micah': 7, 'Nahum': 3, 'Habakkuk': 3, 'Zephaniah': 3,
      'Haggai': 2, 'Zechariah': 14, 'Malachi': 4, 'Matthew': 28,
      'Mark': 16, 'Luke': 24, 'John': 21, 'Acts': 28, 'Romans': 16,
      '1 Corinthians': 16, '2 Corinthians': 13, 'Galatians': 6,
      'Ephesians': 6, 'Philippians': 4, 'Colossians': 4,
      '1 Thessalonians': 5, '2 Thessalonians': 3, '1 Timothy': 6,
      '2 Timothy': 4, 'Titus': 3, 'Philemon': 1, 'Hebrews': 13,
      'James': 5, '1 Peter': 5, '2 Peter': 3, '1 John': 5,
      '2 John': 1, '3 John': 1, 'Jude': 1, 'Revelation': 22,
    };
    return counts[book] ?? 50;
  }

  Future<void> _loadPassage() async {
    setState(() { _isLoading = true; _passageText = ''; _errorText = ''; _verses = []; });
    
    // --- OFFLINE KJV ENGINE ---
    if (_selectedVersion == 'kjv') {
      try {
        final jsonString = await DefaultAssetBundle.of(context).loadString('assets/kjv.json');
        final List<dynamic> bibleData = json.decode(jsonString);
        final searchBook = _selectedBook.replaceAll('+', ' ');
        
        final bookData = bibleData.firstWhere(
          (b) => b['name'].toString().toLowerCase() == searchBook.toLowerCase(),
          orElse: () => null
        );
        
        if (bookData != null) {
          final chapters = bookData['chapters'] as List<dynamic>;
          if (_selectedChapter > 0 && _selectedChapter <= chapters.length) {
            final verses = chapters[_selectedChapter - 1] as List<dynamic>;
            setState(() {
              _verses = verses.asMap().entries.map((e) => {
                'verse': e.key + 1,
                'text': e.value.toString().trim(),
              }).toList();
              _passageText = 'loaded';
              _errorText = '';
            });
          } else {
            setState(() => _errorText = 'Chapter not found.');
          }
        } else {
          setState(() => _errorText = 'Book not found.');
        }
      } catch (e) {
        setState(() => _errorText = 'Error loading offline Bible.');
      }
      setState(() => _isLoading = false);
      return;
    }

    // --- ONLINE API ENGINE (For AMP, NIV, NLT) ---
    try {
      final book = _selectedBook.replaceAll(' ', '+');
      final url = 'https://bible-api.com/$book+$_selectedChapter?translation=$_selectedVersion';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final verseList = data['verses'] as List<dynamic>? ?? [];
        if (verseList.isNotEmpty) {
          setState(() {
            _verses = verseList.map((v) => {
              'verse': v['verse'] as int,
              'text': (v['text'] as String).trim(),
            }).toList();
            _passageText = 'loaded';
          });
        } else {
          setState(() => _passageText = data['text'] ?? 'Passage not found');
        }
      } else {
        setState(() => _errorText = 'Could not load. Check connection.');
      }
    } catch (e) {
      setState(() => _errorText = 'No internet connection. Check your network.');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(children: [
                const Text('Holy Bible',
                  style: TextStyle(fontSize: 26,
                    fontWeight: FontWeight.w800, color: kText)),
                const Spacer(),
                const Text('📖', style: TextStyle(fontSize: 24)),
              ])),
            // Version selector
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _versions.length,
                itemBuilder: (_, i) {
                  final v = _versions[i];
                  final selected = v['value'] == _selectedVersion;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedVersion = v['value']!),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? kGold : kWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? kGold : kGold.withOpacity(0.3))),
                      child: Text(v['label']!,
                        style: TextStyle(
                          color: selected ? kWhite : kTextLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))));
                },
              ),
            ),
            const SizedBox(height: 10),
            // Book + Chapter + Go
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.3))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBook,
                        isExpanded: true,
                        style: const TextStyle(
                          color: kText, fontSize: 13,
                          fontWeight: FontWeight.w600),
                        onChanged: (v) => setState(() {
                          _selectedBook = v!;
                          _selectedChapter = 1;
                        }),
                        items: _displayBooks.map((b) =>
                          DropdownMenuItem(value: b, child: Text(b))
                        ).toList())))),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold.withOpacity(0.3))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedChapter,
                        isExpanded: true,
                        style: const TextStyle(
                          color: kText, fontSize: 13,
                          fontWeight: FontWeight.w600),
                        onChanged: (v) => setState(() => _selectedChapter = v!),
                        items: List.generate(150, (i) => i + 1).map((c) =>
                          DropdownMenuItem(value: c, child: Text('Ch $c'))
                        ).toList())))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadPassage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                  child: const Text('Go',
                    style: TextStyle(fontWeight: FontWeight.w800))),
              ])),
            const SizedBox(height: 8),
            // Passage
            Expanded(child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kGold))
              : _errorText.isNotEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: kGold, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorText,
                        style: TextStyle(fontSize: 14,
                          color: kTextLight.withOpacity(0.7)),
                        textAlign: TextAlign.center),
                    ]))
                : (_verses.isEmpty && _passageText.isEmpty)
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text('Select a book and chapter',
                          style: TextStyle(fontSize: 16,
                            color: kTextLight.withOpacity(0.6))),
                        const SizedBox(height: 4),
                        Text('then tap Go',
                          style: TextStyle(fontSize: 13,
                            color: kTextLight.withOpacity(0.4))),
                      ]))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '$_selectedBook $_selectedChapter - ${_versions.firstWhere((v) => v["value"] == _selectedVersion)["label"]}',
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: kGoldDark))),
                          const SizedBox(height: 16),
                          if (_verses.isNotEmpty)
                            ..._verses.map((v) {
                            final verseNum = v['verse'] as int;
                            final verseText = v['text'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      verseNum.toString(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: kGold,
                                        fontWeight: FontWeight.w800,
                                        height: 2.2))),
                                  Expanded(
                                    child: Text(
                                      verseText,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.7,
                                        color: kText))),
                                ]));
                          })
                          else
                            Text(_passageText,
                              style: const TextStyle(
                                fontSize: 17, height: 2.0, color: kText)),
                        ],
                      ))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  HYMN SCREEN
// ══════════════════════════════════════════════
class HymnScreen extends StatefulWidget {
  const HymnScreen({super.key});
  @override
  State<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends State<HymnScreen> {
  List<dynamic> _hymns = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHymns();
  }

  Future<void> _loadHymns() async {
    try {
      final data = await rootBundle.loadString('assets/hymns.json');
      final list = json.decode(data) as List;
      setState(() { _hymns = list; _filtered = list; _loaded = true; });
    } catch (e) {
      setState(() => _loaded = true);
    }
  }

  void _search(String query) {
    setState(() {
      _filtered = query.isEmpty
        ? _hymns
        : _hymns.where((h) =>
            h['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
            h['lyrics'].toString().toLowerCase().contains(query.toLowerCase())
          ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const Text('Hymn Book',
                  style: TextStyle(fontSize: 26,
                    fontWeight: FontWeight.w800, color: kText)),
                const Spacer(),
                const Text('🎵', style: TextStyle(fontSize: 24)),
              ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search by title or lyric...',
                  prefixIcon: const Icon(Icons.search, color: kGold),
                  filled: true, fillColor: kWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12)))),
            const SizedBox(height: 8),
            if (!_loaded)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: kGold)))
            else if (_filtered.isEmpty)
              Expanded(child: Center(
                child: Text('No hymns found',
                  style: TextStyle(
                    color: kTextLight.withOpacity(0.5)))))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final hymn = _filtered[i];
                    return GestureDetector(
                      onTap: () => _showHymn(hymn),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kGold.withOpacity(0.12)),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6, offset: const Offset(0, 2))]),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(19)),
                            child: Center(child: Text(
                              '#${hymn["number"]}',
                              style: const TextStyle(
                                fontSize: 11, color: kGoldDark,
                                fontWeight: FontWeight.w800)))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(hymn['title'],
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: kText))),
                          Icon(Icons.chevron_right,
                            color: kGold.withOpacity(0.4)),
                        ])));
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showHymn(dynamic hymn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Text('#${hymn["number"]}',
                  style: const TextStyle(
                    color: kGoldDark, fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: Text(hymn['title'],
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: kText))),
              const Text('🎵'),
            ])),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Text(hymn['lyrics'],
                style: const TextStyle(
                  fontSize: 17, height: 2.2, color: kText)))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ATTENDANCE SCREEN
// ══════════════════════════════════════════════
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const Text('Attendance',
                  style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w800, color: kText)),
                const Spacer(),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                    .collection('users').doc(_user?.uid).snapshots(),
                  builder: (ctx, snap) {
                    final data = snap.data?.data()
                      as Map<String, dynamic>?;
                    if (data?['role'] != 'pastor') return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                      child: const Text('Pastor View',
                        style: TextStyle(fontSize: 11,
                          color: kGoldDark,
                          fontWeight: FontWeight.w600)));
                  },
                ),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .orderBy('joinedAt', descending: true)
                  .limit(50)
                  .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📊',
                          style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No attendance records yet.',
                          style: TextStyle(fontSize: 15,
                            color: kTextLight.withOpacity(0.6))),
                        const SizedBox(height: 4),
                        Text('Records appear after classes.',
                          style: TextStyle(fontSize: 13,
                            color: kTextLight.withOpacity(0.4))),
                      ],
                    ));
                  }
                  final Map<String, List<Map<String, dynamic>>> grouped = {};
                  for (final doc in snap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final room = data['roomCode'] ?? 'Unknown';
                    grouped.putIfAbsent(room, () => []).add(data);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: grouped.keys.length,
                    itemBuilder: (_, i) {
                      final roomCode = grouped.keys.elementAt(i);
                      final attendees = grouped[roomCode]!;
                      final first = attendees.first;
                      final ts = first['joinedAt'] as Timestamp?;
                      final date = ts != null
                        ? DateFormat('EEE, MMM d · h:mm a').format(ts.toDate())
                        : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kGold.withOpacity(0.12)),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2))]),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: kGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(22)),
                                child: const Icon(Icons.groups,
                                  color: kGold, size: 22)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(first['topic'] ?? 'Lifestones Class',
                                    style: const TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kText)),
                                  Text(date,
                                    style: TextStyle(fontSize: 11,
                                      color: kTextLight.withOpacity(0.6))),
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  '${attendees.length} joined',
                                  style: const TextStyle(fontSize: 11,
                                    color: kGoldDark,
                                    fontWeight: FontWeight.w700))),
                            ]),
                          ),
                          const Divider(height: 1,
                            color: Color(0xFFEEE8D5)),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 6, runSpacing: 6,
                              children: attendees.map((a) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kMilk,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: kGold.withOpacity(0.2))),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: kGold.withOpacity(0.2)),
                                        child: Center(child: Text(
                                          (a['name'] ?? 'M')[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: kGoldDark,
                                            fontWeight: FontWeight.w700)))),
                                      const SizedBox(width: 4),
                                      Text(
                                        (a['name'] ?? 'Member').split(' ').first,
                                        style: const TextStyle(
                                          fontSize: 11, color: kText)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  PRAYER REQUESTS SCREEN
// ══════════════════════════════════════════════
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final _prayerCtrl = TextEditingController();

  Future<void> _submitPrayer() async {
    final text = _prayerCtrl.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance.collection('prayer_requests').add({
      'text': text,
      'uid': _user?.uid,
      'name': _user?.displayName ?? 'Member',
      'photo': _user?.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'answered': false,
      'response': '',
    });
    _prayerCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🙏 Prayer request submitted!'),
          backgroundColor: kGreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const Text('Prayer Requests',
                  style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w800, color: kText)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Text('🙏 Pray Together',
                    style: TextStyle(fontSize: 11,
                      color: kGoldDark, fontWeight: FontWeight.w600))),
              ])),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection('prayer_requests')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🙏', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No prayer requests yet.',
                          style: TextStyle(fontSize: 15,
                            color: kTextLight.withOpacity(0.6))),
                        const SizedBox(height: 4),
                        Text('Be the first to share a need.',
                          style: TextStyle(fontSize: 13,
                            color: kTextLight.withOpacity(0.4))),
                      ],
                    ));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snap.data!.docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final answered = data['answered'] == true;
                      final response = data['response'] ?? '';
                      final ts = data['createdAt'] as Timestamp?;
                      final date = ts != null
                        ? DateFormat('MMM d · h:mm a').format(ts.toDate())
                        : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: answered
                            ? kGreen.withOpacity(0.05) : kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: answered
                            ? kGreen.withOpacity(0.3)
                            : kGold.withOpacity(0.12)),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kGold.withOpacity(0.15)),
                                child: Center(child: Text(
                                  (data['name'] ?? 'M')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: kGold,
                                    fontWeight: FontWeight.w800)))),
                              const SizedBox(width: 8),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? 'Member',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kText)),
                                  Text(date, style: TextStyle(
                                    fontSize: 10,
                                    color: kTextLight.withOpacity(0.5))),
                                ])),
                              if (answered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                  child: const Text('✅ Answered',
                                    style: TextStyle(fontSize: 10,
                                      color: kGreen,
                                      fontWeight: FontWeight.w600))),
                            ]),
                            const SizedBox(height: 10),
                            Text(data['text'] ?? '',
                              style: TextStyle(fontSize: 14,
                                color: kText.withOpacity(0.85),
                                height: 1.5)),
                            if (response.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: kGold.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: kGold.withOpacity(0.2))),
                                child: Row(children: [
                                  const Text('🎤 ',
                                    style: TextStyle(fontSize: 12)),
                                  Expanded(child: Text(response,
                                    style: TextStyle(fontSize: 12,
                                      color: kGoldDark,
                                      fontStyle: FontStyle.italic))),
                                ])),
                            ],
                            // Pastor response & mark answered
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(_user?.uid).snapshots(),
                              builder: (ctx, userSnap) {
                                final ud = userSnap.data?.data()
                                  as Map<String, dynamic>?;
                                if (ud?['role'] != 'pastor') {
                                  return const SizedBox();
                                }
                                return Column(children: [
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _showPastorResponse(
                                          doc.id, data),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: kGold.withOpacity(0.1),
                                            borderRadius:
                                              BorderRadius.circular(10)),
                                          child: const Text('💬 Respond',
                                            style: TextStyle(fontSize: 12,
                                              color: kGoldDark,
                                              fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center)))),
                                    const SizedBox(width: 8),
                                    if (!answered)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            await doc.reference.update({
                                              'answered': true});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: kGreen.withOpacity(0.1),
                                              borderRadius:
                                                BorderRadius.circular(10)),
                                            child: const Text('✅ Mark Answered',
                                              style: TextStyle(fontSize: 12,
                                                color: kGreen,
                                                fontWeight: FontWeight.w600),
                                              textAlign: TextAlign.center)))),
                                  ]),
                                ]);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: kWhite,
                boxShadow: [BoxShadow(
                  color: kGold.withOpacity(0.08),
                  blurRadius: 12, offset: const Offset(0, -3))]),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _prayerCtrl,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Share a prayer need... 🙏',
                      hintStyle: TextStyle(
                        color: kTextLight.withOpacity(0.4)),
                      filled: true, fillColor: kMilk,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10)))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitPrayer,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: kGold, shape: BoxShape.circle),
                    child: const Icon(Icons.send,
                      color: kWhite, size: 20))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showPastorResponse(String docId, Map<String, dynamic> data) {
    final ctrl = TextEditingController(text: data['response'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pastor Response',
              style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your response...',
                filled: true, fillColor: kMilk,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGold.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kGold, width: 2)))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                    .collection('prayer_requests')
                    .doc(docId)
                    .update({'response': ctrl.text.trim()});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: const Text('Send Response',
                  style: TextStyle(fontWeight: FontWeight.w700)))),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _editingBio = false;
  bool _editingName = false;
  final _bioCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    await FirebaseService.uploadProfilePhoto(File(file.path));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilkDeep,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseService.getUserStream(_user?.uid ?? ''),
          builder: (ctx, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final name = data?['displayName']
              ?? _user?.displayName ?? 'Member';
            final bio = data?['bio'] ?? '';
            final photo = data?['photoUrl'] ?? _user?.photoURL ?? '';
            final role = data?['role'] ?? 'member';
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [kGoldLight, kGold]),
                            border: Border.all(color: kGold, width: 3),
                            boxShadow: [BoxShadow(
                              color: kGoldNeon.withOpacity(0.4),
                              blurRadius: 20, spreadRadius: 3)]),
                          child: photo.isNotEmpty
                            ? ClipOval(child: CachedNetworkImage(
                                imageUrl: photo, fit: BoxFit.cover))
                            : Center(child: Text(name[0].toUpperCase(),
                                style: const TextStyle(color: kWhite,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800)))),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 30, height: 30,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: kGold),
                            child: const Icon(Icons.camera_alt,
                              color: kWhite, size: 16))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _editingName
                    ? Row(children: [
                        Expanded(child: TextField(
                          controller: _nameCtrl..text = name,
                          style: const TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w800, color: kText),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true, fillColor: kWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: kGold)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: kGold, width: 2))),
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await FirebaseService.updateDisplayName(
                              _nameCtrl.text.trim());
                            setState(() => _editingName = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: kGold),
                            child: const Icon(Icons.check,
                              color: kWhite, size: 16))),
                      ])
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800, color: kText)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _editingName = true),
                            child: const Icon(Icons.edit,
                              color: kGold, size: 18)),
                        ],
                      ),
                  const SizedBox(height: 4),
                  Text(_user?.email ?? '',
                    style: TextStyle(fontSize: 13,
                      color: kTextLight.withOpacity(0.6))),
                  const SizedBox(height: 4),
                  if (data?['phone'] != null && data!['phone'].isNotEmpty)
                    Text('📞 ${data!['phone']}',
                      style: TextStyle(fontSize: 13,
                        color: kTextLight.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      role == 'pastor' ? '🎤 Pastor' : '⛪ Member',
                      style: const TextStyle(color: kGoldDark,
                        fontWeight: FontWeight.w700, fontSize: 13))),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withOpacity(0.15)),
                      boxShadow: [BoxShadow(
                        color: kGoldNeon.withOpacity(0.08),
                        blurRadius: 12, offset: const Offset(0, 3))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('About Me',
                            style: TextStyle(fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              color: kGoldDark)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(
                              () => _editingBio = !_editingBio),
                            child: Icon(
                              _editingBio ? Icons.close : Icons.edit,
                              color: kGold, size: 18)),
                        ]),
                        const SizedBox(height: 10),
                        _editingBio
                          ? TextField(
                              controller: _bioCtrl..text = bio,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 14, color: kText),
                              decoration: InputDecoration(
                                hintText: 'Tell the family about yourself...',
                                filled: true, fillColor: kMilk,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: kGold)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: kGold, width: 2))))
                          : Text(
                              bio.isEmpty
                                ? 'Tap ✏️ to add your bio...' : bio,
                              style: TextStyle(fontSize: 14,
                                color: bio.isEmpty
                                  ? kTextLight.withOpacity(0.4)
                                  : kText.withOpacity(0.8),
                                height: 1.5)),
                        const SizedBox(height: 10),
                        TextField(
                          onChanged: (v) {},
                          decoration: InputDecoration(
                            hintText: 'Phone number (optional)',
                            prefixText: '+',
                            prefixIcon: const Icon(
                              Icons.phone, color: kGold, size: 18),
                            filled: true, fillColor: kMilk,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: kGold.withOpacity(0.3))),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: kGold.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: kGold, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                          onSubmitted: (v) async {
                            if (v.trim().isNotEmpty) {
                              await FirebaseService.updatePhone(v.trim());
                            }
                          },
                          controller: TextEditingController(
                            text: data?['phone'] ?? ''),
                        ),
                        if (_editingBio) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await FirebaseService.updateBio(
                                  _bioCtrl.text.trim());
                                setState(() => _editingBio = false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGold,
                                foregroundColor: kWhite,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                                elevation: 0),
                              child: const Text('Save Bio',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Attendance tile for pastor
                  if (role == 'pastor')
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const AttendanceScreen())),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kGold.withOpacity(0.12))),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.bar_chart,
                              color: kGold, size: 18)),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attendance Records',
                                style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kText)),
                              Text('See who joined each class',
                                style: TextStyle(fontSize: 12,
                                  color: kTextLight)),
                            ],
                          )),
                          Icon(Icons.chevron_right,
                            color: kGold.withOpacity(0.4), size: 20),
                        ]),
                      ),
                    ),
                  if (role == 'pastor')
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                        .collection('chat_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                      builder: (ctx, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return GestureDetector(
                          onTap: () {
                            final shell = context
                              .findAncestorStateOfType<_MainShellState>();
                            shell?.setState(() => shell._tab = 3);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: count > 0
                                ? kGold.withOpacity(0.08) : kWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: count > 0
                                ? kGold : kGold.withOpacity(0.12))),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: count > 0
                                    ? kGold : kGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.manage_accounts,
                                  color: count > 0 ? kWhite : kGold,
                                  size: 18)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Chat Access Requests',
                                    style: const TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kText)),
                                  Text(count > 0
                                    ? '$count awaiting approval'
                                    : 'No pending requests',
                                    style: TextStyle(fontSize: 12,
                                      color: count > 0
                                        ? kGoldDark
                                        : kTextLight.withOpacity(0.6))),
                                ],
                              )),
                              if (count > 0) Container(
                                width: 28, height: 28,
                                decoration: const BoxDecoration(
                                  color: kRed,
                                  shape: BoxShape.circle),
                                child: Center(child: Text('\$count',
                                  style: const TextStyle(
                                    color: kWhite, fontSize: 12,
                                    fontWeight: FontWeight.w800)))),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                color: kGold.withOpacity(0.4), size: 20),
                            ]),
                          ),
                        );
                      },
                    ),
                  _buildTile(Icons.notifications_outlined,
                    'Class Reminders', 'Fri, Sat, Sun · 30 min before'),
                  GestureDetector(
                    onTap: () {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        backgroundColor: kMilkDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Welcome to the Sanctuary', style: TextStyle(fontWeight: FontWeight.w800, color: kText)),
                        content: const Text(
                          'This app is dedicated to the Lifestones family. '
                          'Grow in Faith, Community and Discipleship. '
                          'When LIVE, tap to listen in and prepare your heart.',
                          style: TextStyle(height: 1.6, color: kText)),
                        actions: [TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Amen 🙏',
                            style: TextStyle(
                              color: kGold,
                              fontWeight: FontWeight.w700)))],
                      ));
                    },
                    child: _buildTile(Icons.info_outline,
                      'About Lifestones', 'Tap to read our guidelines')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        // Wipe role so they must re-select on next login
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance
                            .collection('users').doc(uid).update({
                              'role': FieldValue.delete(),
                              'roleSetAt': FieldValue.delete(),
                              'chatApproved': false,
                            });
                        }
                        await signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                            (route) => false);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kRed,
                        side: const BorderSide(color: kRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                      child: const Text('Sign Out',
                        style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.12))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kGold, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: kText)),
              Text(subtitle, style: TextStyle(fontSize: 12,
                color: kTextLight.withOpacity(0.6))),
            ],
          )),
          Icon(Icons.chevron_right,
            color: kGold.withOpacity(0.4), size: 20),
        ],
      ),
    );
  }
}
