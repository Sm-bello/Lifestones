import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

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
const kSurface   = Color(0xFFF8F9FA);

// EXACT ENGINE FROM YOUR FRIEND'S SCRIPT
final _googleSignIn = GoogleSignIn(scopes: ['email']);
final _auth = FirebaseAuth.instance;
final AudioPlayer globalAudioPlayer = AudioPlayer(); 

Future<void> initAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}

// EXACT LOGIC FROM YOUR FRIEND'S SCRIPT
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
  await globalAudioPlayer.stop(); 
  await _googleSignIn.signOut();
  await _auth.signOut();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initAudioSession(); 
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: kMilk, statusBarIconBrightness: Brightness.dark),
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
      theme: ThemeData(scaffoldBackgroundColor: kMilk, colorScheme: const ColorScheme.light(primary: kGold)),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(backgroundColor: kMilk, body: Center(child: CircularProgressIndicator(color: kGold)));
          }
          if (snapshot.hasData) return const MainShell();
          return const LoginScreen();
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _error = '';
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
      setState(() { _error = 'Sign-in cancelled. Please try again.'; _loading = false; });
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
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kMilk, kMilkDark])),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [kGoldLight, kGold], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: kGold.withOpacity(0.5), blurRadius: 32, spreadRadius: 4)]),
                    child: const Center(child: Text('✝', style: TextStyle(fontSize: 48, color: kWhite))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Lifestones', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: kGold, letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text('DISCIPLESHIP · COMMUNITY · FAITH', style: TextStyle(fontSize: 10, letterSpacing: 3.5, color: kTextLight.withOpacity(0.6))),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(28), border: Border.all(color: kGold.withOpacity(0.15)), boxShadow: [BoxShadow(color: kGold.withOpacity(0.12), blurRadius: 32, spreadRadius: 2, offset: const Offset(0, 6))]),
                    child: Column(
                      children: [
                        const Text('Welcome to the Family', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
                        const SizedBox(height: 8),
                        Text('Join thousands growing in faith together.\nSign in to access your discipleship classes.', style: TextStyle(fontSize: 14, height: 1.5, color: kTextLight.withOpacity(0.7)), textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        if (_error.isNotEmpty) ...[
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Text(_error, style: const TextStyle(color: kRed, fontSize: 13), textAlign: TextAlign.center)),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kWhite, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6, shadowColor: kGold.withOpacity(0.5)),
                            child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
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
  bool _showMiniPlayer = false;
  String _currentSermonTitle = "Select a message to play";
  
  final _screens = const [
    DiscoverScreen(),
    MeetingsScreen(),
    Center(child: Text('Ministers Screen (Coming Soon)', style: TextStyle(color: kGold, fontWeight: FontWeight.bold))),
    Center(child: Text('Messages Screen (Coming Soon)', style: TextStyle(color: kGold, fontWeight: FontWeight.bold))),
    ProfileScreen(), 
  ];

  @override
  void initState() {
    super.initState();
    globalAudioPlayer.playingStream.listen((playing) {
      if (playing && !_showMiniPlayer && mounted) {
        setState(() => _showMiniPlayer = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Stack(
        children: [
          _screens[_tab],
          if (_showMiniPlayer)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildMiniPlayer()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: kWhite,
          selectedItemColor: kGold,
          unselectedItemColor: kTextLight.withOpacity(0.5),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Discover'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Meetings'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Ministers'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view), label: 'Messages'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 68,
      decoration: BoxDecoration(color: kSurface, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(
        children: [
          StreamBuilder<Duration>(
            stream: globalAudioPlayer.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = globalAudioPlayer.duration ?? const Duration(milliseconds: 1);
              double progress = position.inMilliseconds / duration.inMilliseconds;
              if (progress.isNaN || progress.isInfinite) progress = 0.0;
              return LinearProgressIndicator(value: progress, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation<Color>(kGold), minHeight: 2);
            }
          ),
          Expanded(
            child: Row(
              children: [
                Container(width: 64, height: 64, color: kGold.withOpacity(0.15), child: const Icon(Icons.music_note, color: kGold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentSermonTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kText), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Text('Lifestones Media', style: TextStyle(fontSize: 11, color: kGold)),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: globalAudioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;
                    
                    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                      return const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: kGold, strokeWidth: 2)));
                    } else if (playing != true) {
                      return IconButton(icon: const Icon(Icons.play_circle_fill, size: 36, color: kText), onPressed: globalAudioPlayer.play);
                    } else {
                      return IconButton(icon: const Icon(Icons.pause_circle_filled, size: 36, color: kGold), onPressed: globalAudioPlayer.pause);
                    }
                  },
                ),
                IconButton(icon: const Icon(Icons.close, color: kTextLight), onPressed: () { globalAudioPlayer.stop(); setState(() => _showMiniPlayer = false); }),
                const SizedBox(width: 4),
              ],
            ),
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
  bool _isJoining = false;

  Future<void> _joinService() async {
    setState(() => _isJoining = true);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isWeakNetwork = false;
      if (connectivityResult is List) {
        isWeakNetwork = connectivityResult.contains(ConnectivityResult.mobile);
      } else {
        isWeakNetwork = connectivityResult == ConnectivityResult.mobile;
      }
      
      if (isWeakNetwork && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weak network detected. Activating Audio-Only Mode 📡'), backgroundColor: kGoldDark, duration: Duration(seconds: 4)));
      }

      var options = JitsiMeetConferenceOptions(
        room: "LifestonesMainSanctuary",
        userInfo: JitsiMeetUserInfo(displayName: FirebaseAuth.instance.currentUser?.displayName ?? "Member", email: FirebaseAuth.instance.currentUser?.email),
        configOverrides: {"startWithAudioMuted": false, "startWithVideoMuted": true, if (isWeakNetwork) "startAudioOnly": true},
        featureFlags: {"unwelcome.page.enabled": false, "prejoinpage.enabled": false},
      );
      
      var jitsiMeet = JitsiMeet();
      await globalAudioPlayer.pause(); 
      await jitsiMeet.join(options);
    } catch (e) {
      debugPrint("Jitsi error: $e");
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(backgroundColor: kWhite, elevation: 0, title: const Text('Live Meetings', style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 22))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 120, height: 120, decoration: BoxDecoration(color: kGold.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.cell_tower, size: 60, color: kGold)),
              const SizedBox(height: 32),
              const Text('The Sanctuary', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kText)),
              const SizedBox(height: 12),
              const Text('Powered by the Lifestones Data Saver Engine.\nJoin securely and clearly, even on a 3G network.', textAlign: TextAlign.center, style: TextStyle(color: kTextLight, height: 1.5, fontSize: 14)),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isJoining ? null : _joinService,
                style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kWhite, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6, shadowColor: kGold.withOpacity(0.5)),
                child: _isJoining ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Text('Join Live Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  void _playTestSermon(BuildContext context, String title) async {
    try {
      final url = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"; 
      await globalAudioPlayer.setUrl(url);
      globalAudioPlayer.play();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing: $title'), backgroundColor: kGold));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Friend';
    
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite, elevation: 0,
        title: Text('Hello, $firstName', style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: kText), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: kText), onPressed: () {}),
          Padding(padding: const EdgeInsets.only(right: 16, left: 8), child: CircleAvatar(radius: 16, backgroundColor: kGold, child: Text((firstName.isNotEmpty ? firstName[0] : 'M').toUpperCase(), style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 14)))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHorizontalList(height: 220, items: [
              _buildPlayableMediaCard(context, 'Test Engine Audio', 'Sample Track', Icons.play_arrow),
              _buildPlayableMediaCard(context, 'The Heart Nature', 'Rev. Kayode', Icons.podcasts),
            ]),
            const SizedBox(height: 32),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Curated for you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kText))),
            const SizedBox(height: 16),
            _buildHorizontalList(height: 240, items: [
              _buildCuratedCard('Leading of the Spirit', '7 Messages'),
              _buildCuratedCard('Believers Convention', '30 Messages'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayableMediaCard(BuildContext context, String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () => _playTestSermon(context, title),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 160, width: 160, decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.1))), child: Center(child: Icon(icon, size: 40, color: kGold))),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kText), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: kGold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList({required double height, required List<Widget> items}) {
    return SizedBox(height: height, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 16), itemBuilder: (_, i) => items[i]));
  }

  Widget _buildCuratedCard(String title, String subtitle) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 190, width: 140, decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.1))), child: const Center(child: Icon(Icons.book, size: 40, color: kGold))),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kGold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(width: 90, height: 90, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kGoldLight, kGold])), child: Center(child: Text((user?.displayName != null && user!.displayName!.isNotEmpty ? user.displayName![0] : 'M').toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: kWhite)))),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'Member', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: TextStyle(fontSize: 14, color: kTextLight.withOpacity(0.6))),
              const Spacer(),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () async => await signOut(), style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Sign Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
              const SizedBox(height: 80), 
            ],
          ),
        ),
      ),
    );
  }
}
