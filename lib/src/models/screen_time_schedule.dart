import 'package:flutter/material.dart';

class ScreenTimeSchedule {
  const ScreenTimeSchedule({
    required this.start,
    required this.end,
    this.weekdays,
    this.dailyTimeLimit,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final List<int>? weekdays; // 1=Lun…7=Dom
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
          ? Duration(
              seconds: (map['dailyTimeLimitSeconds'] as num).toInt(),
            )
          : null,
    );
  }
}
