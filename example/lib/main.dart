import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screentime/flutter_screentime.dart';

import 'screens/device_activity_screen.dart';
import 'screens/family_controls_screen.dart';
import 'screens/managed_settings_screen.dart';
import 'screens/permission_request_screen.dart';
import 'screens/shield_config_screen.dart';
import 'screens/shield_events_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_screentime',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _kAppGroupId = 'group.com.ssssstudios.time4kids';

  final _familyControls = const FamilyControls();
  final _managedSettings = const ManagedSettings();
  final _shieldExtension = const ShieldExtension();

  bool _isInitializing = false;
  String _initStatus = '';

  // ---------------------------------------------------------------------------
  // Quick Init
  // ---------------------------------------------------------------------------

  Future<void> _quickInit() async {
    setState(() {
      _isInitializing = true;
      _initStatus = '';
    });

    try {
      // Paso 1 — App Group ID
      _setStatus('Guardando App Group ID…');
      await _managedSettings.setSharedContainerId(_kAppGroupId);

      // Paso 2 — Configurar Shield para el flujo "Pedir permiso"
      _setStatus('Configurando Shield…');
      await _shieldExtension.configureShield(
        const ScreenTimeBlockScreenConfig(
          title: 'App Bloqueada',
          subtitle: 'Este contenido no está disponible ahora.',
          primaryButtonLabel: 'Pedir permiso',
          primaryButtonColorHex: '#3B82F6',
          primaryButtonTextColorHex: '#FFFFFF',
          secondaryButtonLabel: 'Cancelar',
          backgroundColorHex: '#111827',
          backgroundBlurStyle: ShieldBackgroundBlurStyle.dark,
        ),
      );

      // Paso 3 — Autorización FamilyControls (si no está aprobada)
      _setStatus('Verificando autorización…');
      var authStatus = await _familyControls.checkAuthorization();
      if (authStatus != ScreenTimeAuthorizationStatus.approved) {
        _setStatus('Solicitando autorización FamilyControls…');
        authStatus = await _familyControls.requestAuthorization();
        if (authStatus != ScreenTimeAuthorizationStatus.approved) {
          _showError('Autorización denegada. Actívala en Ajustes > Tiempo en Pantalla.');
          return;
        }
      }

      // Paso 4 — Seleccionar apps (abre el picker del sistema)
      _setStatus('Abriendo selector de apps…');
      final summary = await _familyControls.selectBlockedApps();

      if (summary.applicationCount == 0 && summary.categoryCount == 0) {
        _showSnackBar('No se seleccionó ninguna app. Bloqueo no iniciado.');
        return;
      }

      // Paso 5 — Iniciar bloqueo
      _setStatus('Iniciando bloqueo…');
      await _managedSettings.startBlocking();

      _showSnackBar(
        'Listo: ${summary.applicationCount} app(s) y '
        '${summary.categoryCount} categoría(s) bloqueadas.',
        success: true,
      );
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _initStatus = status);
  }

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : null,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_screentime'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -----------------------------------------------------------------
          // Botón Quick Init
          // -----------------------------------------------------------------
          _InitButton(
            isLoading: _isInitializing,
            status: _initStatus,
            onPressed: _isInitializing ? null : _quickInit,
            theme: theme,
          ),
          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Menú de pantallas
          // -----------------------------------------------------------------
          _MenuCard(
            title: 'FamilyControls',
            subtitle: 'Autorización y selección de apps bloqueadas',
            icon: Icons.family_restroom,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FamilyControlsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'ManagedSettings',
            subtitle: 'Activar y desactivar el bloqueo de apps',
            icon: Icons.settings_applications,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ManagedSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'DeviceActivity',
            subtitle: 'Horarios automáticos y límites de tiempo',
            icon: Icons.schedule,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DeviceActivityScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'Shield — Configuración',
            subtitle: 'Personalizar la pantalla de bloqueo',
            icon: Icons.shield,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ShieldConfigScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'Shield — Eventos',
            subtitle: 'Streams de ShieldAction y ActivityEvent',
            icon: Icons.stream,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ShieldEventsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'Solicitud de Permiso',
            subtitle: 'Aprueba acceso temporal desde la pantalla de bloqueo',
            icon: Icons.lock_open_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PermissionRequestScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón de Init rápido
// ---------------------------------------------------------------------------

class _InitButton extends StatelessWidget {
  const _InitButton({
    required this.isLoading,
    required this.status,
    required this.onPressed,
    required this.theme,
  });

  final bool isLoading;
  final String status;
  final VoidCallback? onPressed;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rocket_launch_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Init',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'App Group → Shield → Autorización → Picker → Bloqueo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            if (isLoading) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Init'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu card
// ---------------------------------------------------------------------------

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}
