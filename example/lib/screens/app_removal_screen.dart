import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_control_parental/flutter_control_parental.dart';

class AppRemovalScreen extends StatefulWidget {
  const AppRemovalScreen({super.key});

  @override
  State<AppRemovalScreen> createState() => _AppRemovalScreenState();
}

class _AppRemovalScreenState extends State<AppRemovalScreen> {
  final _managedSettings = const ManagedSettings();

  bool _isDenyingRemoval = false;
  bool _isLoading = false;
  String? _storedPin;

  // ---------------------------------------------------------------------------
  // PIN setup
  // ---------------------------------------------------------------------------

  Future<void> _setupPin() async {
    final pin = await _showPinDialog(
      title: 'Configurar PIN',
      message: 'Ingresa un PIN de 4 dígitos para proteger la desinstalación.',
    );
    if (pin == null) return;

    final confirm = await _showPinDialog(
      title: 'Confirmar PIN',
      message: 'Vuelve a ingresar el PIN para confirmar.',
    );
    if (confirm == null) return;

    if (pin != confirm) {
      _showError('Los PIN no coinciden. Intenta de nuevo.');
      return;
    }

    setState(() => _storedPin = pin);

    // Activar protección contra desinstalación
    await _setDenyRemoval(true);
    _showSnackBar('PIN configurado y protección activada');
  }

  // ---------------------------------------------------------------------------
  // Toggle deny app removal
  // ---------------------------------------------------------------------------

  Future<void> _toggleDenyRemoval() async {
    if (_storedPin == null) {
      _showError('Configura un PIN primero.');
      return;
    }

    if (_isDenyingRemoval) {
      // Quiere permitir desinstalación → pedir PIN
      final pin = await _showPinDialog(
        title: 'Confirmar PIN',
        message:
            'Ingresa tu PIN para permitir la desinstalación de la aplicación.',
      );
      if (pin == null) return;
      if (pin != _storedPin) {
        _showError('PIN incorrecto.');
        return;
      }
      await _setDenyRemoval(false);
      _showSnackBar('Desinstalación permitida');
    } else {
      // Quiere bloquear desinstalación de nuevo
      await _setDenyRemoval(true);
      _showSnackBar('Desinstalación bloqueada');
    }
  }

  Future<void> _setDenyRemoval(bool deny) async {
    setState(() => _isLoading = true);
    try {
      await _managedSettings.setDenyAppRemoval(deny);
      if (!mounted) return;
      setState(() => _isDenyingRemoval = deny);
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // PIN dialog
  // ---------------------------------------------------------------------------

  Future<String?> _showPinDialog({
    required String title,
    required String message,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: '····',
                ),
                onSubmitted: (value) {
                  if (value.length == 4) Navigator.of(ctx).pop(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text;
                if (value.length == 4) {
                  Navigator.of(ctx).pop(value);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPin = _storedPin != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Protección de desinstalación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            color: _isDenyingRemoval
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isDenyingRemoval ? Icons.lock : Icons.lock_open,
                    color: _isDenyingRemoval
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desinstalación',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          _isDenyingRemoval ? 'BLOQUEADA' : 'PERMITIDA',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isDenyingRemoval
                                ? theme.colorScheme.error
                                : theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // PIN section
          Text('PIN parental', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasPin ? Icons.check_circle : Icons.warning_amber,
                        color: hasPin ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasPin ? 'PIN configurado' : 'PIN no configurado',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _setupPin,
                    child: Text(
                      hasPin ? 'Cambiar PIN' : 'Configurar PIN',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Toggle deny removal
          Text('Control de desinstalación', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_isLoading || !hasPin) ? null : _toggleDenyRemoval,
            icon: Icon(
              _isDenyingRemoval ? Icons.lock_open : Icons.lock,
            ),
            label: Text(
              _isDenyingRemoval
                  ? 'Permitir desinstalación'
                  : 'Bloquear desinstalación',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _isDenyingRemoval
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              foregroundColor: _isDenyingRemoval
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onError,
            ),
          ),
          if (!hasPin) ...[
            const SizedBox(height: 8),
            Text(
              'Configura un PIN para habilitar esta opción.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
