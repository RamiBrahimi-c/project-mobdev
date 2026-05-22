import 'package:local_auth/local_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static final _player = AudioPlayer();

  static Future<bool> authenticate() async {
    bool canCheckBiometrics = await _auth.canCheckBiometrics;
    bool isDeviceSupported = await _auth.isDeviceSupported();

    if (!canCheckBiometrics || !isDeviceSupported) return false;

    try {
      bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(stickyAuth: true),
      );

      if (didAuthenticate) {
        _player.setReleaseMode(ReleaseMode.release); // Forces it to play only once
        _player.play(AssetSource('sound/success.mp3'));
      }
      return didAuthenticate;

    } catch (e) {
      debugPrint("Error in biometric: $e");
      return false;
    }
  }
}
