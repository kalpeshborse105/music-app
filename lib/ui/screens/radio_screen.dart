import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/music_repository.dart';
import '../../domain/models/radio_station.dart';
import '../../domain/models/track.dart';
import '../../domain/playback/playback_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/admob_banner_card.dart';
import '../widgets/artwork.dart';
import '../widgets/glass_card.dart';

/// Live radio: Popular / AIR / All, with search + alphabetical All tab.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  List<RadioStation> _all = RadioStation.stations;
  /// Default All so every station shows (Popular / AIR are filters).
  String _tier = 'all'; // private | government | all
  String _state = 'all';
  String _district = 'all';
  String _query = '';
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final List<Map<String, dynamic>> raw = await repo.fetchRadioStations();
      if (!mounted) return;
      setState(() {
        _all = raw.isNotEmpty
            ? raw.map(RadioStation.fromJson).toList()
            : RadioStation.stations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _all = RadioStation.stations;
        _loading = false;
      });
    }
  }

  List<RadioStation> get _filtered {
    Iterable<RadioStation> list = _all;
    if (_tier == 'private') {
      list = list.where((RadioStation s) => s.isPrivate);
    } else if (_tier == 'government') {
      list = list.where((RadioStation s) => !s.isPrivate);
    }
    if (_state != 'all') {
      list = list.where(
        (RadioStation s) => s.state.toLowerCase() == _state.toLowerCase(),
      );
    }
    if (_district != 'all') {
      list = list.where(
        (RadioStation s) =>
            s.district.toLowerCase() == _district.toLowerCase(),
      );
    }
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((RadioStation s) {
        return s.name.toLowerCase().contains(q) ||
            s.tagline.toLowerCase().contains(q) ||
            s.state.toLowerCase().contains(q) ||
            s.district.toLowerCase().contains(q) ||
            s.language.toLowerCase().contains(q) ||
            s.frequency.toLowerCase().contains(q);
      });
    }
    final List<RadioStation> out = list.toList();
    if (_tier == 'all') {
      out.sort(
        (RadioStation a, RadioStation b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      out.sort((RadioStation a, RadioStation b) {
        final int t = (a.isPrivate ? 0 : 1).compareTo(b.isPrivate ? 0 : 1);
        if (t != 0) return t;
        final int st = a.state.compareTo(b.state);
        if (st != 0) return st;
        final int d = a.district.compareTo(b.district);
        if (d != 0) return d;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    return out;
  }

  List<String> get _states {
    final Set<String> s = _all
        .where((RadioStation x) => !x.isPrivate && x.state.isNotEmpty)
        .map((RadioStation x) => x.state)
        .toSet();
    final List<String> list = s.toList()..sort();
    return <String>['all', ...list];
  }

  List<String> get _districts {
    if (_state == 'all') return <String>['all'];
    final Set<String> d = _all
        .where(
          (RadioStation x) =>
              !x.isPrivate &&
              x.state.toLowerCase() == _state.toLowerCase() &&
              x.district.isNotEmpty,
        )
        .map((RadioStation x) => x.district)
        .toSet();
    final List<String> list = d.toList()..sort();
    return <String>['all', ...list];
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackController playback = context.watch<PlaybackController>();
    final Track? currentTrack = playback.snapshot.track;
    final bool isPlaying = playback.snapshot.playing;
    final List<RadioStation> stations = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.neonCyan,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: const Text(
                  'Beats Radio Live',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                actions: <Widget>[
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (String v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: AppColors.neonCyan,
                    decoration: InputDecoration(
                      hintText: 'Search stations, city, language…',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: <Widget>[
                      _tierChip('Popular', 'private'),
                      const SizedBox(width: 8),
                      _tierChip('Akashvani', 'government'),
                      const SizedBox(width: 8),
                      _tierChip('All', 'all'),
                    ],
                  ),
                ),
              ),
              if (_tier != 'private')
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _states.map((String st) {
                        final bool selected = _state == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(st == 'all' ? 'All states' : st),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _state = st;
                                _district = 'all';
                              });
                            },
                            selectedColor:
                                AppColors.neonCyan.withValues(alpha: 0.22),
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.neonCyan
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.surfaceContainerHighest,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.neonCyan
                                  : Colors.white12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              if (_tier != 'private' && _districts.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: _districts.map((String d) {
                          final bool selected = _district == d;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(d == 'all' ? 'All districts' : d),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _district = d),
                              selectedColor: AppColors.electricViolet
                                  .withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 11.5,
                              ),
                              backgroundColor:
                                  AppColors.surfaceContainerHighest,
                              side: BorderSide(
                                color: selected
                                    ? AppColors.electricViolet
                                    : Colors.white10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (stations.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No stations match your search',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final RadioStation station = stations[index];
                        final bool playing =
                            currentTrack?.id == 'radio:${station.id}' &&
                            isPlaying;
                        final bool loaded =
                            currentTrack?.id == 'radio:${station.id}';
                        final String meta = <String>[
                          if (station.district.isNotEmpty) station.district,
                          if (station.state.isNotEmpty) station.state,
                          station.language.toUpperCase(),
                        ].join(' • ');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: EchoGlassCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: 16,
                            borderColor: loaded
                                ? AppColors.neonCyan.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.06),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (playing) {
                                  playback.pause();
                                } else {
                                  playback.playTrack(station.toTrack());
                                }
                              },
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: station.isPrivate
                                            ? const <Color>[
                                                Color(0xFFFF6A00),
                                                Color(0xFFE11D48),
                                              ]
                                            : const <Color>[
                                                Color(0xFF0B3D2E),
                                                Color(0xFF138808),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: (station.isPrivate
                                                  ? const Color(0xFFFF6A00)
                                                  : const Color(0xFF138808))
                                              .withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Artwork(
                                        url: station.artworkUrl,
                                        size: 54,
                                        radius: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          station.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: loaded
                                                ? AppColors.neonCyan
                                                : Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          meta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: playing
                                          ? AppColors.neonCyan
                                          : AppColors.surfaceContainerHighest,
                                    ),
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: playing
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: stations.length,
                    ),
                  ),
                ),
              // Banner sits in the scroll feed above mini-player padding — never overlays playback.
              const SliverToBoxAdapter(
                child: AdMobBannerCard(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tierChip(String label, String value) {
    final bool selected = _tier == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tier = value;
          if (value != 'government') {
            _state = 'all';
            _district = 'all';
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppColors.neonCyan.withValues(alpha: 0.18)
                : AppColors.surfaceContainerHighest,
            border: Border.all(
              color: selected ? AppColors.neonCyan : Colors.white10,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.neonCyan : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
