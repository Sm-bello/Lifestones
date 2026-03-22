class LiveKitConfig {
  static const String wsUrl = 'wss://lifestones-s3a7ls14.livekit.cloud';
  static const String sandboxTokenUrl = 'https://lifestones-2mqxdn.sandbox.livekit.io';
  static const String sandboxId = 'lifestones-2mqxdn';

  // Get token for a room - uses sandbox for now
  static String tokenUrl(String roomName, String participantName) {
    return '$sandboxTokenUrl/token?roomName=$roomName&participantName=$participantName';
  }
}
