import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_config.dart';
import '../../../core/storage/auth_session_storage.dart';

class SkinAnalysisLiveEvent {
  const SkinAnalysisLiveEvent.status({
    required this.sessionId,
    required this.status,
    this.errorCode,
    this.occurredAt,
  }) : reconciliationRequired = false;

  const SkinAnalysisLiveEvent.reconciliationNeeded()
    : sessionId = null,
      status = null,
      errorCode = null,
      occurredAt = null,
      reconciliationRequired = true;

  final String? sessionId;
  final String? status;
  final String? errorCode;
  final String? occurredAt;
  final bool reconciliationRequired;
}

abstract interface class SkinAnalysisLiveUpdatesContract {
  Stream<SkinAnalysisLiveEvent> watch(String sessionId);

  void close();
}

abstract interface class SkinAnalysisSocket {
  void on(String event, void Function(Object? event) handler);

  void connect();

  void dispose();
}

abstract interface class SkinAnalysisSocketFactory {
  SkinAnalysisSocket create({required Uri apiOrigin, required String token});
}

class SkinAnalysisLiveUpdates implements SkinAnalysisLiveUpdatesContract {
  SkinAnalysisLiveUpdates({
    Uri? apiOrigin,
    Future<String?> Function()? accessTokenProvider,
    SkinAnalysisSocketFactory? socketFactory,
    this.reconnectDelay = const Duration(seconds: 1),
  }) : _configuredApiOrigin = apiOrigin,
       _accessTokenProvider =
           accessTokenProvider ?? AuthSessionStorage().readAccessToken,
       _socketFactory = socketFactory ?? const _SocketIoFactory();

  final Uri? _configuredApiOrigin;
  final Future<String?> Function() _accessTokenProvider;
  final SkinAnalysisSocketFactory _socketFactory;
  final Duration reconnectDelay;
  final _events = StreamController<SkinAnalysisLiveEvent>.broadcast();
  SkinAnalysisSocket? _socket;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _hasConnected = false;
  int _watchers = 0;
  static const _validStatuses = {'QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED'};

  Uri get _apiOrigin => _configuredApiOrigin ?? AppConfig.apiBaseUri;

  @override
  Stream<SkinAnalysisLiveEvent> watch(String sessionId) async* {
    _watchers++;
    unawaited(_connect());
    try {
      yield* _events.stream.where(
        (event) => event.reconciliationRequired || event.sessionId == sessionId,
      );
    } finally {
      _watchers--;
      if (_watchers == 0) _disposeSocket();
    }
  }

  Future<void> _connect() async {
    if (_closed || _watchers == 0 || _socket != null) return;
    String? token;
    try {
      token = await _accessTokenProvider();
    } catch (_) {
      return;
    }
    if (_closed || _watchers == 0 || token == null || token.isEmpty) return;

    final SkinAnalysisSocket socket;
    try {
      socket = _socketFactory.create(apiOrigin: _apiOrigin, token: token);
    } catch (_) {
      return;
    }
    _socket = socket;
    socket
      ..on('analysis.status', _onStatus)
      ..on(
        'analysis.ready',
        (_) => _events.add(const SkinAnalysisLiveEvent.reconciliationNeeded()),
      )
      ..on('connect', (_) {
        if (_hasConnected) {
          _events.add(const SkinAnalysisLiveEvent.reconciliationNeeded());
        }
        _hasConnected = true;
      })
      ..on('disconnect', (_) => _reconnect(socket))
      ..on('connect_error', (_) => _reconnect(socket))
      ..connect();
  }

  void _onStatus(Object? value) {
    if (value is! Map) return;
    final sessionId = value['sessionId'];
    final status = value['status'];
    if (sessionId is! String ||
        status is! String ||
        !_validStatuses.contains(status)) {
      return;
    }
    _events.add(
      SkinAnalysisLiveEvent.status(
        sessionId: sessionId,
        status: status,
        errorCode: value['errorCode'] as String?,
        occurredAt: value['occurredAt'] as String?,
      ),
    );
  }

  void _reconnect(SkinAnalysisSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    socket.dispose();
    if (_closed || _watchers == 0 || _reconnectTimer != null) return;
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _disposeSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.dispose();
    _socket = null;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _disposeSocket();
    unawaited(_events.close());
  }
}

class _SocketIoFactory implements SkinAnalysisSocketFactory {
  const _SocketIoFactory();

  @override
  SkinAnalysisSocket create({required Uri apiOrigin, required String token}) {
    final origin = apiOrigin.replace(path: '', query: null, fragment: null);
    return _SocketIoSocket(
      io.io(
        '${origin.toString()}/skin-analysis',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .disableReconnection()
            .build(),
      ),
    );
  }
}

class _SocketIoSocket implements SkinAnalysisSocket {
  const _SocketIoSocket(this._socket);

  final io.Socket _socket;

  @override
  void connect() => _socket.connect();

  @override
  void dispose() => _socket.dispose();

  @override
  void on(String event, void Function(Object? event) handler) =>
      _socket.on(event, handler);
}
