# Plan de Trabajo — flutter_screentime (iOS)

Enfoque exclusivo en iOS. La arquitectura de clases está definida en `control_parental.dart`.
Cada tarea corresponde a implementar una clase de la interfaz final.

---

## Arquitectura de clases (definida en `control_parental.dart`)

```
FamilyControls       → autorización + selección de apps
ManagedSettings      → activar/desactivar bloqueo
DeviceActivity       → horarios y límites de tiempo
ShieldExtension      → pantalla de bloqueo + eventos de extensiones
```

### Modelos de datos finales

| Modelo | Campos clave |
|---|---|
| `ScreenTimeAuthorizationStatus` | `notDetermined`, `denied`, `approved` |
| `SelectedAppsSummary` | `applicationCount`, `categoryCount`, `webDomainCount`, `hasSelection`, `totalCount` |
| `ScreenTimeSchedule` | `start`, `end`, `weekdays`, `dailyTimeLimit` |
| `ScreenTimeBlockScreenConfig` | `title`, `subtitle`, `primaryButtonLabel/Color/TextColor`, `secondaryButtonLabel`, `backgroundColorHex`, `backgroundBlurStyle` |
| `ShieldAction` | `primaryButton`, `secondaryButton` |
| `ActivityEventType` | `intervalDidStart`, `intervalDidEnd`, `thresholdReached` |
| `ActivityEvent` | `type`, `activityName`, `timestamp` |
| `ShieldBackgroundBlurStyle` | `dark`, `light`, `none` |

---

## Tarea 0 — Refactorización: nueva estructura de archivos

### Objetivo
Reorganizar `lib/` para que la API pública refleje las 4 clases definidas en `control_parental.dart`, reemplazando el archivo monolítico `flutter_screentime_api.dart`.

### Nueva estructura de `lib/`
```
lib/
├── flutter_screentime.dart              # Export barrel público
└── src/
    ├── models/
    │   ├── selected_apps_summary.dart
    │   ├── screen_time_schedule.dart
    │   ├── screen_time_block_screen_config.dart
    │   └── activity_event.dart
    ├── family_controls.dart             # Clase FamilyControls
    ├── managed_settings.dart            # Clase ManagedSettings
    ├── device_activity.dart             # Clase DeviceActivity
    └── shield_extension.dart            # Clase ShieldExtension
```

### Sub-tareas
- [ ] 0.1 Crear modelos en `src/models/` (migrar + ampliar desde `flutter_screentime_api.dart`)
- [ ] 0.2 Crear `FamilyControls` con los métodos existentes migrados
- [ ] 0.3 Crear `ManagedSettings` con los métodos existentes migrados
- [ ] 0.4 Actualizar `flutter_screentime.dart` como barrel de exportación
- [ ] 0.5 Eliminar `flutter_screentime_api.dart` una vez migrado todo
- [ ] 0.6 Actualizar `example/lib/main.dart` para reflejar la nueva estructura de clases (reemplazar uso de API monolítica por las 4 clases separadas)

### Archivos a modificar/crear
| Archivo | Acción |
|---|---|
| `lib/src/models/*.dart` | Crear modelos separados |
| `lib/src/family_controls.dart` | Crear con métodos migrados |
| `lib/src/managed_settings.dart` | Crear con métodos migrados |
| `lib/flutter_screentime.dart` | Actualizar exports |
| `lib/src/flutter_screentime_api.dart` | Eliminar al finalizar migración |
| `example/lib/main.dart` | Actualizar imports y uso a las nuevas clases |

---

## Tarea 1 — DeviceActivity: Horarios y Límites de Tiempo

### Clase objetivo: `DeviceActivity`
```dart
abstract class DeviceActivity {
  Future<void> setSchedule(ScreenTimeSchedule schedule);
  Future<ScreenTimeSchedule?> getSchedule();
  Future<void> clearSchedule();
  Future<void> startMonitoring();
  Future<void> stopMonitoring();
}
```

