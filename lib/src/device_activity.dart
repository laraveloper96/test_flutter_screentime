import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('flutter_control_parental');

class ScreenTimeSchedule {
  const ScreenTimeSchedule({
    required this.start,
    required this.end,
    this.weekdays,
    this.dailyTimeLimit,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final List<int>? weekdays; // 1=Lun…7=Dom, null = todos los días
  final Duration? dailyTimeLimit;

  Map<String, Object?> toMap() => {
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
    'weekdays': weekdays,
    'dailyTimeLimitSeconds': dailyTimeLimit?.inSeconds,
  };

  factory ScreenTimeSchedule.fromMap(Map<Object?, Object?> map) {
    return ScreenTimeSchedule(
      start: TimeOfDay(
        hour: (map['startHour'] as num).toInt(),
        minute: (map['startMinute'] as num).toInt(),
      ),
      end: TimeOfDay(
        hour: (map['endHour'] as num).toInt(),
        minute: (map['endMinute'] as num).toInt(),
      ),
      weekdays: (map['weekdays'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      dailyTimeLimit: map['dailyTimeLimitSeconds'] != null
          ? Duration(seconds: (map['dailyTimeLimitSeconds'] as num).toInt())
          : null,
    );
  }
}

class DeviceActivity {
  const DeviceActivity();

  Future<void> setSchedule(ScreenTimeSchedule schedule) {
    return _channel.invokeMethod<void>('setSchedule', schedule.toMap());
  }

  Future<ScreenTimeSchedule?> getSchedule() async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('getSchedule');
    if (result == null || result.isEmpty) return null;
    return ScreenTimeSchedule.fromMap(result);
  }

  Future<void> clearSchedule() {
    return _channel.invokeMethod<void>('clearSchedule');
  }

  Future<void> startMonitoring() {
    return _channel.invokeMethod<void>('startMonitoring');
  }

  Future<void> stopMonitoring() {
    return _channel.invokeMethod<void>('stopMonitoring');
  }
}
