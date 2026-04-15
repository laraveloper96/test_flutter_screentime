enum ScreenTimeAuthorizationStatus {
  notDetermined('notDetermined'),
  denied('denied'),
  approved('approved');

  const ScreenTimeAuthorizationStatus(this.platformValue);
  final String platformValue;

  static ScreenTimeAuthorizationStatus fromPlatformValue(String? value) {
    return values.firstWhere(
      (s) => s.platformValue == value,
      orElse: () => ScreenTimeAuthorizationStatus.notDetermined,
    );
  }
}