### Contexto técnico
`DeviceActivity` de Apple requiere una extensión separada (`DeviceActivityMonitorExtension`) que corre fuera del proceso principal. El plugin configura los schedules/thresholds desde Swift y la extensión reacciona aplicando bloqueos en `ManagedSettingsStore`. El modelo `ScreenTimeSchedule` incluye `dailyTimeLimit` como `Duration?`, eliminando la necesidad de un método `setDailyTimeLimit` separado.

### Sub-tareas

#### 1.1 — Implementación Dart (`lib/src/device_activity.dart`)
- Clase `DeviceActivity` con los 5 métodos de la interfaz
- Serialización de `ScreenTimeSchedule` a `Map` para el method channel:
  - `start`/`end` como `{ hour, minute }`
  - `weekdays` como `List<int>` (1=Lun…7=Dom)
  - `dailyTimeLimit` como total de segundos (`int?`)

#### 1.2 — Implementación Swift
En `ios/Classes/FlutterScreentimePlugin.swift`:
- Cases: `"setSchedule"`, `"getSchedule"`, `"clearSchedule"`, `"startMonitoring"`, `"stopMonitoring"`
- Usar `DeviceActivityCenter.shared.startMonitoring(_:during:)` con el schedule deserializado
- Al `stopBlocking` también llamar `DeviceActivityCenter.shared.stopMonitoring()`

Nuevas claves en `StorageKey`:
```swift
static let activitySchedule = "flutter_screentime.activitySchedule"
static let dailyTimeLimit   = "flutter_screentime.dailyTimeLimit"
```

#### 1.3 — Template `DeviceActivityMonitorExtension` (reescribir stub actual)
El template actual en `templates/ios/DeviceActivityMonitorExtension/` es un stub vacío. Reescribir con lógica real:
- `intervalDidStart`: decodifica `FamilyActivitySelection` del App Group → aplica bloqueo en `ManagedSettingsStore`
- `intervalDidEnd`: `store.clearAllSettings()`
- `eventDidReachThreshold`: aplica bloqueo cuando se agota el límite de tiempo diario

#### 1.4 — Documentación
Actualizar `doc/ios_extensions.md` con setup de Xcode para `DeviceActivityMonitorExtension`.

#### 1.5 — Ejemplo funcional en `example/`
Agregar una sección en `example/lib/main.dart` (o pantalla dedicada `example/lib/screens/device_activity_screen.dart`) que permita probar:
- Configurar y guardar un `ScreenTimeSchedule` con hora de inicio, fin, días y límite diario
- Llamar `startMonitoring()` y `stopMonitoring()` con feedback visual
- Leer el schedule activo con `getSchedule()` y mostrarlo en pantalla
- Llamar `clearSchedule()` y confirmar que se borró

### Archivos a modificar/crear
| Archivo | Acción |
|---|---|
| `lib/src/device_activity.dart` | Crear clase |
| `ios/Classes/FlutterScreentimePlugin.swift` | Agregar 5 handlers Swift |
| `templates/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift.sample` | Reescribir con lógica real |
| `doc/ios_extensions.md` | Actualizar |
| `example/lib/main.dart` | Agregar demo de schedules |
| `example/lib/screens/device_activity_screen.dart` | Crear pantalla dedicada (opcional) |

### Estado
- [ ] 1.1 Clase Dart `DeviceActivity`
- [ ] 1.2 Handlers Swift
- [ ] 1.3 Template DeviceActivityMonitorExtension
- [ ] 1.4 Documentación
- [ ] 1.5 Ejemplo funcional en `example/`

---

## Tarea 2 — ShieldExtension: Pantalla de bloqueo (Opción A + B)

### Clase objetivo: `ShieldExtension`
```dart
abstract class ShieldExtension {
  Future<void> configureShield(ScreenTimeBlockScreenConfig config);  // Opción A
  Future<void> setShieldIcon(Uint8List pngBytes);                    // Opción B
  Future<void> captureWidgetAsIcon(Object repaintKey);               // Opción B (shortcut)
  Stream<ShieldAction> onShieldAction();
  Stream<ActivityEvent> onActivityEvent();
}
```

