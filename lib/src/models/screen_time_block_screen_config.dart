enum ShieldBackgroundBlurStyle { dark, light, none }

class ScreenTimeBlockScreenConfig {
  const ScreenTimeBlockScreenConfig({
    this.title,
    this.subtitle,
    this.primaryButtonLabel,
    this.primaryButtonColorHex,
    this.primaryButtonTextColorHex,
    this.secondaryButtonLabel,
    this.backgroundColorHex,
    this.backgroundBlurStyle,
  });

  final String? title;
  final String? subtitle;
  final String? primaryButtonLabel;
  final String? primaryButtonColorHex;
  final String? primaryButtonTextColorHex;
  final String? secondaryButtonLabel;
  final String? backgroundColorHex;
  final ShieldBackgroundBlurStyle? backgroundBlurStyle;

  Map<String, Object?> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'primaryButtonLabel': primaryButtonLabel,
        'primaryButtonColorHex': primaryButtonColorHex,
        'primaryButtonTextColorHex': primaryButtonTextColorHex,
        'secondaryButtonLabel': secondaryButtonLabel,
        'backgroundColorHex': backgroundColorHex,
        'backgroundBlurStyle': backgroundBlurStyle?.name,
      };
}
