import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('flutter_screentime');

class ManagedSettings {
  const ManagedSettings();

  Future<void> setSharedContainerId(String appGroupId) {
    return _channel.invokeMethod<void>('setSharedContainerId', appGroupId);
  }

  Future<void> startBlocking() {
    return _channel.invokeMethod<void>('startBlocking');
  }

  Future<void> stopBlocking() {
    return _channel.invokeMethod<void>('stopBlocking');
  }

  Future<bool> getBlockingStatus() async {
    final result = await _channel.invokeMethod<bool>('getBlockingStatus');
    return result ?? false;
  }
}
