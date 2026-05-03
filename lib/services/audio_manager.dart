import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  // Static instance so we can access it from ANY file
  static final AudioPlayer player = AudioPlayer();

  static void stopAll() {
    player.stop();
  }
}