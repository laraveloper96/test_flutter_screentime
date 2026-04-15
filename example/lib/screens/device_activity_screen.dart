// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screentime/src/device_activity.dart';

class DeviceActivityScreen extends StatefulWidget {
  const DeviceActivityScreen({super.key});

  @override
  State<DeviceActivityScreen> createState() => _DeviceActivityScreenState();
}

class _DeviceActivityScreenState extends State<DeviceActivityScreen> {
  final _deviceActivity = const DeviceActivity();

  TimeOfDay _startTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _selectedWeekdays = {};
  final TextEditingController _dailyLimitController = TextEditingController();

  ScreenTimeSchedule? _currentSchedule;

  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    _dailyLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    try {
      final schedule = await _deviceActivity.getSchedule();
      if (!mounted) return;
      setState(() {
        _currentSchedule = schedule;
        if (schedule != null) {
          _startTime = schedule.start;
          _endTime = schedule.end;
          _selectedWeekdays.clear();
          if (schedule.weekdays != null) {
            _selectedWeekdays.addAll(schedule.weekdays!);
          }
          if (schedule.dailyTimeLimit != null) {
            _dailyLimitController.text =
                (schedule.dailyTimeLimit!.inSeconds ~/ 60).toString();
          } else {
            _dailyLimitController.clear();
          }
        }
      });
    } on PlatformException catch (e) {
      _showSnackBar('Error al cargar horario: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackBar('Error al cargar horario: $e');
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora de inicio',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Hora de fin',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  Future<void> _saveSchedule() async {
    Duration? dailyLimit;
    final limitText = _dailyLimitController.text.trim();
    if (limitText.isNotEmpty) {
      final minutes = int.tryParse(limitText);
      if (minutes == null || minutes <= 0) {
        _showSnackBar('El límite diario debe ser un número positivo de minutos');
        return;
      }
      dailyLimit = Duration(minutes: minutes);
    }

    final schedule = ScreenTimeSchedule(
      start: _startTime,
      end: _endTime,
      weekdays: _selectedWeekdays.isEmpty
          ? null
          : (_selectedWeekdays.toList()..sort()),
      dailyTimeLimit: dailyLimit,
    );

    try {
      await _deviceActivity.setSchedule(schedule);
      if (!mounted) return;
      _showSnackBar('Horario guardado e iniciado');
      await _loadSchedule();
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _startMonitoring() async {
    try {
      await _deviceActivity.startMonitoring();
      if (!mounted) return;
      _showSnackBar('Monitoreo iniciado');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _stopMonitoring() async {
    try {
      await _deviceActivity.stopMonitoring();
      if (!mounted) return;
      _showSnackBar('Monitoreo detenido');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _clearSchedule() async {
    try {
      await _deviceActivity.clearSchedule();
      if (!mounted) return;
      _showSnackBar('Horario eliminado');
      await _loadSchedule();
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeviceActivity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar horario',
            onPressed: _loadSchedule,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Sección: Configurar horario ---
          Text('Configurar horario', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hora de inicio y fin
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text('Inicio: ${_formatTime(_startTime)}'),
                          onPressed: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text('Fin: ${_formatTime(_endTime)}'),
                          onPressed: _pickEndTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Días de la semana
                  Text('Días', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      final selected = _selectedWeekdays.contains(day);
                      return FilterChip(
                        label: Text(_weekdayLabels[index]),
                        selected: selected,
                        onSelected: (_) => _toggleWeekday(day),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedWeekdays.isEmpty
                        ? 'Sin días seleccionados = todos los días'
                        : '${_selectedWeekdays.length} día(s) seleccionado(s)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  // Límite diario
                  TextField(
                    controller: _dailyLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Límite diario (minutos)',
                      hintText: 'Opcional — deja vacío para sin límite',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar horario'),
                      onPressed: _saveSchedule,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Sección: Horario activo ---
          Text('Horario activo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _currentSchedule == null
                  ? const Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('Sin horario configurado'),
                      ],
                    )
                  : _ScheduleDetail(schedule: _currentSchedule!),
            ),
          ),

          const SizedBox(height: 24),

          // --- Sección: Control de monitoreo ---
          Text('Control de monitoreo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar monitoreo'),
            onPressed: _startMonitoring,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Detener monitoreo'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
            onPressed: _stopMonitoring,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Limpiar horario'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: _clearSchedule,
          ),
        ],
      ),
    );
  }
}

class _ScheduleDetail extends StatelessWidget {
  const _ScheduleDetail({required this.schedule});

  final ScreenTimeSchedule schedule;

  static const _weekdayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = schedule.weekdays;
    final weekdayText = weekdays == null || weekdays.isEmpty
        ? 'Todos los días'
        : weekdays.map((d) => _weekdayNames[d - 1]).join(', ');

    final limit = schedule.dailyTimeLimit;
    final limitText = limit == null
        ? 'Sin límite'
        : '${limit.inMinutes} minutos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(
          icon: Icons.schedule,
          label: 'Inicio',
          value: _formatTime(schedule.start),
          theme: theme,
        ),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: 'Fin',
          value: _formatTime(schedule.end),
          theme: theme,
        ),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.calendar_today,
          label: 'Días',
          value: weekdayText,
          theme: theme,
        ),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.timer_outlined,
          label: 'Límite diario',
          value: limitText,
          theme: theme,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
