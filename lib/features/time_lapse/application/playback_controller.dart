import 'dart:async';

import 'package:bizbrain/features/time_lapse/domain/tl_frame.dart';
import 'package:flutter/foundation.dart';

/// Drives frame-by-frame playback of the Time Lapse chart.
///
/// Plain [ChangeNotifier] created by the screen (disposed with it). A
/// [Timer.periodic] advances the frame index at an interval derived from the
/// selected total animation [durationSeconds] (not the wall-clock speed) and
/// [speed]. Playback stops automatically at the last frame.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    this.defaultDurationSeconds = 60,
    this.defaultSpeed = 1.0,
  })  : _durationSeconds = defaultDurationSeconds,
        _speed = defaultSpeed;

  final int defaultDurationSeconds;
  final double defaultSpeed;

  final List<TLFrame> _frames = <TLFrame>[];
  int _index = 0;
  bool _playing = false;
  Timer? _timer;
  int _durationSeconds;
  double _speed;

  bool get isPlaying => _playing;
  int get index => _index;
  int get length => _frames.length;
  bool get isEnabled => _frames.length > 1;
  int get durationSeconds => _durationSeconds;
  double get speed => _speed;

  List<TLFrame> get frames => List.unmodifiable(_frames);

  TLFrame? get current =>
      _frames.isEmpty ? null : _frames[_index.clamp(0, length - 1)];

  /// Progress in the range 0..1 (0 when fewer than 2 frames).
  double get progress => length < 2 ? 0 : _index / (length - 1);

  /// Number of frame advances between the first and last frames (>= 1).
  int get _slots => length < 2 ? 1 : length - 1;

  /// Per-advance timer interval in milliseconds.
  double get intervalMs =>
      (_durationSeconds * 1000 / _slots) / _speed;

  /// Watch-style media position and remaining time across the whole clip.
  Duration get elapsed =>
      Duration(milliseconds: (_durationSeconds * 1000 * progress).round());

  Duration get remaining =>
      Duration(milliseconds: (_durationSeconds * 1000 * (1 - progress)).round());

  /// Replaces the timeline and restarts playback at the first frame.
  void load(List<TLFrame> frames) {
    _frames
      ..clear()
      ..addAll(frames);
    _index = 0;
    _stopTimer();
    notifyListeners();
  }

  void play() {
    if (!isEnabled || _playing) return;
    _playing = true;
    notifyListeners();
    _startTimer();
  }

  void pause() {
    if (!_playing) return;
    _stopTimer();
    _playing = false;
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  /// Jumps back to the first frame and starts playing again.
  void restart() {
    _index = 0;
    if (_playing) _startTimer();
    notifyListeners();
  }

  /// Pauses and returns to the first frame (initial state).
  void reset() {
    pause();
    _index = 0;
    notifyListeners();
  }

  void seekTo(int frameIndex) {
    final next = frameIndex.clamp(0, length - 1);
    if (next == _index) return;
    _index = next;
    notifyListeners();
  }

  void setSpeed(double value) {
    if (value <= 0 || value == _speed) return;
    _speed = value;
    if (_playing) _startTimer();
    notifyListeners();
  }

  void setDuration(int seconds) {
    if (seconds <= 0 || seconds == _durationSeconds) return;
    _durationSeconds = seconds;
    if (_playing) _startTimer();
    notifyListeners();
  }

  void _advance() {
    if (_index >= length - 1) {
      pause();
      return;
    }
    _index++;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: intervalMs.round().clamp(1, 1 << 30)),
      (_) => _advance(),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}