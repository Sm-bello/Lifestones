import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const kBackground = Color(0xFFFFFFFF);
const kSurface    = Color(0xFFF8F9FA);
const kGold       = Color(0xFFC9973A);
const kTextDark   = Color(0xFF1A1A1A);
const kTextLight  = Color(0xFF757575);

final _auth = FirebaseAuth.instance;

Future<User?> signInWithGoogle() async {
  try {
    final googleSignIn = GoogleSignIn.instance;
    final googleUser = await googleSignIn.authenticate();
    if (googleUser == null) return null;
    
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
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
  await GoogleSignIn.instance.signOut();
  await _auth.signOut();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(); 
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: kBackground,
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
        scaffoldBackgroundColor: kBackground,
        colorScheme: const ColorScheme.light(primary: kGold),
        fontFamily: 'Roboto', // Fallback, we can add a custom font later
      ),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGold)));
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

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    await signInWithGoogle();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [kGold.withOpacity(0.7), kGold]),
                  ),
                  child: const Center(child: Text('✝', style: TextStyle(fontSize: 50, color: Colors.white))),
                ),
                const SizedBox(height: 32),
                const Text('Lifestones', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kTextDark)),
                const SizedBox(height: 8),
                const Text('DISCIPLESHIP · COMMUNITY · FAITH', style: TextStyle(fontSize: 12, letterSpacing: 2, color: kTextLight)),
                const SizedBox(height: 64),
                ElevatedButton(
                  onPressed: _loading ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
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
  
  // MLP: Setting up the 5 screens to match the design
  final _screens = const [
    DiscoverScreen(),
    Center(child: Text('Meetings Screen (Coming Soon)')),
    Center(child: Text('Ministers Screen (Coming Soon)')),
    Center(child: Text('Messages Screen (Coming Soon)')),
    Center(child: Text('Library Screen (Coming Soon)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_tab],
          // The Persistent Mini-Player matching the screenshot
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildMiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.white,
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
            BottomNavigationBarItem(icon: Icon(Icons.library_books_outlined), activeIcon: Icon(Icons.library_books), label: 'Library'),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            color: kGold.withOpacity(0.3),
            child: const Icon(Icons.music_note, color: kGold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Works of The Devil By Attaining...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Rev. Kayode Oyegoke', style: TextStyle(fontSize: 11, color: kGold)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.play_circle_fill, size: 32, color: kTextDark), onPressed: () {}),
          IconButton(icon: const Icon(Icons.close, color: kTextLight), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: kTextDark), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: kTextDark), onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: GestureDetector(
              onTap: signOut,
              child: const CircleAvatar(radius: 16, backgroundColor: kGold, child: Icon(Icons.person, size: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
      // Add bottom padding so the scroll view doesn't hide behind the mini player (64px)
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHorizontalList(
              height: 220,
              items: [
                _buildMediaCard('Overcoming The World', 'Rev. Kayode Oyegoke', Icons.podcasts),
                _buildMediaCard('The Heart nature of a...', 'Rev. Kayode Oyegoke', Icons.podcasts),
                _buildMediaCard('Ascending From Zion', 'Rev. Kayode Oyegoke', Icons.podcasts),
              ]
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Curated for you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
            ),
            const SizedBox(height: 16),
            _buildHorizontalList(
              height: 240,
              items: [
                _buildCuratedCard('Leading of the Spirit', '7 Messages'),
                _buildCuratedCard('Believers Convention', '30 Messages'),
                _buildCuratedCard('Marriage & Family', '9 Messages'),
              ]
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Popular in your circle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
            ),
            const SizedBox(height: 16),
            _buildHorizontalList(
              height: 200,
              items: [
                _buildSquareCard('Cleft Music', Colors.purpleAccent),
                _buildSquareCard('Prayer Meeting', Colors.orange),
                _buildSquareCard('Everlasting School', Colors.deepPurple),
              ]
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList({required double height, required List<Widget> items}) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _buildMediaCard(String title, String subtitle, IconData icon) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160, width: 160,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: const Center(child: Icon(Icons.image_outlined, size: 40, color: kGold)), // Placeholder for real image
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kGold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCuratedCard(String title, String subtitle) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 190, width: 140,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: const Center(child: Icon(Icons.book, size: 40, color: kGold)), // Placeholder for real image
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kGold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSquareCard(String title, Color color) {
    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
    );
  }
}
