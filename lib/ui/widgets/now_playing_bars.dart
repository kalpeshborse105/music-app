import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 4-bar dynamic audio spectrum equalizer animation in Neon Cyan (#06B6D4)
/// matching the Stitch Now Playing and Trending indicators.
class NowPlayingBars extends StatefulWidget {
  final bool playing;
  final Color color;
  final double size;

  const NowPlayingBars({
    super.key,
    this.playing = true,
    this.color = AppColors.secondary,
    this.size = 16,
  });

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.playing) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _bar(0.3),
            _bar(0.4),
            _bar(0.3),
            _bar(0.2),
          ],
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final double t = _controller.value;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _bar((0.35 + (t * 0.65)).clamp(0.2, 1.0)),
              _bar((0.90 - (t * 0.60)).clamp(0.2, 1.0)),
              _bar((0.45 + (t * 0.50)).clamp(0.2, 1.0)),
              _bar((0.80 - (t * 0.45)).clamp(0.2, 1.0)),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double factor) => Container(
        width: 2.2,
        height: widget.size * factor,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35),
              blurRadius: 4,
            ),
          ],
        ),
      );
}
