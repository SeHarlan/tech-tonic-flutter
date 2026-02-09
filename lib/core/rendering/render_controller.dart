import 'package:flutter/scheduler.dart';

/// Drives the render loop using a [Ticker].
///
/// Calls [onTick] each frame with the elapsed time in seconds.
/// Can be paused/resumed and tracks actual FPS.
class RenderController {
  final void Function(double elapsedSeconds) onTick;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double _time = 0;
  int _frameCount = 0;
  double _fps = 0;

  // FPS tracking
  int _fpsFrameCount = 0;
  Duration _fpsLastSample = Duration.zero;
  static const _fpsSampleInterval = Duration(seconds: 1);

  bool _paused = false;

  RenderController({required this.onTick});

  double get time => _time;
  int get frameCount => _frameCount;
  double get fps => _fps;
  bool get isPaused => _paused;

  /// Start the render loop. Must be called with a [TickerProvider].
  void start(TickerProvider provider) {
    _ticker?.dispose();
    _ticker = provider.createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (_paused) {
      _lastElapsed = elapsed;
      return;
    }

    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;

    _time += dt;
    _frameCount++;
    _fpsFrameCount++;

    // Update FPS measurement
    final sinceSample = elapsed - _fpsLastSample;
    if (sinceSample >= _fpsSampleInterval) {
      _fps = _fpsFrameCount / (sinceSample.inMicroseconds / 1e6);
      _fpsFrameCount = 0;
      _fpsLastSample = elapsed;
    }

    onTick(_time);
  }

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  void togglePause() {
    _paused = !_paused;
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}
