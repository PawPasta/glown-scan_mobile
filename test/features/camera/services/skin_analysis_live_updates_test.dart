import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/camera/services/skin_analysis_live_updates.dart';

void main() {
  test(
    'connects to the namespace with auth and filters status events',
    () async {
      final factory = _FakeSocketFactory();
      final updates = SkinAnalysisLiveUpdates(
        apiOrigin: Uri.parse('https://api.glownscan.xyz/v1/'),
        accessTokenProvider: () async => 'access-token',
        socketFactory: factory,
      );
      addTearDown(updates.close);
      final received = <SkinAnalysisLiveEvent>[];
      final subscription = updates.watch('session-a').listen(received.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(
        factory.origins.single,
        Uri.parse('https://api.glownscan.xyz/v1/'),
      );
      expect(factory.tokens.single, 'access-token');
      expect(factory.sockets.single.connected, isTrue);

      factory.sockets.single.emit('analysis.status', {
        'sessionId': 'session-b',
        'status': 'RUNNING',
      });
      factory.sockets.single.emit('analysis.status', {
        'sessionId': 'session-a',
        'status': 'SUCCEEDED',
        'occurredAt': '2026-11-16T00:00:00.000Z',
      });
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.sessionId, 'session-a');
      expect(received.single.status, 'SUCCEEDED');
    },
  );

  test(
    'reconnects with the latest access token and requests reconciliation',
    () async {
      final factory = _FakeSocketFactory();
      var calls = 0;
      final updates = SkinAnalysisLiveUpdates(
        apiOrigin: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async =>
            ++calls == 1 ? 'old-token' : 'new-token',
        socketFactory: factory,
        reconnectDelay: Duration.zero,
      );
      addTearDown(updates.close);
      final received = <SkinAnalysisLiveEvent>[];
      final subscription = updates.watch('session-a').listen(received.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      factory.sockets.first.emit('connect', null);
      factory.sockets.first.emit('disconnect', null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      factory.sockets.last.emit('connect', null);
      await Future<void>.delayed(Duration.zero);

      expect(factory.tokens, ['old-token', 'new-token']);
      expect(received.single.reconciliationRequired, isTrue);
    },
  );
}

class _FakeSocketFactory implements SkinAnalysisSocketFactory {
  final origins = <Uri>[];
  final tokens = <String>[];
  final sockets = <_FakeSocket>[];

  @override
  SkinAnalysisSocket create({required Uri apiOrigin, required String token}) {
    origins.add(apiOrigin);
    tokens.add(token);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

class _FakeSocket implements SkinAnalysisSocket {
  final handlers = <String, void Function(Object?)>{};
  bool connected = false;
  bool disposed = false;

  @override
  void connect() => connected = true;

  @override
  void dispose() => disposed = true;

  void emit(String event, Object? data) => handlers[event]?.call(data);

  @override
  void on(String event, void Function(Object? event) handler) {
    handlers[event] = handler;
  }
}
