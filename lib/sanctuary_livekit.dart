import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'config/livekit_config.dart';

class LiveKitSanctuary extends StatefulWidget {
  final String roomName;
  final String participantName;
  final bool isModerator;
  const LiveKitSanctuary({
    required this.roomName,
    required this.participantName,
    required this.isModerator,
    super.key});
  @override
  State<LiveKitSanctuary> createState() => _LiveKitSanctuaryState();
}

class _LiveKitSanctuaryState extends State<LiveKitSanctuary> {
  Room? _room;
  bool _connected = false;
  bool _muted = true;
  bool _loading = true;
  String _status = 'Connecting...';
  int _participantCount = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      // Get token from token server
      final tokenUrl = LiveKitConfig.tokenUrl(
        widget.roomName, widget.participantName);
      final response = await http.get(Uri.parse(tokenUrl));
      final data = jsonDecode(response.body);
      final token = data['token'] as String;

      // Connect to LiveKit room
      final room = Room();
      await room.connect(LiveKitConfig.wsUrl, token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ));

      room.addListener(_onRoomUpdate);

      setState(() {
        _room = room;
        _connected = true;
        _loading = false;
        _status = 'Connected';
        _participantCount = room.remoteParticipants.length + 1;
      });

      // Pastors start unmuted, members start muted
      if (widget.isModerator) {
        await _toggleMic();
      }

    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Connection failed: $e';
      });
    }
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {
        _participantCount = (_room?.remoteParticipants.length ?? 0) + 1;
      });
    }
  }

  Future<void> _toggleMic() async {
    if (_room == null) return;
    final localParticipant = _room!.localParticipant;
    if (localParticipant == null) return;
    await localParticipant.setMicrophoneEnabled(_muted);
    setState(() => _muted = !_muted);
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800)),
            Text('$_participantCount listening',
              style: const TextStyle(
                color: Colors.white60, fontSize: 12)),
          ]),
        actions: [
          if (_connected)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12)),
              child: const Text('LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800))),
        ]),
      body: _loading
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFC9A84C)),
              const SizedBox(height: 16),
              Text(_status,
                style: const TextStyle(color: Colors.white60)),
            ]))
        : Column(
            children: [
              const SizedBox(height: 40),
              // Audio wave animation
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC9A84C).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFFC9A84C), width: 2)),
                child: const Icon(Icons.cell_tower,
                  color: Color(0xFFC9A84C), size: 48)),
              const SizedBox(height: 24),
              Text(_status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('$_participantCount participants',
                style: const TextStyle(color: Colors.white60)),
              const Spacer(),
              // Controls
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    GestureDetector(
                      onTap: _toggleMic,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _muted
                            ? Colors.white12
                            : const Color(0xFFC9A84C)),
                        child: Icon(
                          _muted ? Icons.mic_off : Icons.mic,
                          color: Colors.white, size: 28))),
                    // Leave button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 70, height: 70,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white, size: 28))),
                  ])),
              const SizedBox(height: 32),
            ]));
  }
}
