# Plan de Diagnóstico — ShieldAction & DeviceActivityMonitorExtension

> Objetivo: identificar y corregir por qué los eventos de los botones de la shield
> y los eventos de `DeviceActivityMonitorExtension` no llegan al stream de Flutter.

---

## Contexto del problema

El flujo de eventos tiene **dos rutas de comunicación independientes**:

```
Ruta A: ShieldAction (botones)
  ShieldActionExtension → Deep Link URL → AppDelegate → Plugin →
  EventChannel → Flutter stream onShieldAction()

Ruta B: ActivityEvent (horarios / límites)
  DeviceActivityMonitorExtension → App Group UserDefaults →
  Darwin Notification → Plugin → EventChannel → Flutter stream onActivityEvent()
```

---

## Ruta A — ShieldAction: botones de la pantalla de bloqueo

### Diagnóstico 1A: ¿Existe el target `ShieldActionExtension`?

> Sin este target iOS usa el comportamiento por defecto y nunca llama a tu código.

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 1A-1 | Abrir `example/ios/Runner.xcworkspace` en Xcode | — |
| 1A-2 | Verificar que exista un target `ShieldActionExtension` | Target visible |
| 1A-3 | Si NO existe: **File › New › Target** → "Shield Action Extension" | Target creado |
| 1A-4 | Verificar que el archivo del target hereda de `ShieldActionDelegate` | Correcto en el `.swift` |

---

### Diagnóstico 2A: ¿Comparte el App Group correcto?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 2A-1 | Target `ShieldActionExtension` › Signing & Capabilities | — |
| 2A-2 | Verificar "App Groups": `group.com.ssssstudios.time4kids` | Idéntico al Runner |

---

### Diagnóstico 3A: ¿El código emite el Deep Link correctamente?

El error más frecuente es NO pasar la URL al `completionHandler`.

```swift
// CORRECTO
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        _ action: ShieldAction,
        for application: Application,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let button = (action == .primaryButton) ? "primary" : "secondary"
        let url = URL(string: "flutter-screentime://shield-action?button=\(button)")!
        completionHandler(.open(url))  // iOS abrirá la URL en la app principal
    }

    override func handle(
        _ action: ShieldAction,
        for applicationCategory: ApplicationCategory,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let button = (action == .primaryButton) ? "primary" : "secondary"
        let url = URL(string: "flutter-screentime://shield-action?button=\(button)")!
        completionHandler(.open(url))
    }
}
```

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 3A-1 | Verificar que el archivo real usa `completionHandler(.open(url))` | Correcto |
| 3A-2 | Si usa `.defer` o `.close` sin URL — corregirlo | Corregido |

---

### Diagnóstico 4A: ¿El URL Scheme `flutter-screentime` está registrado?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 4A-1 | Abrir `example/ios/Runner/Info.plist` | — |
| 4A-2 | Buscar `CFBundleURLTypes` → `CFBundleURLSchemes` → `flutter-screentime` | Existe (agregado hoy) |
| 4A-3 | En Xcode: target Runner › Info › URL Types | Aparece `flutter-screentime` |

---

### Diagnóstico 5A: ¿El `AppDelegate` reenvía la URL?

El plugin se auto-registra como delegate vía `registrar.addApplicationDelegate(instance)`.
Solo funciona si `AppDelegate` extiende `FlutterAppDelegate`.

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 5A-1 | Abrir `example/ios/Runner/AppDelegate.swift` | — |
| 5A-2 | Verificar: `class AppDelegate: FlutterAppDelegate` | Correcto |
| 5A-3 | Si NO — agregar el método de reenvío manual: | Ver código abajo |

```swift
// Solo si AppDelegate NO extiende FlutterAppDelegate
override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    return super.application(app, open: url, options: options)
}
```

---

### Verificación final Ruta A — Cadena de logs esperada

