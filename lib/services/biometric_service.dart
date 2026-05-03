import 'package:local_auth/local_auth.dart';
import 'package:audioplayers/audioplayers.dart';

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

      // --- FIX IS HERE ---
      // Inside authenticate()
      if (didAuthenticate) {
        _player.setReleaseMode(ReleaseMode.release); // Forces it to play only once
        _player.play(AssetSource('sound/success.mp3'));
      }
      return didAuthenticate;

      // if (didAuthenticate) {
      //   try {
      //     // We wrap this in its own try/catch so if the sound is missing, 
      //     // the app doesn't return "false" for the whole login.
      //     await _player.play(AssetSource('sound/success.mp3'));
      //   } catch (e) {
      //     print("Sound failed but fingerprint passed: $e");
      //   }
      // }
      // -------------------

      // return didAuthenticate;
    } catch (e) {
      print("Error in biometric: $e");
      return false;
    }
  }
}