### Contexto técnico
- **Opción A**: `configureShield()` persiste `ScreenTimeBlockScreenConfig` (ahora con campos completos) en el App Group. La extensión lee y construye `ShieldConfiguration`.
- **Opción B**: `setShieldIcon()` guarda el PNG en `<AppGroup>/Library/Caches/flutter_screentime_shield_icon.png`. La extensión lo carga como `UIImage`.
- Los streams `onShieldAction` y `onActivityEvent` se implementan en Tarea 3.

### Sub-tareas

#### 2.1 — Clase Dart `ShieldExtension` (configureShield + setShieldIcon + captureWidgetAsIcon)
- `configureShield(config)`: serializa `ScreenTimeBlockScreenConfig` al method channel
  - Incluye `backgroundBlurStyle` como string (`'dark'`/`'light'`/`'none'`)
- `setShieldIcon(pngBytes)`: envía `Uint8List` al method channel
- `captureWidgetAsIcon(repaintKey)`: captura widget con `RepaintBoundary.toImage()` y llama `setShieldIcon()`

#### 2.2 — Handler Swift `configureShield`
- Acepta el mapa completo de `ScreenTimeBlockScreenConfig`
- Persiste en `UserDefaults` estándar y App Group compartido
- Reemplaza el actual `configureBlockScreen` (renombrar)

#### 2.3 — Handler Swift `setShieldIcon`
- Recibe `FlutterStandardTypedData` con los bytes PNG
- Escribe el archivo en el container del App Group:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`

#### 2.4 — Template `ShieldConfigurationExtension` (reemplazar actual)
Reescribir `templates/ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift.sample`:
- Lee todos los campos de `ScreenTimeBlockScreenConfig` del App Group → **Opción A**
- Intenta cargar `flutter_screentime_shield_icon.png` del container → **Opción B**
- Maneja tanto `shielding application:` como `shielding applicationCategory:`
- Construye `ShieldConfiguration` combinando ambas fuentes

#### 2.5 — Documentación y ejemplo
- Actualizar `doc/ios_extensions.md` con guía de `ShieldConfigurationExtension`

#### 2.6 — Ejemplo funcional en `example/`
Agregar pantalla `example/lib/screens/shield_config_screen.dart` que permita probar:
- Formulario para editar todos los campos de `ScreenTimeBlockScreenConfig` (título, subtítulo, colores, botones, blur style)
- Botón "Aplicar configuración" que llame `configureShield()`
- Selector de imagen para elegir un PNG y llamar `setShieldIcon()`
- Demo de `captureWidgetAsIcon()` capturando un widget de Flutter como ícono de la shield
- Vista previa del estado actual de la configuración

### Archivos a modificar/crear
| Archivo | Acción |
|---|---|
| `lib/src/shield_extension.dart` | Crear clase (configureShield + setShieldIcon + captureWidgetAsIcon) |
| `ios/Classes/FlutterScreentimePlugin.swift` | Handlers `configureShield` y `setShieldIcon` |
| `templates/ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift.sample` | Reescribir completo |
| `doc/ios_extensions.md` | Actualizar |
| `example/lib/main.dart` | Agregar navegación a la nueva pantalla |
| `example/lib/screens/shield_config_screen.dart` | Crear pantalla dedicada |

### Estado
- [ ] 2.1 Clase Dart `ShieldExtension` (métodos de configuración)
- [ ] 2.2 Handler Swift `configureShield`
- [ ] 2.3 Handler Swift `setShieldIcon`
- [ ] 2.4 Template ShieldConfigurationExtension
- [ ] 2.5 Documentación
- [ ] 2.6 Ejemplo funcional en `example/`

---

## Tarea 3 — ShieldExtension: Streams de eventos (ShieldAction + ActivityEvent)

### Métodos objetivo
```dart
Stream<ShieldAction> onShieldAction();     // botones de la shield
Stream<ActivityEvent> onActivityEvent();   // eventos del monitor de actividad
```

### Contexto técnico
Los streams requieren `EventChannel` en el plugin (uno por tipo de evento). La `ShieldActionExtension` se comunica con la app principal via deep link (`flutter-screentime://shield-action?button=primary`). La `DeviceActivityMonitorExtension` se comunica escribiendo un evento al App Group y la app lo detecta vía `NotificationCenter` o polling.

