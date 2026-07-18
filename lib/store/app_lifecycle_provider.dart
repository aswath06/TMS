import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart' as tripzo_user_store;

/// A global provider that holds the current AppLifecycleState.
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// A root observer widget that updates the global appLifecycleProvider
class AppLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  
  const AppLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver> with WidgetsBindingObserver {
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If the app starts in foreground, start the session immediately.
    _sessionStartTime = DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).state = state;

    if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_sessionStartTime != null) {
        final durationSeconds = DateTime.now().difference(_sessionStartTime!).inSeconds;
        _sessionStartTime = null; // Reset
        if (durationSeconds > 0) {
          _syncUsageToBackend(durationSeconds);
        }
      }
    }
  }

  Future<void> _syncUsageToBackend(int seconds) async {
    try {
      final token = await tripzo_user_store.UserStore.getToken();
      if (token == null || token.isEmpty) return;

      final deviceInfo = DeviceInfoPlugin();
      String? deviceModel;
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
      }

      final url = Uri.parse("\${ApiConstants.baseUrl}/user/usage-sync");
      await http.post(
        url,
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({
          "duration_seconds": seconds,
          if (deviceModel != null) "device_model": deviceModel,
        }),
      );
    } catch (e) {
      debugPrint("Failed to sync usage: \$e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
