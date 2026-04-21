# Guía de Integración — flutter_control_parental

Esta guía cubre todo lo necesario para integrar `flutter_control_parental` en una app nueva desde cero.

---

## Índice

1. [Agregar el plugin](#1-agregar-el-plugin)
2. [Configuración iOS](#2-configuración-ios)
   - 2.1 [Entitlement Family Controls en la app principal](#21-entitlement-family-controls-en-la-app-principal)
   - 2.2 [Crear App Group](#22-crear-app-group)
   - 2.3 [Agregar extensión ShieldConfigurationExtension](#23-agregar-extensión-shieldconfigurationextension)
   - 2.4 [Agregar extensión ShieldActionExtension (opcional)](#24-agregar-extensión-shieldactionextension-opcional)
   - 2.5 [Agregar extensión DeviceActivityMonitor (opcional)](#25-agregar-extensión-deviceactivitymonitor-opcional)
   - 2.6 [URL Scheme para botones del shield (opcional)](#26-url-scheme-para-botones-del-shield-opcional)
3. [Uso básico en Dart](#3-uso-básico-en-dart)
4. [Errores comunes](#4-errores-comunes)

---

## 1. Agregar el plugin

En `pubspec.yaml`:

```yaml
dependencies:
  flutter_control_parental:
    path: ../  # o la versión de pub.dev cuando esté publicado
```

---

## 2. Configuración iOS

> **Requisito**: iOS 16+, dispositivo físico (los simuladores no soportan FamilyControls).

### 2.1 Entitlement Family Controls en la app principal

1. Abre `ios/Runner.xcworkspace` en Xcode.
2. Selecciona el target **Runner** → pestaña **Signing & Capabilities**.
3. Click en **+ Capability** → busca y agrega **Family Controls**.

Esto genera automáticamente (o actualiza) `Runner.entitlements`:

```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

> Este entitlement requiere aprobación de Apple para distribución en App Store.
> Para desarrollo y TestFlight no se necesita aprobación previa.

---

### 2.2 Crear App Group

El App Group es el canal de comunicación entre la app principal y las extensiones.

1. Target **Runner** → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Click en **+** y crea el grupo: `group.com.tuempresa.tuapp`
3. Anota el ID exacto — lo usarás en Dart y en cada extensión.

El entitlement quedará así:

```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.tuempresa.tuapp</string>
</array>
```

---

### 2.3 Agregar extensión ShieldConfigurationExtension

Esta extensión es **obligatoria** para mostrar una pantalla de bloqueo personalizada en lugar de la pantalla por defecto del sistema.

#### Crear el target en Xcode

1. **File → New → Target…**
2. Busca **Shield Configuration Extension** y selecciónalo.
3. Nombre del producto: `ShieldConfigurationExtension`
4. Asegúrate de que el **Bundle Identifier** sea: `com.tuempresa.tuapp.ShieldConfigurationExtension`

#### Configurar entitlements de la extensión

1. Selecciona el target `ShieldConfigurationExtension` → **Signing & Capabilities**.
2. Agrega **Family Controls**.
3. Agrega **App Groups** con el **mismo** grupo que la app principal: `group.com.tuempresa.tuapp`.

El `ShieldConfigurationExtension.entitlements` debe quedar:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.family-controls</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.tuempresa.tuapp</string>
  </array>
</dict>
</plist>
```

#### Reemplazar el código de la extensión

Copia el contenido de `templates/ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift.sample` al archivo `ShieldConfigurationExtension.swift` del target y cambia:

```swift
private let kAppGroupID = "group.com.tuempresa.tuapp" // ← tu App Group ID real
```

> **Importante**: El template incluye los **4 overrides** necesarios. Si omites alguno, iOS mostrará la pantalla por defecto para ese caso:
>
> | Override | Cuándo se invoca |
> |---|---|
> | `configuration(shielding application:)` | App bloqueada individualmente |
> | `configuration(shielding application:in category:)` | App bloqueada por categoría |
> | `configuration(shielding webDomain:)` | Dominio web bloqueado individualmente |
> | `configuration(shielding webDomain:in category:)` | Dominio web bloqueado por categoría |

#### Verificar Info.plist de la extensión

El `Info.plist` de la extensión debe tener `NSExtensionPrincipalClass` apuntando a tu clase:

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.ManagedSettingsUI.shield-configuration-service</string>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).ShieldConfigDataSource</string>
</dict>
```

> El nombre de clase (`ShieldConfigDataSource`) debe coincidir exactamente con el nombre de tu clase Swift.

---

### 2.4 Agregar extensión ShieldActionExtension (opcional)

Permite interceptar el tap en los botones de la pantalla de bloqueo y ejecutar una acción (ej: abrir la app principal).

#### Crear el target en Xcode

1. **File → New → Target…** → **Shield Action Extension**
2. Nombre: `ShieldActionExtension`
3. Bundle ID: `com.tuempresa.tuapp.ShieldActionExtension`

#### Configurar entitlements

Igual que la ShieldConfigurationExtension: agrega **Family Controls** y el **App Group**.

#### Código de la extensión

Copia `templates/ios/ShieldActionExtension/ShieldActionExtension.swift.sample` y actualiza el App Group ID.

---

### 2.5 Agregar extensión DeviceActivityMonitor (opcional)

Permite ejecutar lógica cuando un horario de bloqueo empieza/termina, o cuando se alcanza un límite de tiempo diario.

#### Crear el target en Xcode

1. **File → New → Target…** → **Device Activity Monitor Extension**
2. Nombre: `DeviceActivityMonitorExtension`
3. Bundle ID: `com.tuempresa.tuapp.DeviceActivityMonitorExtension`

#### Configurar entitlements

Mismos que las extensiones anteriores: **Family Controls** + **App Group**.

#### Código de la extensión

Copia `templates/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift.sample` y actualiza el App Group ID.

---

### 2.6 URL Scheme para botones del shield (opcional)

Si usas `ShieldActionExtension` y quieres que los botones de la pantalla de bloqueo emitan eventos hacia Flutter:

1. Target **Runner** → pestaña **Info** → sección **URL Types**.
2. Click en **+** y agrega:
   - **Identifier**: `flutter-control-parental`
   - **URL Schemes**: `flutter-control-parental`

Esto permite que la extensión abra la app principal con `flutter-control-parental://shield-action?button=primary` y el plugin re-emita el evento via `onShieldAction()` stream.

---

## 3. Uso básico en Dart

```dart
import 'package:flutter_control_parental/flutter_control_parental.dart';

const screenTime = FlutterControlParental();

// 1. Configurar el App Group ID (debe llamarse antes que cualquier otra cosa en iOS)
await screenTime.setSharedContainerId('group.com.tuempresa.tuapp');

// 2. Solicitar autorización (abre el diálogo del sistema la primera vez)
final status = await screenTime.requestAuthorization();
// status: 'approved' | 'denied' | 'notDetermined'

// 3. Configurar la pantalla de bloqueo personalizada
await screenTime.configureBlockScreen(ScreenTimeBlockScreenConfig(
  title: 'App Bloqueada',
  subtitle: 'Este contenido no está disponible.',
  backgroundColorHex: '#1a1a2e',
  primaryButtonLabel: 'Entendido',
  primaryButtonColorHex: '#e94560',
  primaryButtonTextColorHex: '#FFFFFF',
  secondaryButtonLabel: 'Ignorar',
));

// 4. (iOS) Abrir el picker de selección de apps/categorías
final summary = await screenTime.selectBlockedApps();
// summary.applicationCount, summary.categoryCount

// 5. Activar el bloqueo
await screenTime.startBlocking();

// 6. Desactivar el bloqueo
await screenTime.stopBlocking();
```

---

## 4. Errores comunes

### La pantalla de bloqueo muestra el diseño por defecto del sistema

**Causa**: La `ShieldConfigurationExtension` no implementa el override para el tipo de bloqueo que estás usando.

**Solución**: Verifica que el template tenga los 4 overrides (ver tabla en sección 2.3). El error más frecuente es omitir `configuration(shielding application:in category:)`, lo que provoca que el bloqueo por categoría use la pantalla por defecto.

---

### Error al compilar: "Method does not override any method from its superclass"

**Causa**: El nombre del tipo del parámetro es incorrecto.

**Correcto**:
```swift
// Para apps en categoría → usa ActivityCategory (de ManagedSettings)
override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration

// Para web en categoría
override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration
```

**Incorrecto** (no existe en la superclase):
```swift
// ❌ Este método NO existe en ShieldConfigurationDataSource
override func configuration(shielding applicationCategory: ApplicationCategory) -> ShieldConfiguration
```

---

### Error: "Cannot find type 'ApplicationCategory' in scope"

**Causa**: `ApplicationCategory` no existe en `ManagedSettings` para `ShieldConfigurationDataSource`. El tipo correcto es `ActivityCategory`.

---

### El App Group no sincroniza datos entre la app y la extensión

**Causas posibles**:
1. El App Group ID en el código Swift de la extensión no coincide exactamente con el registrado en Xcode.
2. No se llamó `setSharedContainerId(...)` desde Dart antes de `startBlocking()`.
3. Los entitlements del App Group no están en **ambos** targets (app principal Y extensión).

---

### `requestAuthorization` falla en simulador

**Causa**: FamilyControls no está disponible en simuladores de iOS. Requiere dispositivo físico.

---

### La extensión no recibe la configuración (`blockScreenConfig` es nil)

**Causa**: `configureBlockScreen(...)` debe llamarse **antes** de `startBlocking()`, y `setSharedContainerId(...)` debe llamarse primero que ambos.

**Orden correcto**:
```dart
await screenTime.setSharedContainerId('group.com.tuempresa.tuapp'); // 1ro
await screenTime.configureBlockScreen(config);                       // 2do
await screenTime.startBlocking();                                    // 3ro
```
