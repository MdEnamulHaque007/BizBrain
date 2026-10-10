import 'dart:async';

import 'package:bizbrain/features/time_lapse/domain/tl_frame.dart';
import 'package:flutter/foundation.dart';

/// Drives frame-by-frame playback of the Time Lapse chart.
///
/// Plain [ChangeNotifier] created by the screen (disposed with it). A
/// [Timer.periodic] advances the frame index every [tick]; playback stops
/// automatically at the last frame.
class PlaybackController extends ChangeNotifier {
  PlaybackController({this.tick = const Duration(milliseconds: 200)});

  final Duration tick;

  final List<TLFrame> _frames = <TLFrame>[];
  int _index = 0;
  bool _playing = false;
  Timer? _timer;

  bool get isPlaying => _playing;
  int get index => _index;
  int get length => _frames.length;
  bool get isEnabled => _frames.length > 1;

  List<TLFrame> get frames => List.unmodifiable(_frames);

  TLFrame? get current =>
      _frames.isEmpty ? null : _frames[_index.clamp(0, length - 1)];

  /// Progress in the range 0..1 (0 when fewer than 2 frames).
  double get progress =>
      length < 2 ? 0 : _index / (length - 1);

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
    _timer = Timer.periodic(tick, (_) => _advance());
  }

  void pause() {
    if (!_playing) return;
    _stopTimer();
    _playing = false;
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  void restart() {
    _index = 0;
    if (_playing) {
      _timer?.cancel();
      _timer = Timer.periodic(tick, (_) => _advance());
    }
    notifyListeners();
  }

  void seekTo(int frameIndex) {
    final next = frameIndex.clamp(0, length - 1);
    if (next == _index) return;
    _index = next;
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