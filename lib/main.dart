import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFDF6E3),
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LifestonesApp());
}

const kMilk      = Color(0xFFFDF6E3);
const kMilkDark  = Color(0xFFF5ECD7);
const kGold      = Color(0xFFC9973A);
const kGoldLight = Color(0xFFE2B96F);
const kGoldDark  = Color(0xFFA07828);
const kText      = Color(0xFF2C1A00);
const kTextLight = Color(0xFF8B6914);
const kWhite     = Color(0xFFFFFFFF);
const kRed       = Color(0xFFD32F2F);
const kGreen     = Color(0xFF2E7D32);

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
        fontFamily: 'serif',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _isHost = false;
  bool _loading = false;
  String _error = '';

  Future<void> _joinMeeting() async {
    final name = _nameCtrl.text.trim();
    final room = _roomCtrl.text.trim().toUpperCase();

    if (name.isEmpty || room.isEmpty) {
      setState(() => _error = 'Please enter your name and room code');
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
        userInfo: JitsiMeetUserInfo(displayName: name),
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "disableDeepLinking": true,
          "prejoinPageEnabled": false,
          "p2p.enabled": true,
          "channelLastN": 10,
          "toolbarButtons": [
            "microphone",
            "camera",
            "chat",
            "raisehand",
            "hangup",
          ],
        },
        featureFlags: {
          "recording.enabled": _isHost,
          "live-streaming.enabled": false,
          "raise-hand.enabled": true,
          "chat.enabled": true,
          "pip.enabled": true,
          "meeting-name.enabled": true,
          "toolbox.alwaysVisible": true,
          "video-mute.enabled": true,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildHero(),
                const SizedBox(height: 36),
                _buildCard(),
                const SizedBox(height: 16),
                Text(
                  'Share your room code with members before class',
                  style: TextStyle(
                    color: kTextLight.withOpacity(0.7),
                    fontSize: 12,
                  ),
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

  Widget _buildHero() {
    return Column(children: [
      Container(
        width: 80, height: 80,
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
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Text('✝', style: TextStyle(fontSize: 40, color: kWhite)),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Lifestones',
        style: TextStyle(
          fontSize: 40, fontWeight: FontWeight.w800,
          color: kGold, letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'DISCIPLESHIP · COMMUNITY · FAITH',
        style: TextStyle(
          fontSize: 10, letterSpacing: 3.5,
          color: kTextLight.withOpacity(0.6),
        ),
      ),
    ]);
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
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('YOUR NAME'),
          _inputField(_nameCtrl, 'e.g. Bro Emmanuel', false),
          const SizedBox(height: 16),
          _label('ROOM CODE'),
          _inputField(_roomCtrl, 'FRIDAY', true),
          const SizedBox(height: 16),
          _label('I AM JOINING AS'),
          _roleSelector(),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_error,
              style: const TextStyle(color: kRed, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          _joinButton(),
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

  Widget _inputField(TextEditingController ctrl, String hint, bool isCode) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        color: kText,
        fontSize: isCode ? 22 : 16,
        letterSpacing: isCode ? 6 : 0,
        fontFamily: isCode ? 'monospace' : null,
        fontWeight: isCode ? FontWeight.w700 : FontWeight.normal,
      ),
      textCapitalization: isCode
          ? TextCapitalization.characters
          : TextCapitalization.words,
      textAlign: isCode ? TextAlign.center : TextAlign.start,
      onChanged: isCode
          ? (v) => ctrl.value = ctrl.value.copyWith(
              text: v.toUpperCase(),
              selection: TextSelection.collapsed(offset: v.length))
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: kTextLight.withOpacity(0.4)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _roleSelector() {
    return Row(children: [
      _roleBtn('🎤', 'Pastor', 'Records session', true),
      const SizedBox(width: 10),
      _roleBtn('🙏', 'Member', 'Join & participate', false),
    ]);
  }

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

  Widget _joinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _joinMeeting,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kWhite,
          disabledBackgroundColor: kGold.withOpacity(0.5),
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
                  fontSize: 17, fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
      ),
    );
  }
}
