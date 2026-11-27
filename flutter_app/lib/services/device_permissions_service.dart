import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevicePermissionSnapshot {
  final bool notificationsGranted;
  final bool batteryOptimizationIgnored;
  final bool bluetoothGranted;
  final bool microphoneGranted;
  final bool overlayGranted;
  final int sdkInt;
  final bool loaded;

  const DevicePermissionSnapshot({
    this.notificationsGranted = true,
    this.batteryOptimizationIgnored = true,
    this.bluetoothGranted = true,
    this.microphoneGranted = false,
    this.overlayGranted = true,
    this.sdkInt = 34,
    this.loaded = false,
  });

  bool get backgroundReady => notificationsGranted && batteryOptimizationIgnored;

  bool get dynamicIslandOutsideAppReady =>
      notificationsGranted && overlayGranted;

  int get missingCount {
    var count = 0;
    if (!notificationsGranted) count += 1;
    if (!batteryOptimizationIgnored) count += 1;
    if (!bluetoothGranted) count += 1;
    if (!overlayGranted) count += 1;
    return count;
  }

  DevicePermissionSnapshot copyWith({
    bool? notificationsGranted,
    bool? batteryOptimizationIgnored,
    bool? bluetoothGranted,
    bool? microphoneGranted,
    bool? overlayGranted,
    int? sdkInt,
    bool? loaded,
  }) {
    return DevicePermissionSnapshot(
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      batteryOptimizationIgnored:
          batteryOptimizationIgnored ?? this.batteryOptimizationIgnored,
      bluetoothGranted: bluetoothGranted ?? this.bluetoothGranted,
      microphoneGranted: microphoneGranted ?? this.microphoneGranted,
      overlayGranted: overlayGranted ?? this.overlayGranted,
      sdkInt: sdkInt ?? this.sdkInt,
      loaded: loaded ?? this.loaded,
    );
  }
}

class DevicePermissionsNotifier extends StateNotifier<DevicePermissionSnapshot> {
  static const MethodChannel _channel =
      MethodChannel('com.lunarellys.music/permissions');

  void Function(String action)? _islandActionHandler;

  DevicePermissionsNotifier() : super(const DevicePermissionSnapshot()) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDynamicIslandAction') {
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) {
          _islandActionHandler?.call(action);
        }
      }
    });
    refresh();
  }

  void setDynamicIslandActionHandler(void Function(String action)? handler) {
    _islandActionHandler = handler;
  }

  Future<void> refresh() async {
    if (!Platform.isAndroid) {
      state = state.copyWith(loaded: true);
      return;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('checkStatuses');
      if (raw == null) return;
      state = DevicePermissionSnapshot(
        notificationsGranted: raw['notificationsGranted'] == true,
        batteryOptimizationIgnored: raw['batteryOptimizationIgnored'] == true,
        bluetoothGranted: raw['bluetoothGranted'] == true,
        microphoneGranted: raw['microphoneGranted'] == true,
        overlayGranted: raw['overlayGranted'] == true,
        sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 34,
        loaded: true,
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission') ??
              false;
      await refresh();
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final opened =
          await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
      Future<void>.delayed(const Duration(milliseconds: 900), refresh);
      return opened;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestBluetooth() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestBluetoothPermission') ??
              false;
      await refresh();
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestMicrophone() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestMicrophonePermission') ??
              false;
      await refresh();
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      final opened = await _channel
              .invokeMethod<bool>('requestBatteryOptimizationExemption') ??
          false;
      Future<void>.delayed(const Duration(milliseconds: 900), refresh);
      return opened;
    } catch (_) {
      return false;
    }
  }

  Future<void> updatePlaybackAndLyrics({
    required bool enabled,
    required bool alwaysVisible,
    required bool systemOverlayEnabled,
    required String positionMode,
    required bool lockScreenLyricsEnabled,
    required bool hasTrack,
    required String trackId,
    required String title,
    required String artist,
    required String artUrl,
    required bool isPlaying,
    required int positionMs,
    required int durationMs,
    required int lyricsOffsetMs,
    required int accentColor,
    List<Map<String, dynamic>>? lyrics,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('updatePlaybackAndLyrics', {
        'enabled': enabled,
        'alwaysVisible': alwaysVisible,
        'systemOverlayEnabled': systemOverlayEnabled,
        'positionMode': positionMode,
        'lockScreenLyricsEnabled': lockScreenLyricsEnabled,
        'hasTrack': hasTrack,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'artUrl': artUrl,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'lyricsOffsetMs': lyricsOffsetMs,
        'accentColor': accentColor,
        if (lyrics != null) 'lyrics': lyrics,
      });
    } catch (_) {}
  }

  Future<void> updateSystemDynamicIsland({
    required bool enabled,
    required bool alwaysVisible,
    required bool systemOverlayEnabled,
    required bool hasTrack,
    required String title,
    required String artist,
    required bool isPlaying,
    required int accentColor,
  }) async {
    await updatePlaybackAndLyrics(
      enabled: enabled,
      alwaysVisible: alwaysVisible,
      systemOverlayEnabled: systemOverlayEnabled,
      positionMode: 'below',
      lockScreenLyricsEnabled: true,
      hasTrack: hasTrack,
      trackId: '',
      title: title,
      artist: artist,
      artUrl: '',
      isPlaying: isPlaying,
      positionMs: 0,
      durationMs: 0,
      lyricsOffsetMs: 0,
      accentColor: accentColor,
    );
  }

  Future<bool> openLockScreenPreview() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openLockScreenPreview') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> hideSystemDynamicIsland() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('hideSystemDynamicIsland');
    } catch (_) {}
  }

  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }
}

final devicePermissionsProvider = StateNotifierProvider<
    DevicePermissionsNotifier, DevicePermissionSnapshot>((ref) {
  return DevicePermissionsNotifier();
});
