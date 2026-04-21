import 'package:flutter/services.dart';

import 'models/screen_time_authorization_status.dart';
import 'models/selected_apps_summary.dart';

const MethodChannel _channel = MethodChannel('flutter_control_parental');

enum FamilyControlsMember { child, individual }

class FamilyControls {
  const FamilyControls();

  Future<ScreenTimeAuthorizationStatus> checkAuthorization() async {
    final status = await _channel.invokeMethod<String>('checkAuthorization');
    return ScreenTimeAuthorizationStatus.fromPlatformValue(status);
  }

  Future<bool> requestNotificationPermission() async {
    final result =
        await _channel.invokeMethod<bool>('requestNotificationPermission');
    return result ?? false;
  }

  Future<ScreenTimeAuthorizationStatus> requestAuthorization({
    // TODO(dev): Use the member parameter to request authorization for the child or individual.
    FamilyControlsMember member = FamilyControlsMember.individual,
  }) async {
    final status = await _channel.invokeMethod<String>(
      'requestAuthorization',
      member.name,
    );
    return ScreenTimeAuthorizationStatus.fromPlatformValue(status);
  }

  Future<void> revokeAuthorization() {
    return _channel.invokeMethod<void>('revokeAuthorization');
  }

  Future<SelectedAppsSummary> selectBlockedApps() async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('selectBlockedApps');
    return SelectedAppsSummary.fromMap(result ?? const {});
  }

  Future<SelectedAppsSummary> getSelectedAppsSummary() async {
    final result = await _channel
        .invokeMapMethod<Object?, Object?>('getSelectedAppsSummary');
    return SelectedAppsSummary.fromMap(result ?? const {});
  }
}
