class LiveKitConfig {
  static const String wsUrl = 'wss://lifestones-s3a7ls14.livekit.cloud';
  static const String apiKey = 'APINFTXKpek55BD';
  static const String sandboxTokenUrl = 'https://lifestones-2mqxdn.sandbox.livekit.io';

  static String tokenUrl(String roomName, String participantName) {
    final encodedRoom = Uri.encodeComponent(roomName);
    final encodedName = Uri.encodeComponent(participantName);
    return '$sandboxTokenUrl/token?roomName=$encodedRoom&participantName=$encodedName';
  }
}