```
// Xcode Console (subsystem FlutterScreentime):
📱 application(open:) called with URL: flutter-screentime://shield-action?button=primary
📱 Emitting ShieldAction: primaryButton

// Terminal Flutter / VS Code:
dart: ShieldAction received: primaryButton
```

- Si NO aparece el log de iOS → problema en pasos 3A o 4A.
- Si aparece iOS pero NO Flutter → problema en la suscripción al EventChannel.

---

## Ruta B — ActivityEvent: DeviceActivityMonitorExtension

### Diagnóstico 1B: ¿Existe el target `DeviceActivityMonitorExtension`?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 1B-1 | En Xcode, verificar la lista de targets | Target `DeviceActivityMonitorExtension` visible |
| 1B-2 | Si NO existe: **File › New › Target** → "Device Activity Monitor Extension" | Target creado |
| 1B-3 | Bundle ID: `<bundle_principal>.DeviceActivityMonitorExtension` | Ej. `com.ssssstudios.time4kids.DeviceActivityMonitorExtension` |

---

### Diagnóstico 2B: ¿El `Info.plist` de la extensión es correcto?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 2B-1 | Abrir `Info.plist` del target `DeviceActivityMonitorExtension` (NO el de Runner) | — |
| 2B-2 | `NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension` |
| 2B-3 | `NSExtensionPointIdentifier` | `com.apple.deviceactivity.monitor-extension` |

---

### Diagnóstico 3B: ¿La extensión comparte el App Group?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 3B-1 | Target `DeviceActivityMonitorExtension` › Signing & Capabilities | — |
| 3B-2 | "App Groups": `group.com.ssssstudios.time4kids` | Mismo ID que Runner |
| 3B-3 | Entitlement `com.apple.developer.family-controls` presente | Habilitado |

---

### Diagnóstico 4B: ¿El código escribe en el App Group y emite la notificación?

```swift
import DeviceActivity
import Foundation
import os

private let kAppGroupID = "group.com.ssssstudios.time4kids"  // debe coincidir exactamente
private let kNotification = "dev.iori.flutter_screentime.activity_event" // mismo valor que el plugin
private let log = Logger(subsystem: "com.ssssstudios.time4kids.Monitor", category: "MonitorExtension")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log.info("⏰ intervalDidStart: \(activity.rawValue)")
        postEvent(type: "intervalDidStart", activityName: activity.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log.info("⏰ intervalDidEnd: \(activity.rawValue)")
        postEvent(type: "intervalDidEnd", activityName: activity.rawValue)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        log.info("⏰ thresholdReached: \(event.rawValue) in \(activity.rawValue)")
        postEvent(type: "thresholdReached", activityName: activity.rawValue)
    }

    private func postEvent(type: String, activityName: String) {
        let payload: [String: Any] = [
            "type": type,
            "activityName": activityName,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let shared = UserDefaults(suiteName: kAppGroupID) {
            shared.set(payload, forKey: "flutter_screentime.lastActivityEvent")
            shared.synchronize()
            log.info("⏰ ✅ Event written to App Group")
        } else {
            log.error("⏰ ❌ Cannot access App Group: \(kAppGroupID)")
            return
        }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(kNotification as CFString),
            nil, nil, true
        )
        log.info("⏰ Darwin Notification posted")
    }
}
```

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 4B-1 | `kAppGroupID` es exactamente `group.com.ssssstudios.time4kids` | Coincide |
| 4B-2 | `kNotification` es `"dev.iori.flutter_screentime.activity_event"` | Coincide con el plugin |
| 4B-3 | Se llama `super.intervalDidStart(...)` antes de `postEvent` | `super` presente |

---

### Diagnóstico 5B: ¿`setSharedContainerId` se llama ANTES de setSchedule/startMonitoring?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 5B-1 | Verificar que se llama `setSharedContainerId("group.com.ssssstudios.time4kids")` al iniciar la app | Existe la llamada |
| 5B-2 | La llamada ocurre ANTES de `setSchedule()` o `startMonitoring()` | Orden correcto |

