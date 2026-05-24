import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_manager.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioManager.player;

  MyAudioHandler() {
    // Pipe the player's state into the Android Notification system
    _player.onPlayerStateChanged.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state == PlayerState.playing,
        processingState: state == PlayerState.stopped 
        ? AudioProcessingState.idle 
        : AudioProcessingState.ready,
        
        controls: [
          MediaControl.pause,
          MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
      ));
    });
  }

  // when the user clicks Play in the notification bar
  @override
  Future<void> play() => _player.resume();

  // when the user clicks Pause in the notification bar
  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop(); // Stop the hardware
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle, // Tells Android we are done
    ));
    return super.stop(); // This kills the notification
  }

  // updates the actual Text and Image in the notification bar
  void updateMetadata(String title, String reciter) {
    mediaItem.add(MediaItem(
      id: 'id_1', 
      album: "SecureStream",
      title: title,
      artist: reciter,
    ));
  }
}