### Sub-tareas

#### 3.1 — EventChannels en Swift
En `FlutterScreentimePlugin.swift`:
```swift
// Dos canales de eventos
let shieldActionChannel   = FlutterEventChannel(name: "flutter_screentime/shield_action", ...)
let activityEventChannel  = FlutterEventChannel(name: "flutter_screentime/activity_event", ...)
```
- `shieldActionChannel`: alimentado por el URL handler del deep link
- `activityEventChannel`: alimentado por cambios en el App Group (usando `CFNotificationCenter` o `UserDefaults.didChangeNotification`)

#### 3.2 — Streams Dart en `ShieldExtension`
- `onShieldAction()` → `Stream<ShieldAction>` desde `EventChannel`
- `onActivityEvent()` → `Stream<ActivityEvent>` deserializando `{ type, activityName, timestamp }` desde el canal

#### 3.3 — Template `ShieldActionExtension`
Crear `templates/ios/ShieldActionExtension/ShieldActionExtension.swift.sample`:
- Botón primario: abre la app con `open(URL("flutter-screentime://shield-action?button=primary"))`
- Botón secundario: retorna `.close`
- Lee el App Group para determinar comportamiento configurable

#### 3.4 — Template `DeviceActivityMonitorExtension` (complemento de Tarea 1.3)
Agregar emisión de eventos al App Group para que la app principal los reciba:
```swift
// En cada handler del monitor:
sharedDefaults?.set(["type": "thresholdReached", "activityName": activity.rawValue,
                     "timestamp": Date().timeIntervalSince1970], 
                    forKey: "flutter_screentime.lastActivityEvent")
CFNotificationCenterPostNotification(...)
```

#### 3.5 — Documentación
Agregar en `doc/ios_extensions.md`:
- Configuración del URL scheme en Xcode para `ShieldActionExtension`
- Setup del App Group notification en `DeviceActivityMonitorExtension`

#### 3.6 — Ejemplo funcional en `example/`
Agregar sección en la pantalla de ShieldExtension (o pantalla propia `example/lib/screens/shield_events_screen.dart`) que permita probar:
- Suscribirse a `onShieldAction()` y mostrar en tiempo real qué botón presionó el usuario desde la shield
- Suscribirse a `onActivityEvent()` y mostrar el log de eventos (`intervalDidStart`, `intervalDidEnd`, `thresholdReached`) con timestamp
- Botones para iniciar/detener la escucha de cada stream de forma independiente

### Archivos a modificar/crear
| Archivo | Acción |
|---|---|
| `lib/src/shield_extension.dart` | Agregar `onShieldAction()` y `onActivityEvent()` |
| `ios/Classes/FlutterScreentimePlugin.swift` | Agregar 2 EventChannels + URL handler |
| `templates/ios/ShieldActionExtension/ShieldActionExtension.swift.sample` | Crear template |
| `templates/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift.sample` | Agregar emisión de eventos |
| `doc/ios_extensions.md` | Documentar URL scheme y notificaciones |
| `example/lib/main.dart` | Agregar navegación a la nueva pantalla |
| `example/lib/screens/shield_events_screen.dart` | Crear pantalla dedicada |

### Estado
- [ ] 3.1 EventChannels Swift
- [ ] 3.2 Streams Dart
- [ ] 3.3 Template ShieldActionExtension
- [ ] 3.4 Template DeviceActivityMonitorExtension (emisión de eventos)
- [ ] 3.5 Documentación
- [ ] 3.6 Ejemplo funcional en `example/`

---

## Tarea 4 — FamilyControls: completar API

### Métodos a agregar
```dart
// En FamilyControls (ya tiene checkAuthorization, requestAuthorization, selectBlockedApps)
Future<void> revokeAuthorization();
Future<SelectedAppsSummary> getSelectedAppsSummary();  // sin abrir el picker
```

