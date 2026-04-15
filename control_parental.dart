// =============================================================
// PLAN DE API — flutter_screentime (iOS)
// Este archivo define la arquitectura de clases del plugin.
// Cada clase refleja un framework nativo de Apple.
// =============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';

// -------------------------------------------------------------
// MODELOS DE DATOS
// -------------------------------------------------------------

/// Estado de autorización de FamilyControls.
enum ScreenTimeAuthorizationStatus {
  notDetermined, // El usuario aún no ha respondido
  denied, // El usuario denegó o revocó
  approved, // Autorización concedida
}

/// Botón que el usuario tocó en la pantalla de bloqueo (shield).
enum ShieldAction {
  primaryButton, // Botón principal (ej. "Pedir más tiempo")
  secondaryButton, // Botón secundario (ej. "Cancelar")
}

/// Estilo del blur de fondo de la shield screen.
enum ShieldBackgroundBlurStyle { dark, light, none }

/// Tipo de evento emitido por DeviceActivityMonitorExtension.
enum ActivityEventType {
  /// El intervalo/horario de bloqueo comenzó.
  /// Corresponde a intervalDidStart() en Swift.
  intervalDidStart,

  /// El intervalo/horario de bloqueo terminó.
  /// Corresponde a intervalDidEnd() en Swift.
  intervalDidEnd,

  /// El usuario agotó el límite de tiempo diario para las apps bloqueadas.
  /// Corresponde a eventDidReachThreshold() en Swift.
  thresholdReached,
}

/// Evento emitido por DeviceActivityMonitorExtension.
class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.activityName,
    required this.timestamp,
  });

  /// Tipo de evento que ocurrió.
  final ActivityEventType type;

  /// Nombre del DeviceActivity que disparó el evento.
  /// Coincide con el nombre registrado en setSchedule().
  final String activityName;

  /// Momento exacto en que ocurrió el evento.
  final DateTime timestamp;
}

/// Resumen de apps, categorías y dominios web seleccionados por el usuario.
///
/// NOTA: Apple hace los tokens opacos por privacidad. No es posible obtener
/// el nombre, bundle ID ni ningún identificador de las apps seleccionadas.
/// Solo se puede saber cuántas hay en cada grupo.
class SelectedAppsSummary {
  const SelectedAppsSummary({
    required this.applicationCount,
    required this.categoryCount,
    required this.webDomainCount,
  });

  /// Número de apps específicas seleccionadas (tokens opacos).
  final int applicationCount;

  /// Número de categorías seleccionadas (ej. Redes Sociales, Juegos).
  final int categoryCount;

  /// Número de dominios web seleccionados (ej. instagram.com).
  final int webDomainCount;

  /// True si el usuario seleccionó al menos un elemento.
  bool get hasSelection =>
      applicationCount > 0 || categoryCount > 0 || webDomainCount > 0;

  /// Total de elementos seleccionados.
  int get totalCount => applicationCount + categoryCount + webDomainCount;
}

/// Horario de bloqueo con soporte de días de la semana y límite diario.
class ScreenTimeSchedule {
  const ScreenTimeSchedule({
    required this.start, // Hora de inicio del bloqueo
    required this.end, // Hora de fin del bloqueo
    this.weekdays, // 1=Lun … 7=Dom. null = todos los días
    this.dailyTimeLimit, // Tiempo máximo de uso antes de bloquear
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final List<int>? weekdays;
  final Duration? dailyTimeLimit;
}

/// Configuración visual de la pantalla de bloqueo.
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
}

// -------------------------------------------------------------
// CLASE 1 — FamilyControls
// Responsabilidad: autorización del sistema y selección de apps.
// Framework Apple: FamilyControls
// -------------------------------------------------------------
abstract class FamilyControls {
  /// Retorna el estado de autorización actual sin mostrar diálogo.
  Future<ScreenTimeAuthorizationStatus> checkAuthorization();

  /// Muestra el diálogo de autorización del sistema y retorna el nuevo estado.
  Future<ScreenTimeAuthorizationStatus> requestAuthorization();

  /// Revoca la autorización y limpia toda la configuración almacenada.
  Future<void> revokeAuthorization();

