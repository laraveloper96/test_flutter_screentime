import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('flutter_control_parental');

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

  Future<void> setDenyAppRemoval(bool deny) {
    return _channel.invokeMethod<void>('setDenyAppRemoval', deny);
  }
}
