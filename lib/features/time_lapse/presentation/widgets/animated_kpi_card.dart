import 'package:flutter/material.dart';

/// KPI card that animates its numeric value smoothly whenever [value] changes
/// (e.g. every playback frame). Uses [TweenAnimationBuilder] so intervening
/// values are interpolated for a video-player-like feel.
class AnimatedKpiCard extends StatelessWidget {
  const AnimatedKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.formatter,
    this.prefix = '',
    this.suffix = '',
    this.trend = 0,
    this.duration = const Duration(milliseconds: 200),
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final String Function(double) formatter;
  final String prefix;
  final String suffix;

  /// -1 down, 0 flat, 1 up (companion to the growth % value).
  final int trend;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .16), color.withValues(alpha: .05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const Spacer(),
              _TrendGlyph(trend: trend, color: color),
            ],
          ),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: value, end: value),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '$prefix${formatter(animated)}$suffix',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendGlyph extends StatelessWidget {
  const _TrendGlyph({required this.trend, required this.color});

  final int trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (trend > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward_rounded, size: 15, color: Colors.green.shade700),
          Text('+', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800)),
        ],
      );
    }
    if (trend < 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_downward_rounded, size: 15, color: Colors.red.shade600),
          Text('−', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w800)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.remove_rounded, size: 15, color: color),
        Text('—', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}