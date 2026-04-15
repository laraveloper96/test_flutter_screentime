import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screentime/flutter_screentime.dart';

class ManagedSettingsScreen extends StatefulWidget {
  const ManagedSettingsScreen({super.key});

  @override
  State<ManagedSettingsScreen> createState() => _ManagedSettingsScreenState();
}

class _ManagedSettingsScreenState extends State<ManagedSettingsScreen> {
  final _managedSettings = const ManagedSettings();
  final _appGroupController = TextEditingController(
      text: "group.com.ssssstudios.time4kids");

  bool _isBlocking = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAppGroupAndStatus();
  }

  Future<void> _initAppGroupAndStatus() async {
    // Guardar el App Group ID automáticamente al entrar a la pantalla,
    // para que configureShield() siempre tenga acceso al App Group.
    final groupId = _appGroupController.text.trim();
    if (groupId.isNotEmpty) {
      try {
        await _managedSettings.setSharedContainerId(groupId);
      } on PlatformException catch (_) {
        // Ignorar: el usuario puede corregirlo manualmente.
      }
    }
    _refreshBlockingStatus();
  }

  @override
  void dispose() {
    _appGroupController.dispose();
    super.dispose();
  }

  Future<void> _refreshBlockingStatus() async {
    try {
      final status = await _managedSettings.getBlockingStatus();
      if (!mounted) return;
      setState(() => _isBlocking = status);
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    }
  }

  Future<void> _saveAppGroupId() async {
    final groupId = _appGroupController.text.trim();
    if (groupId.isEmpty) {
      _showError('Ingresa un App Group ID válido');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _managedSettings.setSharedContainerId(groupId);
      if (!mounted) return;
      _showSnackBar('App Group ID guardado: $groupId');
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startBlocking() async {
    setState(() => _isLoading = true);
    try {
      await _managedSettings.startBlocking();
      if (!mounted) return;
      await _refreshBlockingStatus();
      _showSnackBar('Bloqueo iniciado');
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopBlocking() async {
    setState(() => _isLoading = true);
    try {
      await _managedSettings.stopBlocking();
      if (!mounted) return;
      await _refreshBlockingStatus();
      _showSnackBar('Bloqueo detenido');
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ManagedSettings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Blocking status card
          Card(
            color: _isBlocking
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isBlocking ? Icons.block : Icons.check_circle_outline,
                    color: _isBlocking
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado del bloqueo',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        _isBlocking ? 'ACTIVO' : 'INACTIVO',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isBlocking
                              ? theme.colorScheme.error
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _refreshBlockingStatus,
                    tooltip: 'Actualizar estado',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Group ID section
          Text('App Group ID', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _appGroupController,
            decoration: const InputDecoration(
              hintText: 'group.com.tuempresa.app',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group_work_outlined),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveAppGroupId(),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _isLoading ? null : _saveAppGroupId,
            child: const Text('Guardar App Group ID'),
          ),
          const SizedBox(height: 24),

          // Blocking controls
          Text('Control de bloqueo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_isLoading || _isBlocking) ? null : _startBlocking,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar bloqueo'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_isLoading || !_isBlocking) ? null : _stopBlocking,
            icon: const Icon(Icons.stop),
            label: const Text('Detener bloqueo'),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
