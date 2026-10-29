import 'dart:async';

import 'cast_device.dart';
import 'cast_media.dart';

/// Possible states of a cast session.
enum SessionState {
  connecting,
  connected,
  loading,
  playing,
  paused,
  buffering,
  idle,
  disconnected,
}

/// Manages valid state transitions for a cast session.
class SessionStateMachine {
  static const Map<SessionState, Set<SessionState>> _validTransitions = {
    SessionState.disconnected: {SessionState.connecting},
    SessionState.connecting: {
      SessionState.connected,
      SessionState.disconnected,
    },
    SessionState.connected: {SessionState.loading, SessionState.disconnected},
    SessionState.loading: {
      SessionState.playing,
      SessionState.buffering, // receiver may report BUFFERING before PLAYING
      SessionState.paused, // LOAD with autoplay=false
      SessionState.idle, // LOAD failed (IDLE/ERROR) or content ended
      SessionState.disconnected,
    },
    SessionState.playing: {
      SessionState.paused,
      SessionState.buffering,
      SessionState.idle,
      SessionState.loading, // source switching while playing
      SessionState.disconnected,
    },
    SessionState.paused: {
      SessionState.playing,
      SessionState.idle,
      SessionState.loading, // source switching while paused
      SessionState.disconnected,
    },
    SessionState.buffering: {
      SessionState.playing,
      SessionState.loading, // source switching while buffering
      SessionState.paused, // user can pause during buffering
      SessionState.disconnected,
    },
    SessionState.idle: {
      SessionState.loading,
      // The receiver can push a fresh playback state directly from idle —
      // e.g. after a LOAD retry where the stale failure status briefly
      // flipped us to idle before the new attempt's BUFFERING/PLAYING
      // arrives. Allow the recovery transition rather than silently
      // dropping the state update.
      SessionState.buffering,
      SessionState.playing,
      SessionState.paused,
      SessionState.disconnected,
    },
  };

  SessionState _state = SessionState.disconnected;
  final StreamController<SessionState> _controller =
      StreamController<SessionState>.broadcast();

  /// The current state.
  SessionState get state => _state;

  /// Stream of state changes.
  Stream<SessionState> get stateStream => _controller.stream;

  /// Returns true if the transition to [target] is valid from the current state.
  bool canTransitionTo(SessionState target) {
    if (target == SessionState.disconnected) return true;
    return _validTransitions[_state]?.contains(target) ?? false;
  }

  /// Transitions to [target] state. No-op if already in [target].
  /// Throws [StateError] if invalid.
  void transitionTo(SessionState target) {
    if (_state == target) return; // no-op for same state
    if (!canTransitionTo(target)) {
      throw StateError('Invalid transition from $_state to $target');
    }
    _state = target;
    _controller.add(target);
  }

  /// Force-sets the state without validation. For testing only.
  void forceState(SessionState target) {
    _state = target;
    _controller.add(target);
  }

  /// Closes the state stream.
  void dispose() {
    _controller.close();
  }
}

/// Abstract base class for protocol-specific cast sessions.
abstract class CastSession {
  /// The device this session is connected to.
  final CastDevice device;

  /// The state machine managing session lifecycle.
  final SessionStateMachine stateMachine = SessionStateMachine();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Creates a [CastSession] for the given [device].
  CastSession(this.device);

  // -- Getters --

  /// Current session state.
  SessionState get state => stateMachine.state;

  /// Stream of session state changes.
  Stream<SessionState> get stateStream => stateMachine.stateStream;

  /// Current playback position.
  Duration get position => _position;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _positionController.stream;

  /// Current media duration.
  Duration get duration => _duration;

  /// Stream of media duration updates.
  Stream<Duration> get durationStream => _durationController.stream;

  /// Stream of volume changes.
  Stream<double> get volumeStream => _volumeController.stream;

  // -- Update methods for subclasses --

  /// Updates the current playback position.
  void updatePosition(Duration position) {
    _position = position;
    _positionController.add(position);
  }

  /// Updates the current media duration.
  void updateDuration(Duration duration) {
    _duration = duration;
    _durationController.add(duration);
  }

  /// Updates the current volume level.
  void updateVolume(double volume) {
    _volumeController.add(volume);
  }

  // -- Lifecycle --

  /// Connects to the cast device.
  ///
  /// Default implementation transitions directly to connected.
  /// Protocol-specific subclasses override this
  /// to perform their connection handshake.
  Future<void> connect() async {
    stateMachine.transitionTo(SessionState.connecting);
    stateMachine.transitionTo(SessionState.connected);
  }

  // -- Abstract methods --

  /// Loads media onto the cast device.
  Future<void> loadMedia(CastMedia media);

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback.
  Future<void> stop();

  /// Seeks to a position in the media.
  Future<void> seek(Duration position);

  /// Sets the volume level (0.0 to 1.0).
  Future<void> setVolume(double volume);

  /// Sets the active subtitle track.
  Future<void> setSubtitle(CastSubtitle? subtitle);

  /// Disconnects from the cast device.
  Future<void> disconnect();

  /// Disposes all resources.
  void dispose() {
    _positionController.close();
    _durationController.close();
    _volumeController.close();
    stateMachine.dispose();
  }
}
