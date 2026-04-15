enum ActivityEventType { intervalDidStart, intervalDidEnd, thresholdReached }

enum ShieldAction { primaryButton, secondaryButton }

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
