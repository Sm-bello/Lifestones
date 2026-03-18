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
import 'package:flutter_sound/flutter_sound.dart';
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
          if (snapshot.hasData) return const MainShell();
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
    final user = await signInWithGoogle();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _error = 'Sign-in cancelled. Please try again.';
        _loading = false;
      });
    }
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: kWhite,
                                        borderRadius: BorderRadius.circular(4)),
                                      child: const Center(child: Text('G',
                                        style: TextStyle(color: kGold,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14)))),
                                    const SizedBox(width: 12),
                                    const Text('Continue with Google',
                                      style: TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMilk,
      body: _screens[_tab],
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
              if (!snap.hasData || snap.data!.docs.isEmpty) {
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

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentUrl = '';

  Future<void> _playRecording(String url, BuildContext ctx) async {
    if (url.isEmpty) return;
    try {
      if (_isPlaying && _currentUrl == url) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
        return;
      }
      setState(() { _isPlaying = true; _currentUrl = url; });
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      debugPrint('Play error: \$e');
      setState(() => _isPlaying = false);
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
              .limit(10)
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
              return Column(
                children: snap.data!.docs.map((doc) {
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
      await FirebaseFirestore.instance.collection('recordings').add({
        'roomCode': roomCode,
        'downloadUrl': downloadUrl,
        'title': 'Lifestones Class - \${DateTime.now().toString().substring(0, 10)}',
        'duration': '',
        'uploadedBy': _user?.displayName ?? 'Pastor',
        'uploadedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
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
              const SizedBox(height: 24),
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
                            onPressed: () {
                              if (pinCtrl.text == '7749') {
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
                      await _startMeeting(selectedRole);
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

  Future<void> _startMeeting(String role) async {
    final roomCode = await FirebaseService.createMeeting(
      topic: 'Lifestones Class',
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
    await FirebaseFirestore.instance.collection('recordings').add({
      'roomCode': roomCode,
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': user?.displayName ?? 'Member',
      'uid': user?.uid,
      'title': 'Lifestones Class - $roomCode',
    });
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
    Share.share(
      '⛪ Join the Lifestones class!\n\nRoom: $roomCode\n\n'
      'Download Lifestones app to join.\n\nGod bless you 🙏');
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

  Widget _buildLiveCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kGold, kGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: kGoldNeon.withOpacity(0.4),
          blurRadius: 24, spreadRadius: 2)]),
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
                child: const Text('End',
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptySanctuary() {
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
            color: kGold.withOpacity(0.1)),
          child: const Icon(Icons.cell_tower, color: kGold, size: 36)),
        const SizedBox(height: 16),
        const Text('The Sanctuary',
          style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: kText)),
        const SizedBox(height: 8),
        Text('No class is live right now.\nStart one or wait for your Pastor.',
          style: TextStyle(fontSize: 13, height: 1.5,
            color: kTextLight.withOpacity(0.7)),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: kMilk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGold.withOpacity(0.2))),
          child: Text('⬇️ Pull down to refresh',
            style: TextStyle(fontSize: 11,
              color: kTextLight.withOpacity(0.6)))),
      ]),
    );
  }

  Widget _buildStartButton() {
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
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
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
                      return _buildMemberCard(data);
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

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _isTyping = false;
    FirebaseFirestore.instance
      .collection('typing')
      .doc(_user?.uid)
      .set({'isTyping': false, 'name': _user?.displayName ?? 'Member',
            'updatedAt': FieldValue.serverTimestamp()});
    await FirebaseService.sendMessage(
      text: text,
      senderName: _user?.displayName ?? 'Member',
      senderUid: _user?.uid ?? '',
      senderPhoto: _user?.photoURL ?? '',
    );
    // Only notify OTHERS - not the sender
    // FCM handles this via Cloud Functions trigger on Firestore
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
                  Container(
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
                    ])),
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
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🕊️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Be the first to say hello!',
                          style: TextStyle(fontSize: 16,
                            color: kTextLight.withOpacity(0.6))),
                      ],
                    ));
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
                if (isMe) {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => ListTile(
                      leading: const Icon(Icons.delete, color: kRed),
                      title: const Text('Delete message'),
                      onTap: () {
                        FirebaseService.deleteMessage(docId);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }
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
                    Text(text, style: TextStyle(
                      color: isMe ? kWhite : kText,
                      fontSize: 14, height: 1.4)),
                    const SizedBox(height: 2),
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
    return Container(
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
                  _buildTile(Icons.notifications_outlined,
                    'Class Reminders', 'Fri, Sat, Sun · 30 min before'),
                  _buildTile(Icons.info_outline,
                    'About Lifestones',
                    'Version 1.0.0 · Built with ❤️ for the family'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async => await signOut(),
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
