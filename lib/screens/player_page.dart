import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/audio_manager.dart';
import 'package:flutter/services.dart';

import '../main.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _audioPlayer = AudioManager.player;
  
  // Data Master Lists
  List _surahs = [];
  List _reciters = [];
  
  // Filtered Lists (What the UI sees)
  List _filteredSurahs = [];
  List _filteredReciters = [];
  
  bool _isLoading = true;
  bool _isPlaying = false;
  
  String _currentTitle = "Select a Surah";
  String _selectedServer = "https://server8.mp3quran.net/afs/"; 
  String _selectedReciterName = "Mishary Alafasy";
  
  Set<String> _favoritedIds = {}; 
  final TextEditingController _searchController = TextEditingController();

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadFavorites();

    _isPlaying = _audioPlayer.state == PlayerState.playing;
    _currentTitle = AudioManager.currentTitle;

    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) setState(() => _duration = d);
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = (state == PlayerState.playing));
    });

    if (AudioManager.hasActiveTrack) _syncExistingPlayer();
  }

  Future<void> _fetchInitialData() async {
    try {
      final sRes = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters?language=en'));
      final rRes = await http.get(Uri.parse('https://mp3quran.net/api/v3/reciters?language=en'));

      if (!mounted) return;

      if (sRes.statusCode == 200 && rRes.statusCode == 200) {
        setState(() {
          _surahs = json.decode(sRes.body)['chapters'];
          _filteredSurahs = _surahs;
          
          _reciters = json.decode(rRes.body)['reciters'];
          _filteredReciters = _reciters;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REFACTORED SEARCH LOGIC (Filters both categories) ---
  void _runFilter(String query) {
    setState(() {
      _filteredSurahs = _surahs.where((s) => 
        s["name_simple"].toLowerCase().contains(query.toLowerCase())).toList();
        
      _filteredReciters = _reciters.where((r) => 
        r["name"].toLowerCase().contains(query.toLowerCase())).toList();
    });
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
    await _audioPlayer.play(UrlSource("$_selectedServer$chapterId.mp3"));
    Future.delayed(const Duration(seconds: 2), () => _syncExistingPlayer());
    String audioUrl = "$_selectedServer$chapterId.mp3";

    try {
      audioHandler.updateMetadata(name, _selectedReciterName);
    } catch (e) {
      debugPrint("AudioHandler not ready yet: $e");
    }
  
  await _audioPlayer.play(UrlSource(audioUrl));  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  void dispose() {
    _durationSub?.cancel(); _positionSub?.cancel(); _playerStateSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Audio Library", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          // FIXED: Search bar is now part of the AppBar for a cleaner look
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                _buildSearchBar(),
                const TabBar(
                  indicatorColor: Colors.blueAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.blueGrey,
                  tabs: [
                    Tab(text: "Surahs"),
                    Tab(text: "Reciters"),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildSurahList(),
                        _buildReciterList(),
                      ],
                    ),
                  ),
                  _buildControlPanel(),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search library...",
          hintStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    return ListView.builder(
      itemCount: _filteredSurahs.length,
      itemBuilder: (context, index) {
        final chapter = _filteredSurahs[index];
        final id = chapter['id'].toString();
        bool isFav = _favoritedIds.contains(id);
        return ListTile(
          leading: Text(id, style: const TextStyle(color: Colors.blueGrey)),
          title: Text(chapter['name_simple'], style: const TextStyle(color: Colors.white)),
          subtitle: Text("Voice: $_selectedReciterName", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.blueGrey),
            onPressed: () => _toggleFavorite(id, chapter['name_simple']),
          ),
          onTap: () => _play(chapter['id'], chapter['name_simple']),
        );
      },
    );
  }

  Widget _buildReciterList() {
    return ListView.builder(
      itemCount: _filteredReciters.length,
      itemBuilder: (context, index) {
        final reciter = _filteredReciters[index];
        bool isSelected = _selectedReciterName == reciter['name'];
        return ListTile(
          leading: Icon(Icons.mic, color: isSelected ? Colors.blueAccent : Colors.blueGrey),
          title: Text(reciter['name'], style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white)),
          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
          onTap: () {
            setState(() {
              _selectedReciterName = reciter['name'];
              _selectedServer = reciter['moshaf'][0]['server'];
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to $_selectedReciterName"), duration: const Duration(seconds: 1)));
          },
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Slider(
            value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
            activeColor: Colors.blueAccent,
            onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            iconSize: 56,
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
            color: Colors.white,
            onPressed: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.resume(),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(String id, String name) async {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;
    final docRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('favorites').doc(id);
    if (_favoritedIds.contains(id)) {
      await docRef.delete();
      setState(() => _favoritedIds.remove(id));
    } else {
      await docRef.set({'name': name, 'id': int.parse(id)});
      setState(() => _favoritedIds.add(id));
    }
  }

  void _syncExistingPlayer() async {
    final d = await _audioPlayer.getDuration();
    final p = await _audioPlayer.getCurrentPosition();
    if (mounted) setState(() {
      _isPlaying = _audioPlayer.state == PlayerState.playing;
      if (d != null) _duration = d;
      if (p != null) _position = p;
    });
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').get();
    if (mounted) setState(() => _favoritedIds = snapshot.docs.map((doc) => doc.id).toSet());
  }
}