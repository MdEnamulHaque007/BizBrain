import 'package:bizbrain/features/time_lapse/domain/tl_frame.dart';

/// Turns sorted date→value bucket entries into a playback timeline.
///
/// The input must be sorted ascending by [DateTime] (the Time Lapse screen
/// already sorts its grouped buckets). If [cumulative] is true each frame's
/// [TLFrame.total] becomes a running sum of all buckets up to that date.
class TLFrameFactory {
  const TLFrameFactory();

  /// Number of buckets at or below which frames are rebuilt as-is.
  static const int maxFrames = 500;

  List<TLFrame> build(
    List<MapEntry<DateTime, double>> buckets, {
    bool cumulative = false,
  }) {
    if (buckets.length > maxFrames) {
      buckets = _thinned(buckets);
    }
    var running = 0.0;
    final frames = <TLFrame>[];
    for (var i = 0; i < buckets.length; i++) {
      running += buckets[i].value;
      frames.add(
        TLFrame(
          index: i,
          date: buckets[i].key,
          total: cumulative ? running : buckets[i].value,
          count: 1,
        ),
      );
    }
    return frames;
  }

  /// Keeps the timeline bounded for very long ranges by sampling buckets
  /// evenly while preserving the first and last entries.
  List<MapEntry<DateTime, double>> _thinned(
    List<MapEntry<DateTime, double>> buckets,
  ) {
    if (buckets.length <= maxFrames) return buckets;
    final step = buckets.length / (maxFrames - 1);
    final result = <MapEntry<DateTime, double>>[];
    for (var i = 0; i < maxFrames - 1; i++) {
      result.add(buckets[(i * step).floor()]);
    }
    result.add(buckets.last);
    return result;
  }
}