```dart
// En main() o initState() del widget raíz — ANTES de cualquier otra llamada
await ManagedSettings().setSharedContainerId('group.com.ssssstudios.time4kids');
```

---

### Diagnóstico 6B: ¿El horario está activo cuando se prueba?

| Paso | Acción | Resultado esperado |
|------|--------|--------------------|
| 6B-1 | Ir a la pantalla DeviceActivity | — |
| 6B-2 | Configurar horario: inicio = **hora actual + 1 min**, fin = **hora actual + 5 min** | Schedule configurado |
| 6B-3 | Pulsar "Guardar horario" → sin error | Monitoreo activo |
| 6B-4 | Esperar 1 minuto | — |
| 6B-5 | **Console.app** (filtro `MonitorExtension`): `⏰ intervalDidStart` | Log presente = extensión activa |
| 6B-6 | **Xcode Console** (filtro `FlutterScreentime`): `📱 Received Darwin Notification` | Log presente = bridge activo |
| 6B-7 | **Terminal Flutter**: `dart: ActivityEvent received` | Log presente = stream funcional |

> Para probar `thresholdReached`: configura `dailyTimeLimit` en 10 segundos y abre una app bloqueada.

---

### Verificación final Ruta B — Cadena de logs esperada

```
// Console.app - filtro "MonitorExtension":
⏰ intervalDidStart: flutter_screentime.schedule
⏰ ✅ Event written to App Group
⏰ Darwin Notification posted

// Xcode Console - filtro "FlutterScreentime":
📱 Received Darwin Notification: dev.iori.flutter_screentime.activity_event
📱 Bridge: Activity Event found: ["type": "intervalDidStart", ...]

// Terminal Flutter:
dart: ActivityEvent received: {type: intervalDidStart, activityName: flutter_screentime.schedule, timestamp: ...}
```

---

## Tabla de síntomas y causas

| Síntoma | Causa probable | Paso a revisar |
|---------|----------------|----------------|
| Botón no hace nada visible | Target `ShieldActionExtension` no existe | 1A |
| URL recibida pero "no match" en Xcode | URL scheme no registrado en Info.plist | 4A |
| No hay ningún log de iOS al pulsar botón | `completionHandler(.open(url))` no se llama | 3A |
| Log de iOS presente pero no Flutter | EventChannel sin listener activo al momento del evento | Verificar `_startShieldActions()` |
| No hay logs de `MonitorExtension` nunca | Target no existe o bundle ID incorrecto | 1B / 2B |
| Log de extensión pero no de plugin | App Group ID no coincide o `setSharedContainerId` no llamado | 3B / 5B |
| Log de plugin pero no de Flutter | Stream no estaba escuchando cuando llegó el evento | Iniciar escucha ANTES del horario |
| Stream activo pero evento nunca llega | Horario no configurado o fuera de su ventana de tiempo | 6B |

---

## Cómo ver los logs de extensiones en Console.app

Las extensiones corren en un **proceso separado** — sus logs NO aparecen en Xcode.

1. Abrir **Console.app** (`/Applications/Utilities/Console.app`)
2. Seleccionar el iPhone en la barra lateral
3. Filtrar por: `MonitorExtension`
4. Pulsar ▸ para capturar
5. Cuando el horario se active, los logs aparecen aquí

Para los logs del plugin (proceso principal):
- **Xcode** → Debug Area → Console, filtrando por `FlutterScreentime`

---

## Orden de ejecución recomendado

Trabajar primero la **Ruta A** (más rápida: solo pulsar un botón).
La Ruta B requiere esperar a que un horario se active.

```
Ruta A:  1A → 2A → 3A → 4A → 5A → Prueba final A
Ruta B:  1B → 2B → 3B → 4B → 5B → 6B → Prueba final B
```
