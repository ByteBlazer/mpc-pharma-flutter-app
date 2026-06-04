import 'dart:async';

class AuthManager {
  AuthManager._();

  static final AuthManager instance = AuthManager._();

  final _controller = StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get authEvents => _controller.stream;

  void notifySessionExpired() {
    if (!_controller.isClosed) {
      _controller.add(AuthEvent.expired);
    }
  }

  void dispose() {
    _controller.close();
  }
}

enum AuthEvent { expired }
