import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/services/youtube_api_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  List<ApiTrack> _results = [];
  ApiTrack? _nowPlaying;
  bool _isSearching = false;
  bool _isLoadingStream = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Toggle between JioSaavn (Bollywood/free) and YouTube
  String _selectedSource = 'jiosaavn';

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _results = [];
    });

    List<ApiTrack> results = [];

    if (_selectedSource == 'jiosaavn') {
      results = await MusicApiService.searchJioSaavn(query, limit: 20);
    } else {
      // YouTube search: get list first, then for each we'd need to call /stream
      // We'll show results as searchable list and load stream on tap
      final raw = await MusicApiService.searchYouTube(query, limit: 10);
      results = raw.map((t) => ApiTrack.fromYouTube(t, '')).toList();
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _playTrack(ApiTrack track) async {
    if (_isLoadingStream) return;

    setState(() {
      _isLoadingStream = true;
      _nowPlaying = track;
    });

    await _player.stop();

    try {
      String? streamUrl = track.streamUrl;

      // For YouTube tracks from search (no pre-loaded URL), fetch stream now
      if (track.source == 'youtube' && streamUrl.isEmpty) {
        final ytUrl = 'https://www.youtube.com/watch?v=${track.id}';
        final info = await MusicApiService.getYouTubeStreamUrl(ytUrl);
        streamUrl = info?['stream_url'] as String?;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Could not load stream. Try another song.')),
          );
          setState(() => _isLoadingStream = false);
        }
        return;
      }

      await _player.setUrl(streamUrl);
      await _player.play();

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isLoadingStream = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing: $e')),
        );
        setState(() => _isLoadingStream = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Kalpkrut Beats', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Source Toggle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text('Source:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('🎵 JioSaavn'),
                  selected: _selectedSource == 'jiosaavn',
                  onSelected: (_) => setState(() => _selectedSource = 'jiosaavn'),
                  selectedColor: const Color(0xFF6C63FF),
                  labelStyle: TextStyle(
                    color: _selectedSource == 'jiosaavn' ? Colors.white : Colors.white60,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('▶️ YouTube'),
                  selected: _selectedSource == 'youtube',
                  onSelected: (_) => setState(() => _selectedSource = 'youtube'),
                  selectedColor: Colors.red.shade700,
                  labelStyle: TextStyle(
                    color: _selectedSource == 'youtube' ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          // ── Search Bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _selectedSource == 'jiosaavn'
                          ? 'Search Bollywood, English, Hindi...'
                          : 'Paste YouTube URL or search...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E1E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSearching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
          // ── Track List ────────────────────────────────────────────────────
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note, size: 72, color: Colors.white12),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSource == 'jiosaavn'
                              ? 'Search songs, artists, albums\non JioSaavn'
                              : 'Search YouTube music',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final track = _results[index];
                      final isNowPlaying = _nowPlaying?.id == track.id;
                      return ListTile(
                        key: ValueKey(track.id),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: track.thumbnail.isNotEmpty
                              ? Image.network(
                                  track.thumbnail,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 52,
                                    height: 52,
                                    color: const Color(0xFF2A2A3E),
                                    child: const Icon(Icons.music_note, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFF2A2A3E),
                                  child: const Icon(Icons.music_note, color: Colors.white38),
                                ),
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            color: isNowPlaying ? const Color(0xFF6C63FF) : Colors.white,
                            fontWeight: isNowPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isNowPlaying && _isLoadingStream
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
                              )
                            : Icon(
                                isNowPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: isNowPlaying ? const Color(0xFF6C63FF) : Colors.white38,
                                size: 32,
                              ),
                        onTap: () {
                          if (isNowPlaying) {
                            _togglePlayPause();
                          } else {
                            _playTrack(track);
                          }
                        },
                      );
                    },
                  ),
          ),
          // ── Now Playing Bar ───────────────────────────────────────────────
          if (_nowPlaying != null)
            Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_nowPlaying!.thumbnail.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _nowPlaying!.thumbnail,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFF2A2A3E),
                              child: const Icon(Icons.music_note, color: Colors.white38, size: 20),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nowPlaying!.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _nowPlaying!.artist,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _isLoadingStream
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
                            )
                          : IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: const Color(0xFF6C63FF),
                                size: 40,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Expanded(
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: (value) {
                            _player.seek(Duration(milliseconds: (value * _duration.inMilliseconds).round()));
                          },
                          activeColor: const Color(0xFF6C63FF),
                          inactiveColor: Colors.white12,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
