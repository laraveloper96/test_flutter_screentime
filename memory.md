# memory.md — Memoria del Proyecto flutter_screentime

Este archivo registra las decisiones, cambios y contexto del desarrollo de este proyecto.

---

## Enfoque

- El desarrollo se enfoca **netamente en iOS**.
- Android queda fuera del alcance por ahora.
- La implementación iOS usa el framework nativo `FamilyControls` (iOS 16+) con `ManagedSettingsStore` para el bloqueo de apps.

---

## Conocimiento sobre Control Parental en iOS

### Frameworks de Apple disponibles
- **`FamilyControls`** (iOS 16+): Framework central. Requiere entitlement especial de Apple para App Store. Maneja autorización del padre/tutor y provee `FamilyActivityPicker`.
- **`ManagedSettings`** (iOS 16+): Bloqueo real de apps a nivel sistema con `ManagedSettingsStore`. Muestra pantalla "Shield" nativa al intentar abrir app bloqueada.
- **`DeviceActivity`** (iOS 16+): Monitorea uso del dispositivo con schedules (horarios) y thresholds (límites de tiempo). Llama a extensión `DeviceActivityMonitor` cuando se alcanza un límite.

### Extensiones requeridas por Apple
| Extensión | Propósito |
|---|---|
| `ShieldConfigurationExtension` | Personaliza la pantalla que ve el usuario al intentar abrir una app bloqueada |
| `ShieldActionExtension` | Define qué pasa cuando el usuario toca un botón en la Shield (ej. "Pedir más tiempo") |
| `DeviceActivityMonitorExtension` | Reacciona a eventos de tiempo (inicio/fin de schedule, límite alcanzado) |

> Las extensiones deben vivir en el host app (no en el plugin), pero el plugin provee templates y almacenamiento compartido vía App Group.

---

## Estado actual del plugin (iOS)

### Funcionalidades YA integradas
- ✅ `FamilyControls`: `requestAuthorization`, `checkAuthorization`
- ✅ `FamilyActivityPicker`: `selectBlockedApps` (selector nativo de apps)
- ✅ `ManagedSettingsStore`: `startBlocking` (shield por apps y categorías), `stopBlocking`
- ✅ App Group / UserDefaults compartido: `setSharedContainerId`
- ✅ Configuración de pantalla de bloqueo: `configureBlockScreen` (persiste para extensiones)

### Funcionalidades NO integradas (pendientes)
- ❌ `DeviceActivity`: Sin horarios (schedules), sin límites de tiempo (thresholds)
- ❌ `ShieldConfigurationExtension`: El plugin guarda la config, pero la extensión la debe crear el host app
- ❌ `ShieldActionExtension`: No implementada en absoluto
- ❌ `DeviceActivityMonitorExtension`: No implementada en absoluto
- ❌ Bloqueo por horario (ej. bloquear de 10pm a 7am)
- ❌ Límites de tiempo de uso (ej. máximo 1 hora/día en TikTok)

### ¿Se pueden integrar todas?
- **DeviceActivity (schedules/thresholds)**: SÍ, se puede agregar directo al código Swift del plugin como nuevos métodos.
- **Extensiones (ShieldConfiguration, ShieldAction, DeviceActivityMonitor)**: Deben vivir en el host app por diseño de Apple, pero el plugin puede proveer templates y la infraestructura de almacenamiento compartido.

---

## Plan de Trabajo

El plan detallado está en `plan.md`. Resumen de las 4 tareas:

### Tarea 1 — DeviceActivity (horarios y límites de tiempo)
- Nuevos métodos Dart: `setSchedule`, `setDailyTimeLimit`, `clearSchedule`
- Implementación Swift con `DeviceActivityCenter` y `DeviceActivitySchedule`
- **Reescribir** template de `DeviceActivityMonitorExtension` (actual es stub vacío) con lógica real: `intervalDidStart/End` + `eventDidReachThreshold`

### Tarea 2 — ShieldConfigurationExtension (Opción A + B)
- **Opción A**: Ampliar `ScreenTimeBlockScreenConfig` con todos los campos de `ShieldConfiguration`
- **Opción B**: `setShieldIcon(Uint8List)` → guarda PNG en App Group container → extensión lo carga como `UIImage`
- Helper Dart `captureAndSetShieldIcon(GlobalKey)` para capturar widgets
- Template actualizado que maneja apps y categorías (`shielding application:` + `shielding applicationCategory:`)

### Tarea 3 — ShieldActionExtension (no existe, crear desde cero)
- Template Swift: botón primario abre app via deep link, botón secundario cierra shield
- `EventChannel` en el plugin para notificar a Flutter qué botón tocó el usuario
- Enum `ShieldAction` en Dart

### Tarea 4 — Getters de estado + revokeAuthorization
- `getBlockingStatus()`, `getSchedule()`, `getSelectedAppsSummary()`
- `revokeAuthorization()` — limpia todo y revoca FamilyControls
- Modelo `ScreenTimeSchedule` en Dart

> Orden: Tarea 1 → Tarea 2 → Tarea 3 → Tarea 4

---

## Cambios y Decisiones

<!-- Registrar aquí cada cambio importante, decisión técnica o contexto relevante -->