  /// Abre el FamilyActivityPicker nativo para que el usuario elija
  /// qué apps y categorías bloquear. Retorna un resumen de la selección.
  Future<SelectedAppsSummary> selectBlockedApps();

  /// Retorna el resumen de apps/categorías actualmente seleccionadas
  /// sin abrir el picker.
  Future<SelectedAppsSummary> getSelectedAppsSummary();
}

// -------------------------------------------------------------
// CLASE 2 — ManagedSettings
// Responsabilidad: activar y desactivar el bloqueo de apps.
// Framework Apple: ManagedSettings (ManagedSettingsStore)
// -------------------------------------------------------------
abstract class ManagedSettings {
  /// Registra el App Group ID para compartir datos con las extensiones iOS.
  /// Debe llamarse antes de startBlocking().
  Future<void> setSharedContainerId(String appGroupId);

  /// Activa el bloqueo usando la selección almacenada por FamilyControls.
  /// Aplica shield a apps y categorías seleccionadas.
  Future<void> startBlocking();

  /// Desactiva el bloqueo y limpia todos los ajustes de ManagedSettingsStore.
  Future<void> stopBlocking();

  /// Retorna true si el bloqueo está activo en este momento.
  Future<bool> getBlockingStatus();
}

// -------------------------------------------------------------
// CLASE 3 — DeviceActivity
// Responsabilidad: horarios automáticos y límites de tiempo de uso.
// Framework Apple: DeviceActivity (DeviceActivityCenter)
// Requiere: DeviceActivityMonitorExtension en el host app.
// -------------------------------------------------------------
abstract class DeviceActivity {
  /// Configura y activa un horario de bloqueo.
  /// Internamente llama DeviceActivityCenter.shared.startMonitoring().
  Future<void> setSchedule(ScreenTimeSchedule schedule);

  /// Retorna el horario actualmente configurado, o null si no hay ninguno.
  Future<ScreenTimeSchedule?> getSchedule();

  /// Elimina el horario y detiene el monitoreo automático.
  Future<void> clearSchedule();

  /// Inicia el monitoreo de actividad independientemente de un schedule,
  /// necesario para que DeviceActivityMonitorExtension reciba eventos.
  Future<void> startMonitoring();

  /// Detiene el monitoreo de actividad.
  Future<void> stopMonitoring();
}

// -------------------------------------------------------------
// CLASE 4 — ShieldExtension
// Responsabilidad: configurar la pantalla de bloqueo y recibir
// eventos desde las extensiones del host app.
//
// Cubre tres extensiones iOS (que viven en el host app):
//   · ShieldConfigurationExtension — apariencia de la shield
//   · ShieldActionExtension        — acciones de los botones
//   · DeviceActivityMonitorExtension — eventos de tiempo/horario
// -------------------------------------------------------------
abstract class ShieldExtension {
  /// Configura los textos y colores de la shield screen.
  /// Los datos se persisten en el App Group para que
  /// ShieldConfigurationExtension los lea.
  /// [Opción A]
  Future<void> configureShield(ScreenTimeBlockScreenConfig config);

  /// Sube un PNG (generado desde un widget Flutter) como ícono
  /// de la shield screen. Se guarda en el container del App Group.
  /// [Opción B] — usar junto a captureWidgetAsIcon()
  Future<void> setShieldIcon(Uint8List pngBytes);

  /// Captura un widget Flutter (identificado por [repaintKey]) como
  /// imagen PNG y lo sube automáticamente con setShieldIcon().
  /// Conveniencia que combina RepaintBoundary.toImage() + setShieldIcon().
  /// [Opción B]
  Future<void> captureWidgetAsIcon(Object repaintKey);

  /// Stream que emite un [ShieldAction] cada vez que el usuario
  /// toca un botón en la shield screen.
  /// Requiere: ShieldActionExtension configurada en el host app
  /// con el deep link "flutter-screentime://shield-action".
  Stream<ShieldAction> onShieldAction();

  /// Stream que emite un [ActivityEvent] cuando
  /// DeviceActivityMonitorExtension detecta un evento:
  /// - intervalDidStart  → el horario de bloqueo comenzó
  /// - intervalDidEnd    → el horario de bloqueo terminó
  /// - thresholdReached  → se agotó el límite de tiempo diario
  Stream<ActivityEvent> onActivityEvent();
}
