import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../data/music_repository.dart';
import '../../domain/models/lyrics.dart';
import '../../domain/models/track.dart';
import '../theme/app_spacing.dart';
import '../widgets/state_views.dart';

/// Lyrics screen. Lyrics are provider-supplied only — we never scrape them.
/// When a provider has no lyrics we show an honest "Lyrics unavailable"
/// (spec §19).
class LyricsScreen extends StatefulWidget {
  final Track track;
  const LyricsScreen({super.key, required this.track});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  late Future<Lyrics> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MusicRepository>().lyrics(widget.track);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom + 32;

    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: SafeArea(
        bottom: true,
        child: FutureBuilder<Lyrics>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<Lyrics> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return MessageView.fromError(snapshot.error!);
            }
            final Lyrics? lyrics = snapshot.data;
            if (lyrics == null || lyrics.isEmpty) {
              return const MessageView(
                icon: Icons.lyrics_outlined,
                title: 'Lyrics unavailable',
                subtitle:
                    'Lyrics are not supplied for this track. EchoFlow only shows '
                    'licensed lyrics.',
              );
            }
            if (lyrics.isSynced && lyrics.synced.isNotEmpty) {
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                itemCount: lyrics.synced.length,
                itemBuilder: (BuildContext c, int i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    lyrics.synced[i].text,
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
              child: Text(
                lyrics.plain ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Exposed for completeness; the sheet/quality helpers may surface this.
AppException lyricsError(Object e) => toAppException(e);
