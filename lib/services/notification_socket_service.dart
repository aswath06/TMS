import 'package:socket_io_client/socket_io_client.dart' as IO;

class NotificationSocketService {
  IO.Socket? socket;

  void connect({
    required String socketBaseUrl,
    required String token,
    required Function(Map<String, dynamic>) onNewNotification,
    Function()? onConnected,
    Function()? onDisconnected,
    Function(dynamic)? onError,
  }) {
    socket = IO.io(
      socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'X-Tunnel-Skip-Anti-Phishing-Page': 'true'})
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      onConnected?.call();
    });

    socket!.on('notification:new', (data) {
      if (data is Map) {
        onNewNotification(Map<String, dynamic>.from(data));
      }
    });

    socket!.onDisconnect((_) {
      onDisconnected?.call();
    });

    socket!.onConnectError((error) {
      onError?.call(error);
    });

    socket!.onError((error) {
      onError?.call(error);
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
  }
}
