import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/audio_manager.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _audioPlayer = AudioManager.player;
  List _tracks = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  String _currentTitle = "Select a Surah";
  Set<String> _favoritedIds = {}; // Local track of hearts
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadFavorites();

    // 1. RESTORE STATE
    _isPlaying = _audioPlayer.state == PlayerState.playing;
    _currentTitle = AudioManager.currentTitle;

    // 2. LISTENERS (For moving bar)
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) setState(() => _duration = d);
    });
    
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = (state == PlayerState.playing));
    });

    if (AudioManager.hasActiveTrack) {
      _syncExistingPlayer();
    }
  }

  void _syncExistingPlayer() async {
    final d = await _audioPlayer.getDuration();
    final p = await _audioPlayer.getCurrentPosition();
    if (mounted) {
      setState(() {
        _isPlaying = _audioPlayer.state == PlayerState.playing;
        if (d != null) _duration = d;
        if (p != null) _position = p;
      });
    }
  }

  void _play(int id, String name) async {
    if (mounted) {
      setState(() {
        _currentTitle = name;
        _position = Duration.zero; 
        _duration = Duration.zero; 
      });
    }

    AudioManager.currentTitle = name;
    AudioManager.hasActiveTrack = true;

    String chapterId = id.toString().padLeft(3, '0');
    String audioUrl = "https://server8.mp3quran.net/afs/$chapterId.mp3"; 
    
    await _audioPlayer.play(UrlSource(audioUrl));
    Future.delayed(const Duration(seconds: 2), () => _syncExistingPlayer());
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters?language=en'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _tracks = json.decode(response.body)['chapters'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').get();
    if (mounted) setState(() => _favoritedIds = snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Audio Library", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final chapter = _tracks[index];
                      final String chapterId = chapter['id'].toString();
                      bool isFav = _favoritedIds.contains(chapterId);

                      return ListTile(
                        leading: Text(chapterId, style: const TextStyle(color: Colors.blueGrey)),
                        title: Text(chapter['name_simple'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        subtitle: Text(chapter['translated_name']['name'], style: const TextStyle(color: Colors.grey)),
                        // --- RESTORED FAVORITE BUTTON ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, 
                                         color: isFav ? Colors.redAccent : Colors.blueGrey),
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').doc(chapterId);
                                if (isFav) {
                                  await docRef.delete();
                                  if (mounted) setState(() => _favoritedIds.remove(chapterId));
                                } else {
                                  await docRef.set({'name': chapter['name_simple'], 'id': chapter['id']});
                                  if (mounted) setState(() => _favoritedIds.add(chapterId));
                                }
                              },
                            ),
                            const Icon(Icons.play_arrow, color: Colors.blueAccent),
                          ],
                        ),
                        onTap: () => _play(chapter['id'], chapter['name_simple']),
                      );
                    },
                  ),
                ),
                
                // BOTTOM CONTROL PANEL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  ),
                  child: Column(
                    children: [
                      Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      Slider(
                        value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                        max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.white10,
                        onChanged: (v) async {
                          await _audioPlayer.seek(Duration(seconds: v.toInt()));
                        },
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position), style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                            Text(_formatDuration(_duration), style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      IconButton(
                        iconSize: 64,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        color: Colors.white,
                        onPressed: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.resume(),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}