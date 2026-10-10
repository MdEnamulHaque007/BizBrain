import 'package:flutter/foundation.dart';

/// One date bucket on the playback timeline of the Time Lapse report.
///
/// [total] is the quantity summed for this bucket (non-cumulative when
/// cumulative mode is off, running total when on).
@immutable
class TLFrame {
  const TLFrame({
    required this.index,
    required this.date,
    required this.total,
    required this.count,
  });

  final int index;
  final DateTime date;
  final double total;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TLFrame &&
          other.index == index &&
          other.date == date &&
          other.total == total &&
          other.count == count;

  @override
  int get hashCode => Object.hash(index, date, total, count);

  @override
  String toString() =>
      'TLFrame($index: ${date.toIso8601String()} -> $total x$count)';
}