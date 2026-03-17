  import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notification_service.dart';

const kMilk      = Color(0xFFFDF6E3);
const kMilkDark  = Color(0xFFF0E6CC);
const kGold      = Color(0xFFC9973A);
const kGoldLight = Color(0xFFE2B96F);
const kGoldDark  = Color(0xFFA07828);
const kText      = Color(0xFF2C1A00);
const kTextLight = Color(0xFF8B6914);
const kWhite     = Color(0xFFFFFFFF);
const kRed       = Color(0xFFD32F2F);
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
  await NotificationService.init();
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
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800,
                color: kGold, letterSpacing: -1,
              ),
            ),
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(0.5),
                          blurRadius: 32, spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('✝',
                        style: TextStyle(fontSize: 48, color: kWhite)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Lifestones',
                    style: TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withOpacity(0.2)),
                    ),
                    child: Text(
                      '"Where iron sharpens iron" — Prov 27:17',
                      style: TextStyle(
                        fontSize: 12,
                        color: kGoldDark.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: kGold.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(0.12),
                          blurRadius: 32, spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text('Welcome to the Family',
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: kText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join thousands growing in faith together.\nSign in to access your discipleship classes.',
                          style: TextStyle(
                            fontSize: 14, height: 1.5,
                            color: kTextLight.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        if (_error.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_error,
                              style: const TextStyle(
                                color: kRed, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                              shadowColor: kGold.withOpacity(0.5),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 22, width: 22,
                                    child: CircularProgressIndicator(
                                      color: kWhite, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          color: kWhite,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Center(
                                          child: Text('G',
                                            style: TextStyle(
                                              color: kGold,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            )),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Continue with Google',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        )),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'By signing in, you join the Lifestones family ✝',
                          style: TextStyle(
                            fontSize: 11,
                            color: kTextLight.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
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
    DashboardScreen(),
    ClassesScreen(),
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
          boxShadow: [
            BoxShadow(
              color: kGold.withOpacity(0.1),
              blurRadius: 20, offset: const Offset(0, -4),
            ),
          ],
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Classes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late AnimationController _pulseCtrl;

  bool get _isClassTime {
    final now = DateTime.now();
    final isDay = now.weekday == DateTime.friday ||
        now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    final isHour = now.hour >= 18 && now.hour < 20;
    return isDay && isHour;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _todayClass {
    final day = DateTime.now().weekday;
    if (day == DateTime.friday) return 'Friday Discipleship Class';
    if (day == DateTime.saturday) return 'Saturday Bible Study';
    if (day == DateTime.sunday) return 'Sunday Service';
    return '';
  }

  String get _nextClass {
    final day = DateTime.now().weekday;
    if (day < DateTime.friday) return 'Friday · 6:00 PM';
    if (day == DateTime.friday) return 'Saturday · 6:00 PM';
    if (day == DateTime.saturday) return 'Sunday · 6:00 PM';
    return 'Friday · 6:00 PM';
  }

  final _scriptures = [
    '"I can do all things through Christ who strengthens me." — Phil 4:13',
    '"The Lord is my shepherd, I shall not want." — Psalm 23:1',
    '"Trust in the Lord with all your heart." — Prov 3:5',
    '"For I know the plans I have for you, declares the Lord." — Jer 29:11',
    '"Be still and know that I am God." — Psalm 46:10',
  ];

  String get _scripture {
    final day = DateTime.now().day;
    return _scriptures[day % _scriptures.length];
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 24),
                      _buildWelcomeBanner(),
                      const SizedBox(height: 20),
                      if (_isClassTime) ...[
                        _buildLiveBanner(),
                        const SizedBox(height: 20),
                      ],
                      _buildNextClass(),
                      const SizedBox(height: 20),
                      _buildScripture(),
                      const SizedBox(height: 24),
                      const Text('Messages & Resources',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: kText, letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 5,
                    itemBuilder: (_, i) => _buildSermonCard(i),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
            gradient: LinearGradient(colors: [kGoldLight, kGold]),
          ),
          child: const Center(
            child: Text('✝',
              style: TextStyle(fontSize: 20, color: kWhite)),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Lifestones',
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: kGold,
          ),
        ),
        const Spacer(),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: kWhite,
            border: Border.all(color: kGold.withOpacity(0.2)),
          ),
          child: const Icon(Icons.notifications_outlined,
            color: kGold, size: 20),
        ),
        const SizedBox(width: 8),
        Container(
          width: 38, height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle, color: kGold,
          ),
          child: Center(
            child: Text(
              (_user?.displayName ?? 'M')[0].toUpperCase(),
              style: const TextStyle(
                color: kWhite, fontWeight: FontWeight.w800, fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeBanner() {
    final firstName = _user?.displayName?.split(' ').first ?? 'Friend';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_greeting, $firstName 🙏',
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: kText, letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text('Welcome back to the family',
          style: TextStyle(
            fontSize: 14, color: kTextLight.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBanner() {
    return GestureDetector(
      onTap: () => _joinClass('LIVE'),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kGold, kGoldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(
                    0.3 + _pulseCtrl.value * 0.3),
                  blurRadius: 20 + _pulseCtrl.value * 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: kWhite, size: 8),
                  SizedBox(width: 4),
                  Text('LIVE',
                    style: TextStyle(
                      color: kWhite, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 1,
                    )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_todayClass,
                    style: const TextStyle(
                      color: kWhite, fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Text('Class is live now — tap to join',
                    style: TextStyle(
                      color: kWhite, fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Join',
                style: TextStyle(
                  color: kGold, fontWeight: FontWeight.w800,
                  fontSize: 13,
                )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextClass() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: kGold.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today,
                  color: kGold, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next Class',
                    style: TextStyle(
                      color: kTextLight, fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 1,
                    ),
                  ),
                  Text(_nextClass,
                    style: const TextStyle(
                      color: kText, fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showJoinDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: kGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Join',
                    style: TextStyle(
                      color: kWhite, fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kMilk,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: kGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Classes hold every Friday, Saturday & Sunday · 6:00 PM',
                    style: TextStyle(
                      fontSize: 12,
                      color: kTextLight.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScripture() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kGold.withOpacity(0.12), kGold.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('📖', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scripture of the Day',
                  style: TextStyle(
                    fontSize: 10, letterSpacing: 1.5,
                    fontWeight: FontWeight.w700, color: kGoldDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_scripture,
                  style: TextStyle(
                    fontSize: 13, height: 1.5,
                    color: kText.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final _sermonTitles = [
    'Walking in Purpose',
    'The Power of Prayer',
    'Faith Over Fear',
    'Grace & Truth',
    'Living the Word',
  ];

  final _sermonSubtitles = [
    'Pastor Emmanuel · 3 days ago',
    'Pastor Emmanuel · 1 week ago',
    'Guest Speaker · 2 weeks ago',
    'Pastor Emmanuel · 3 weeks ago',
    'Youth Service · 1 month ago',
  ];

  final _sermonEmojis = ['🔥', '🙏', '✝️', '📖', '⚡'];

  Widget _buildSermonCard(int i) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_sermonTitles[i]} — Coming soon!'),
            backgroundColor: kGold,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: kGold.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kGold.withOpacity(0.15 + i * 0.05),
                    kGoldLight.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(_sermonEmojis[i],
                  style: const TextStyle(fontSize: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sermonTitles[i],
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(_sermonSubtitles[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: kTextLight.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    bool isHost = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Join a Class',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: kText,
                )),
              const SizedBox(height: 6),
              Text('Enter the room code your Pastor shared',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextLight.withOpacity(0.7),
                )),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 22, letterSpacing: 6,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                onChanged: (v) => ctrl.value = ctrl.value.copyWith(
                  text: v.toUpperCase(),
                  selection: TextSelection.collapsed(offset: v.length),
                ),
                decoration: InputDecoration(
                  hintText: 'FRIDAY',
                  hintStyle: TextStyle(
                    color: kTextLight.withOpacity(0.3),
                    letterSpacing: 4, fontSize: 18,
                  ),
                  filled: true,
                  fillColor: kMilk,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kGold.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kGold.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kGold, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _modalRoleBtn(
                  setModal, '🎤', 'Pastor',
                  isHost, () => setModal(() => isHost = true)),
                const SizedBox(width: 10),
                _modalRoleBtn(
                  setModal, '🙏', 'Member',
                  !isHost, () => setModal(() => isHost = false)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _joinClass(ctrl.text.trim(), isHost: isHost);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Join Class →',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                    )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalRoleBtn(
    StateSetter setModal,
    String icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kGold.withOpacity(0.08) : kMilk,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kGold : kGold.withOpacity(0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(label,
                style: TextStyle(
                  color: selected ? kGoldDark : kTextLight,
                  fontWeight: FontWeight.w700, fontSize: 14,
                )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinClass(String room, {bool isHost = false}) async {
    if (room.isEmpty) {
      _showJoinDialog();
      return;
    }
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    try {
      final jitsi = JitsiMeet();
      await jitsi.join(JitsiMeetConferenceOptions(
        room: 'Lifestones-$room',
        userInfo: JitsiMeetUserInfo(
          displayName: _user?.displayName ?? 'Member',
          email: _user?.email,
        ),
        configOverrides: {
          'startWithAudioMuted': false,
          'startWithVideoMuted': false,
          'disableDeepLinking': true,
          'prejoinPageEnabled': false,
          'lobby.enabled': false,
          'p2p.enabled': true,
          'channelLastN': 10,
        },
        featureFlags: {
          'recording.enabled': isHost,
          'live-streaming.enabled': false,
          'raise-hand.enabled': true,
          'chat.enabled': true,
          'pip.enabled': true,
          'toolbox.alwaysVisible': true,
          'invite.enabled': false,
          'meeting-password.enabled': false,
        },
      ));
    } catch (e) {
      debugPrint('Join error: $e');
    }
  }
}

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schedule = [
      {'day': 'Friday', 'time': '6:00 PM', 'topic': 'Discipleship Class', 'emoji': '📖'},
      {'day': 'Saturday', 'time': '6:00 PM', 'topic': 'Bible Study', 'emoji': '✝️'},
      {'day': 'Sunday', 'time': '6:00 PM', 'topic': 'Sunday Service', 'emoji': '⛪'},
    ];

    return Scaffold(
      backgroundColor: kMilk,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Classes',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: kText, letterSpacing: -0.5,
                )),
              const SizedBox(height: 4),
              Text('Weekly discipleship schedule',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextLight.withOpacity(0.6),
                )),
              const SizedBox(height: 24),
              ...schedule.map((s) => _buildScheduleCard(context, s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext ctx, Map<String, String> s) {
    final now = DateTime.now();
    final isToday = now.weekday == _dayNumber(s['day']!);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isToday ? kGold : kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? kGold : kGold.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: kGold.withOpacity(isToday ? 0.3 : 0.08),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(s['emoji']!, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s['day']!,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: isToday ? kWhite : kText,
                      )),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('TODAY',
                          style: TextStyle(
                            fontSize: 9, color: kWhite,
                            fontWeight: FontWeight.w800, letterSpacing: 1,
                          )),
                      ),
                    ],
                  ],
                ),
                Text('${s['topic']} · ${s['time']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isToday
                        ? kWhite.withOpacity(0.8)
                        : kTextLight.withOpacity(0.7),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _dayNumber(String day) {
    switch (day) {
      case 'Friday': return DateTime.friday;
      case 'Saturday': return DateTime.saturday;
      case 'Sunday': return DateTime.sunday;
      default: return 1;
    }
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: kMilk,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [kGoldLight, kGold]),
                ),
                child: Center(
                  child: Text(
                    (user?.displayName ?? 'M')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w800,
                      color: kWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'Member',
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: kText,
                )),
              const SizedBox(height: 4),
              Text(user?.email ?? '',
                style: TextStyle(
                  fontSize: 14, color: kTextLight.withOpacity(0.6),
                )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('⛪ Lifestones Member',
                  style: TextStyle(
                    color: kGoldDark, fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
              ),
              const SizedBox(height: 40),
              _buildTile(Icons.notifications_outlined,
                'Class Reminders', 'Fri, Sat, Sun · 30 min before'),
              _buildTile(Icons.info_outline,
                'About Lifestones', 'Discipleship · Community · Faith'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async => await signOut(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Sign Out',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                    )),
                ),
              ),
            ],
          ),
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
        border: Border.all(color: kGold.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kText,
                  )),
                Text(subtitle,
                  style: TextStyle(
                    fontSize: 12, color: kTextLight.withOpacity(0.6),
                  )),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
            color: kGold.withOpacity(0.4), size: 20),
        ],
      ),
    );
  }
}
