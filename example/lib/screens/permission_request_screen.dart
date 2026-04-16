// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screentime/src/shield_extension.dart';

class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  final _shield = const ShieldExtension();

  StreamSubscription<void>? _permissionSub;

  // Estado de la solicitud pendiente
  bool _hasPendingRequest = false;
  DateTime? _requestTime;

  // Estado del acceso temporal
  bool _temporaryAccessActive = false;
  DateTime? _accessExpiresAt;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  // Log de eventos
  final List<_LogEntry> _log = [];

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Stream
  // -------------------------------------------------------------------------

  void _startListening() {
    _permissionSub = _shield.onPermissionRequest().listen(
      (_) => _onPermissionRequest(),
      onError: (Object error) {
        _addLog('Error en stream: $error', isError: true);
      },
    );
  }

  void _onPermissionRequest() {
    setState(() {
      _hasPendingRequest = true;
      _requestTime = DateTime.now();
    });
    _addLog('Solicitud de permiso recibida desde el Shield');
    _showPermissionDialog();
  }

  // -------------------------------------------------------------------------
  // Diálogo de aprobación
  // -------------------------------------------------------------------------

  void _showPermissionDialog() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PermissionBottomSheet(
        requestTime: _requestTime!,
        onGrant: (duration) {
          Navigator.of(ctx).pop();
          _grantAccess(duration);
        },
        onDeny: () {
          Navigator.of(ctx).pop();
          _denyAccess();
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Acciones
  // -------------------------------------------------------------------------

  Future<void> _grantAccess(Duration duration) async {
    try {
      await _shield.grantTemporaryAccess(duration: duration);
      final expiresAt = DateTime.now().add(duration);
      setState(() {
        _hasPendingRequest = false;
        _temporaryAccessActive = true;
        _accessExpiresAt = expiresAt;
        _remaining = duration;
      });
      _addLog(
        'Acceso concedido por ${_formatDuration(duration)}',
        isSuccess: true,
      );
      _startCountdown(duration);
    } catch (e) {
      _addLog('Error al conceder acceso: $e', isError: true);
    }
  }

  void _denyAccess() {
    setState(() {
      _hasPendingRequest = false;
    });
    _addLog('Solicitud denegada');
  }

  void _startCountdown(Duration total) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _accessExpiresAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        setState(() {
          _temporaryAccessActive = false;
          _remaining = Duration.zero;
        });
        _addLog('Acceso temporal expirado — bloqueo reactivado');
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  // -------------------------------------------------------------------------
  // Log
  // -------------------------------------------------------------------------

  void _addLog(String message, {bool isError = false, bool isSuccess = false}) {
    setState(() {
      _log.insert(
        0,
        _LogEntry(
          message: message,
          time: DateTime.now(),
          isError: isError,
          isSuccess: isSuccess,
        ),
      );
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de Permiso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -----------------------------------------------------------------
          // Estado del stream
          // -----------------------------------------------------------------
          _SectionTitle('Estado'),
          const SizedBox(height: 8),
          _StatusCard(
            icon: Icons.sensors,
            label: 'Escuchando solicitudes del Shield',
            active: _permissionSub != null,
            color: Colors.green,
          ),
          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Solicitud pendiente
          // -----------------------------------------------------------------
          if (_hasPendingRequest) ...[
            _SectionTitle('Solicitud pendiente'),
            const SizedBox(height: 8),
            _PendingRequestCard(
              requestTime: _requestTime!,
              onGrant: _showPermissionDialog,
              onDeny: _denyAccess,
            ),
            const SizedBox(height: 24),
          ],

          // -----------------------------------------------------------------
          // Acceso temporal activo
          // -----------------------------------------------------------------
          if (_temporaryAccessActive) ...[
            _SectionTitle('Acceso temporal activo'),
            const SizedBox(height: 8),
            _AccessCountdownCard(
              remaining: _remaining,
              expiresAt: _accessExpiresAt!,
            ),
            const SizedBox(height: 24),
          ],

          // -----------------------------------------------------------------
          // Instrucciones
          // -----------------------------------------------------------------
          if (!_hasPendingRequest && !_temporaryAccessActive) ...[
            _InfoBanner(
              icon: Icons.info_outline,
              text:
                  'Esta pantalla escucha automáticamente cuando el usuario pulsa '
                  '"Pedir permiso" en la pantalla de bloqueo (Shield).\n\n'
                  'Asegúrate de tener la ShieldActionExtension configurada '
                  'en Xcode y que el botón primario esté etiquetado '
                  'como "Pedir permiso".',
            ),
            const SizedBox(height: 24),
          ],

          // -----------------------------------------------------------------
          // Configuración recomendada del Shield
          // -----------------------------------------------------------------
          _SectionTitle('Configuración del Shield para esta demo'),
          const SizedBox(height: 8),
          _ConfigHint(theme: theme),
          const SizedBox(height: 24),

          // -----------------------------------------------------------------
          // Log de eventos
          // -----------------------------------------------------------------
          _SectionTitle('Registro de eventos'),
          const SizedBox(height: 8),
          _LogList(entries: _log),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds} seg';
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet de permiso
// ---------------------------------------------------------------------------

class _PermissionBottomSheet extends StatelessWidget {
  const _PermissionBottomSheet({
    required this.requestTime,
    required this.onGrant,
    required this.onDeny,
  });

  final DateTime requestTime;
  final void Function(Duration) onGrant;
  final VoidCallback onDeny;

  static const _durations = [
    (label: '5 min', value: Duration(minutes: 5)),
    (label: '15 min', value: Duration(minutes: 15)),
    (label: '30 min', value: Duration(minutes: 30)),
    (label: '1 hora', value: Duration(hours: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icono + título
          Icon(
            Icons.lock_open_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Solicitud de permiso',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Se recibió una solicitud desde la pantalla de bloqueo.\n'
            '¿Cuánto tiempo deseas conceder?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Opciones de duración
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _durations.map((d) {
              return FilledButton(
                onPressed: () => onGrant(d.value),
                child: Text(d.label),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Denegar
          OutlinedButton(
            onPressed: onDeny,
            child: const Text('Denegar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets de soporte
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? color : Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.requestTime,
    required this.onGrant,
    required this.onDeny,
  });

  final DateTime requestTime;
  final VoidCallback onGrant;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = requestTime.hour.toString().padLeft(2, '0');
    final m = requestTime.minute.toString().padLeft(2, '0');
    final s = requestTime.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Solicitud a las $h:$m:$s',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onGrant,
                  child: const Text('Conceder acceso'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onDeny,
                child: const Text('Denegar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessCountdownCard extends StatelessWidget {
  const _AccessCountdownCard({
    required this.remaining,
    required this.expiresAt,
  });

  final Duration remaining;
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = remaining.inMinutes.toString().padLeft(2, '0');
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.green, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$mins:$secs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Acceso temporal activo',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigHint extends StatelessWidget {
  const _ConfigHint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configura el Shield con estos labels:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _CodeRow(label: 'primaryButtonLabel', value: 'Pedir permiso'),
          _CodeRow(label: 'secondaryButtonLabel', value: 'Cancelar'),
          const SizedBox(height: 8),
          Text(
            'Puedes configurarlo en la pantalla "Shield — Configuración".',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            '"$value"',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log
// ---------------------------------------------------------------------------

class _LogEntry {
  const _LogEntry({
    required this.message,
    required this.time,
    this.isError = false,
    this.isSuccess = false,
  });

  final String message;
  final DateTime time;
  final bool isError;
  final bool isSuccess;

  String get formattedTime {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color get color {
    if (isError) return Colors.red;
    if (isSuccess) return Colors.green;
    return Colors.grey;
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.entries});
  final List<_LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Sin eventos aún.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = entries[i];
          return ListTile(
            dense: true,
            leading: Icon(
              e.isError
                  ? Icons.error_outline
                  : e.isSuccess
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              color: e.color,
              size: 16,
            ),
            title: Text(e.message, style: TextStyle(fontSize: 12, color: e.color)),
            trailing: Text(
              e.formattedTime,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