### Sub-tareas

#### 4.1 — `getSelectedAppsSummary` en Dart y Swift
- Dart: llama al channel y deserializa `{ applicationCount, categoryCount, webDomainCount }`
- Swift: lee `flutter_screentime.blockedSelection` del App Group, decodifica `FamilyActivitySelection` y retorna los conteos (incluyendo `webDomainTokens.count`)
- Actualizar `SelectedAppsSummary.fromMap` para incluir `webDomainCount`

#### 4.2 — `revokeAuthorization` en Dart y Swift
- Dart: invoca el method channel
- Swift: llama `AuthorizationCenter.shared.revokeAuthorization(completionHandler:)`, limpia todo el App Group y llama `store.clearAllSettings()` + `DeviceActivityCenter.shared.stopMonitoring()`

#### 4.3 — Ejemplo funcional en `example/`
Agregar o actualizar la sección de `FamilyControls` en `example/lib/main.dart` (o `example/lib/screens/family_controls_screen.dart`) para probar:
- Mostrar el resumen de apps seleccionadas (`getSelectedAppsSummary()`) sin necesidad de abrir el picker
- Botón "Revocar autorización" con confirmación y feedback del resultado
- Estado actualizado tras cada acción (conteos de apps, categorías y dominios web)

### Archivos a modificar/crear
| Archivo | Acción |
|---|---|
| `lib/src/family_controls.dart` | Agregar `revokeAuthorization` y `getSelectedAppsSummary` |
| `ios/Classes/FlutterScreentimePlugin.swift` | Handlers Swift para ambos métodos |
| `example/lib/main.dart` | Actualizar sección de FamilyControls |
| `example/lib/screens/family_controls_screen.dart` | Crear pantalla dedicada (opcional) |

### Estado
- [ ] 4.1 `getSelectedAppsSummary`
- [ ] 4.2 `revokeAuthorization`
- [ ] 4.3 Ejemplo funcional en `example/`

---

## Orden de ejecución

```
Tarea 0          Tarea 1          Tarea 2          Tarea 3          Tarea 4
Refactor     →  DeviceActivity → ShieldConfig   → Streams        → FamilyControls
(estructura)    (horarios)       (UI custom)      (eventos)        (completitud)
```

- **Tarea 0**: base estructural, no bloquea pero conviene hacerla primero.
- **Tarea 1**: core funcional de control parental (horarios y límites de tiempo).
- **Tarea 2**: experiencia visual de la shield (depende del App Group de Tarea 0).
- **Tarea 3**: comunicación bidireccional con extensiones (depende de Tarea 2).
- **Tarea 4**: completitud de la API de autorización.

---

## Notas generales
- Todo el desarrollo es exclusivamente iOS (Android fuera de alcance).
- Requiere iOS 16+ en todos los casos.
- Las extensiones deben crearse manualmente en Xcode en el host app; el plugin provee templates y la infraestructura del App Group.
- El entitlement `com.apple.developer.family-controls` debe estar activo en el perfil de desarrollo.
- La arquitectura de clases de referencia está en `control_parental.dart`.

## Lineamiento de ejemplos (`example/`)

Cada tarea debe incluir, como parte de su definición de hecho, un ejemplo funcional en `example/` que permita probar manualmente todas las funciones integradas. Reglas:

- **Una pantalla por clase**: preferir pantallas dedicadas en `example/lib/screens/<clase>_screen.dart` en lugar de saturar `main.dart`.
- **Cobertura completa**: cada método público de la clase debe tener al menos un botón/acción en la pantalla de ejemplo.
- **Feedback visible**: todas las llamadas deben mostrar resultado (éxito, error, datos retornados) en la UI, nunca solo en consola.
- **Estado reactivo**: usar `setState` o equivalente para que la pantalla refleje el estado actual del plugin tras cada operación.
- **`main.dart` como índice**: `main.dart` actúa como menú de navegación hacia las pantallas de cada clase; no contiene lógica de plugin directamente.
