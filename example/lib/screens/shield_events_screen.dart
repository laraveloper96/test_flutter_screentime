// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_control_parental/src/shield_extension.dart';

class ShieldEventsScreen extends StatefulWidget {
  const ShieldEventsScreen({super.key});

  @override
  State<ShieldEventsScreen> createState() => _ShieldEventsScreenState();
}

class _ShieldEventsScreenState extends State<ShieldEventsScreen> {
  final _shieldExtension = const ShieldExtension();

  // Shield Action stream
  StreamSubscription<ShieldAction>? _shieldActionSub;
  final List<_EventEntry> _shieldActionEvents = [];
  bool _listeningShieldActions = false;

  // Activity Event stream
  StreamSubscription<ActivityEvent>? _activityEventSub;
  final List<_EventEntry> _activityEvents = [];
  bool _listeningActivityEvents = false;

  // -------------------------------------------------------------------------
  // Shield Action controls
  // -------------------------------------------------------------------------

  void _startShieldActions() {
    if (_listeningShieldActions) return;
    _shieldActionSub = _shieldExtension.onShieldAction().listen(
      (action) {
        setState(() {
          _shieldActionEvents.insert(
            0,
            _EventEntry(
              label: action == ShieldAction.primaryButton
                  ? 'Botón primario pulsado'
                  : 'Botón secundario pulsado',
              timestamp: DateTime.now(),
            ),
          );
        });
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en ShieldAction stream: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    setState(() => _listeningShieldActions = true);
  }

  void _stopShieldActions() {
    _shieldActionSub?.cancel();
    _shieldActionSub = null;
    setState(() => _listeningShieldActions = false);
  }

  // -------------------------------------------------------------------------
  // Activity Event controls
  // -------------------------------------------------------------------------

  void _startActivityEvents() {
    if (_listeningActivityEvents) return;
    _activityEventSub = _shieldExtension.onActivityEvent().listen(
      (event) {
        setState(() {
          _activityEvents.insert(
            0,
            _EventEntry(
              label: '[${event.type.name}] ${event.activityName}',
              timestamp: event.timestamp,
            ),
          );
        });
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en ActivityEvent stream: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    setState(() => _listeningActivityEvents = true);
  }

  void _stopActivityEvents() {
    _activityEventSub?.cancel();
    _activityEventSub = null;
    setState(() => _listeningActivityEvents = false);
  }

  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _shieldActionSub?.cancel();
    _activityEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos de Shield')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -----------------------------------------------------------------
          // Sección: ShieldAction events
          // -----------------------------------------------------------------
          _SectionHeader(title: 'ShieldAction events'),
          const SizedBox(height: 8),
          _StatusChip(active: _listeningShieldActions),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _listeningShieldActions ? null : _startShieldActions,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar escucha'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _listeningShieldActions ? _stopShieldActions : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Detener escucha'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EventList(events: _shieldActionEvents, emptyMessage: 'Sin eventos aún.'),
          const SizedBox(height: 32),

          // -----------------------------------------------------------------
          // Sección: ActivityEvent events
          // -----------------------------------------------------------------
          _SectionHeader(title: 'ActivityEvent events'),
          const SizedBox(height: 8),
          _StatusChip(active: _listeningActivityEvents),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _listeningActivityEvents ? null : _startActivityEvents,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar escucha'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _listeningActivityEvents ? _stopActivityEvents : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Detener escucha'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EventList(events: _activityEvents, emptyMessage: 'Sin eventos aún.'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de UI
// ---------------------------------------------------------------------------

class _EventEntry {
  const _EventEntry({required this.label, required this.timestamp});
  final String label;
  final DateTime timestamp;

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.circle : Icons.circle_outlined,
          size: 12,
          color: active ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          active ? 'Escuchando...' : 'Detenido',
          style: TextStyle(
            color: active ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.emptyMessage});
  final List<_EventEntry> events;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = events[index];
          return ListTile(
            dense: true,
            title: Text(entry.label, style: const TextStyle(fontSize: 13)),
            trailing: Text(
              entry.formattedTime,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
