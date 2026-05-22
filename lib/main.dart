import 'dart:async'; // Required for memory management
import 'package:audioplayers/audioplayers.dart';
import 'package:final_final/services/audio_manager.dart';
import 'package:final_final/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart'; 
import 'screens/login_page.dart';
import 'screens/biometric_screen.dart';
import 'screens/player_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Midnight
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
    ),
    home: const AppStartGate(),
  ));
}

// THE BIOMETRIC WALL
class AppStartGate extends StatefulWidget {
  const AppStartGate({super.key});
  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate> {
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return BiometricScreen(onSuccess: () {
        setState(() => _isUnlocked = true);
      });
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) return const LoginPage();
        return const ProfilePage();
      },
    );
  }
}

// THE DASHBOARD
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  int _monthlyGoal = 20;
  final List<double> _dailyMinutes = [45, 120, 30, 90, 60, 15, 100]; 

  // 1. CREATE A VARIABLE TO HOLD THE PROFILE FUTURE
  late Future<Map<String, dynamic>?> _profileFuture;

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadGoal();
    
    // 2. INITIALIZE THE FUTURE ONCE HERE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileFuture = AuthService().getProfile(user.uid);
    }

    _isPlaying = AudioManager.player.state == PlayerState.playing;
    _stateSub = AudioManager.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _posSub = AudioManager.player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = AudioManager.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel(); _durSub?.cancel(); _stateSub?.cancel();
    super.dispose();
  }

  // (Keep your existing _loadGoal, _updateGoal, _getTotalTime, and _secureDelete functions)
  _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _monthlyGoal = prefs.getInt('monthly_goal') ?? 20);
  }
  _updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthly_goal', newGoal);
    setState(() => _monthlyGoal = newGoal);
  }
  String _getTotalTime() {
    double totalMinutes = _dailyMinutes.reduce((a, b) => a + b);
    return "${(totalMinutes / 60).floor()} h ${(totalMinutes % 60).toInt()} m";
  }
  void _secureDelete(DocumentReference docRef) async {
    bool authenticated = await BiometricService.authenticate();
    if (authenticated) await docRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // PERSISTENT MINI PLAYER
      bottomNavigationBar: AudioManager.hasActiveTrack ? _buildMiniPlayer() : null,
      
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("Control Center", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () { AudioManager.stopAll(); AuthService().logout(); },
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture, // 3. USE THE CACHED FUTURE VARIABLE HERE
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data ?? {"firstName": "Guest", "lastName": ""};
          
          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                    children: [
                      const TextSpan(text: "Hello, "),
                      TextSpan(text: "${data['firstName']} ${data['lastName']}", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: _buildStatTile("Listen Time", _getTotalTime(), Icons.timer_outlined)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildGoalTile()),
                  ],
                ),
                const SizedBox(height: 25),
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: _dailyMinutes.asMap().entries.map((e) => 
                        BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(toY: e.value, color: Colors.blueAccent, width: 12, borderRadius: BorderRadius.circular(4))
                        ])
                      ).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerPage())),
                    icon: const Icon(Icons.library_music_rounded),
                    label: const Text("OPEN AUDIO LIBRARY", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 35),
                const Text("Secure Favorites", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildFavoritesList(user.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  // (Keep your _buildMiniPlayer, _buildStatTile, _buildGoalTile, and _buildFavoritesList code as is)
  Widget _buildMiniPlayer() {
    double progress = _position.inSeconds / (_duration.inSeconds > 0 ? _duration.inSeconds : 1);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage())),
      child: Container(
        height: 80,
        margin: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 2, backgroundColor: Colors.white10, color: Colors.blueAccent),
            ListTile(
              dense: true,
              leading: const Icon(Icons.graphic_eq, color: Colors.blueAccent),
              title: Text(AudioManager.currentTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: const Text("TAP TO OPEN", style: TextStyle(color: Colors.white38, fontSize: 10)),
              trailing: IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 32),
                onPressed: () => _isPlaying ? AudioManager.player.pause() : AudioManager.player.resume(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGoalTile() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<int>(
            value: _monthlyGoal,
            dropdownColor: const Color(0xFF1E293B),
            isDense: true,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: [10, 20, 30, 40].map((int val) => DropdownMenuItem(value: val, child: Text("$val hrs"))).toList(),
            onChanged: (val) => _updateGoal(val!),
          ),
          const SizedBox(height: 5),
          const Text("Monthly Target", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ((_dailyMinutes.reduce((a, b) => a + b) / 60) / _monthlyGoal).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            color: Colors.greenAccent,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final fav = docs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
                title: Text(fav['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                  onPressed: () => _secureDelete(fav.reference),
                ),
              ),
            );
          },
        );
      },
    );
  }
}



