import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioPlayer player = AudioPlayer();
  
  // Store the state here so it survives when the UI is destroyed
  static String currentTitle = "Select a Surah";
  static bool hasActiveTrack = false;

  static void stopAll() {
    player.stop();
    currentTitle = "Select a Surah";
    hasActiveTrack = false;
  }
}