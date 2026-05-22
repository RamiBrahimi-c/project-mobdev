import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

class BiometricScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const BiometricScreen({super.key, required this.onSuccess});

  @override
  _BiometricScreenState createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _isAuthenticating = false;
  bool _didSucceed = false; // to prevent double-firing

  @override
  void initState() {
    super.initState();
    // Use a slightly longer delay to ensure the native UI is ready
    Future.delayed(const Duration(milliseconds: 1000), () => _startAuth());
  }

  void _startAuth() async {
    // If we already succeeded or are currently prompt, don't do anything
    if (_isAuthenticating || _didSucceed) return; 
    
    if (mounted) setState(() => _isAuthenticating = true);
    
    bool success = await BiometricService.authenticate();
    
    if (success) {
      _didSucceed = true; // Mark as done
      if (mounted) widget.onSuccess(); 
    } else {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showSettingsDialog();
      }
    }
  }

  void _showSettingsDialog() {
    // Check if dialog is already showing to prevent "cancelDraw" loops
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Security Required"),
        content: const Text("Authentication failed or cancelled. Please try again."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Give the OS a moment to close the dialog before showing fingerprint again
              Future.delayed(const Duration(milliseconds: 500), () => _startAuth()); 
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Removed "const" to allow dynamic updates
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_isAuthenticating ? "Authenticating..." : "Please scan your fingerprint"),
          ],
        ),
      ),
    );
  }
}