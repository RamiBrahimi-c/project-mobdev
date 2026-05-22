import 'package:final_final/services/audio_manager.dart';
import 'package:final_final/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart'; 
import 'screens/login_page.dart';
import 'screens/biometric_screen.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/player_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Deep Midnight Blue
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
    ),
    home: const AppStartGate(),
  ));
}

class AppStartGate extends StatefulWidget {
  const AppStartGate({super.key});
  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate> {
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    // LOCK: If not unlocked, show ONLY the Biometric Screen. 
    // This stops Firebase from even trying to run.
    if (!_isUnlocked) {
      return BiometricScreen(onSuccess: () {
        setState(() => _isUnlocked = true);
      });
    }

    // UNLOCK: Now we let Firebase take over.
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  int _monthlyGoal = 20;
  final List<double> _dailyMinutes = [45, 120, 30, 90, 60, 15, 100]; 

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _monthlyGoal = prefs.getInt('monthly_goal') ?? 20);
  }

  _updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthly_goal', newGoal);
    setState(() => _monthlyGoal = newGoal);
  }

  String _getTotalTime() {
    double totalMinutes = _dailyMinutes.reduce((a, b) => a + b);
    int hours = (totalMinutes / 60).floor();
    int minutes = (totalMinutes % 60).toInt();
    return "$hours h ${minutes} m";
  }

  void _secureDelete(DocumentReference docRef) async {
    bool authenticated = await BiometricService.authenticate();
    if (authenticated) {
      await docRef.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
        future: AuthService().getProfile(user.uid),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
          final data = snapshot.data ?? {"firstName": "Guest", "lastName": ""};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DYNAMIC WELCOME
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

                // 2. NOW PLAYING CARD (Makes the home page feel relevant)
                if (AudioManager.hasActiveTrack) 
                  _buildNowPlayingCard(),

                const SizedBox(height: 30),
                const Text("Usage Statistics", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.1)),
                const SizedBox(height: 15),

                // 3. STATS GRID (Total Time + Goal)
                Row(
                  children: [
                    Expanded(child: _buildStatTile("Listen Time", _getTotalTime(), Icons.timer_outlined)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildGoalTile()),
                  ],
                ),

                const SizedBox(height: 25),

                // 4. THE REQUIREMENT: HISTOGRAM
                const Text("Monthly Activity", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 15),
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
                // 5. MAIN ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
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

  // --- COMPONENT WIDGETS ---

  Widget _buildNowPlayingCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blueAccent, Colors.blueAccent.withOpacity(0.6)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CONTINUE LISTENING", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(AudioManager.currentTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
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
            value: (_dailyMinutes.reduce((a, b) => a + b) / 60) / _monthlyGoal,
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








