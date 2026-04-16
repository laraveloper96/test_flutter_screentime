import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models/screen_time_block_screen_config.dart';

export 'models/screen_time_block_screen_config.dart';

const MethodChannel _channel = MethodChannel('flutter_screentime');
const EventChannel _shieldActionChannel =
    EventChannel('flutter_screentime/shield_action');
const EventChannel _activityEventChannel =
    EventChannel('flutter_screentime/activity_event');

enum ShieldAction { primaryButton, secondaryButton }

enum ActivityEventType { intervalDidStart, intervalDidEnd, thresholdReached }

class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.activityName,
    required this.timestamp,
  });
  final ActivityEventType type;
  final String activityName;
  final DateTime timestamp;

  factory ActivityEvent.fromMap(Map<Object?, Object?> map) {
    return ActivityEvent(
      type: ActivityEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityEventType.intervalDidStart,
      ),
      activityName: map['activityName'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((map['timestamp'] as num) * 1000).toInt(),
      ),
    );
  }
}

class ShieldExtension {
  const ShieldExtension();

  Future<void> configureShield(ScreenTimeBlockScreenConfig config) {
    return _channel.invokeMethod<void>('configureShield', config.toMap());
  }

  /// Desbloquea temporalmente las apps bloqueadas durante [duration] y las
  /// vuelve a bloquear automáticamente al vencer el tiempo.
  ///
  /// Llamar después de recibir un evento en [onPermissionRequest] para
  /// conceder acceso temporal al hijo/usuario.
  Future<void> grantTemporaryAccess({required Duration duration}) {
    return _channel.invokeMethod<void>(
      'grantTemporaryAccess',
      duration.inSeconds,
    );
  }

  Future<void> setShieldIcon(Uint8List pngBytes) {
    return _channel.invokeMethod<void>('setShieldIcon', pngBytes);
  }

  Future<void> captureWidgetAsIcon(GlobalKey repaintKey) async {
    final boundary =
        repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('RepaintBoundary not found for the given key.');
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode widget as PNG.');
    }
    await setShieldIcon(byteData.buffer.asUint8List());
  }

  Stream<ShieldAction> onShieldAction() {
    return _shieldActionChannel.receiveBroadcastStream().map((event) {
      return ShieldAction.values.firstWhere(
        (a) => a.name == event as String,
        orElse: () => ShieldAction.primaryButton,
      );
    });
  }

  /// Stream que emite únicamente cuando el usuario pulsa el botón primario
  /// del Shield (caso de uso: "Pedir permiso").
  ///
  /// Equivalente a `onShieldAction().where((a) => a == ShieldAction.primaryButton)`.
  Stream<void> onPermissionRequest() {
    return onShieldAction()
        .where((action) => action == ShieldAction.primaryButton)
        .cast<void>();
  }

  Stream<ActivityEvent> onActivityEvent() {
    return _activityEventChannel.receiveBroadcastStream().map((event) {
      return ActivityEvent.fromMap(event as Map<Object?, Object?>);
    });
  }
}
