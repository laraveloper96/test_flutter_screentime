// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter_screentime/src/shield_extension.dart';

class ShieldConfigScreen extends StatefulWidget {
  const ShieldConfigScreen({super.key});

  @override
  State<ShieldConfigScreen> createState() => _ShieldConfigScreenState();
}

class _ShieldConfigScreenState extends State<ShieldConfigScreen> {
  final _titleController = TextEditingController(text: 'App Bloqueada');
  final _subtitleController = TextEditingController(
    text: 'Este contenido no está disponible en este momento.',
  );
  final _primaryLabelController = TextEditingController(text: 'Entendido');
  final _secondaryLabelController = TextEditingController(text: 'Ignorar');
  final _bgColorController = TextEditingController(text: '#111827');
  final _primaryColorController = TextEditingController(text: '#3B82F6');
  final _primaryTextColorController = TextEditingController(text: '#FFFFFF');

  ShieldBackgroundBlurStyle _blurStyle = ShieldBackgroundBlurStyle.dark;

  final GlobalKey _repaintKey = GlobalKey();
  final _shieldExtension = const ShieldExtension();

  Color? _parseHex(String hex) {
    try {
      var h = hex.trim();
      if (h.startsWith('#')) h = h.substring(1);
      if (h.length == 6) h = 'FF$h';
      if (h.length != 8) return null;
      final value = int.parse(h, radix: 16);
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyConfig() async {
    final config = ScreenTimeBlockScreenConfig(
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      subtitle: _subtitleController.text.trim().isEmpty
          ? null
          : _subtitleController.text.trim(),
      primaryButtonLabel: _primaryLabelController.text.trim().isEmpty
          ? null
          : _primaryLabelController.text.trim(),
      secondaryButtonLabel: _secondaryLabelController.text.trim().isEmpty
          ? null
          : _secondaryLabelController.text.trim(),
      backgroundColorHex: _bgColorController.text.trim().isEmpty
          ? null
          : _bgColorController.text.trim(),
      primaryButtonColorHex: _primaryColorController.text.trim().isEmpty
          ? null
          : _primaryColorController.text.trim(),
      primaryButtonTextColorHex: _primaryTextColorController.text.trim().isEmpty
          ? null
          : _primaryTextColorController.text.trim(),
      backgroundBlurStyle: _blurStyle,
    );

    try {
      await _shieldExtension.configureShield(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración aplicada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aplicar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _captureWidgetAsIcon() async {
    try {
      await _shieldExtension.captureWidgetAsIcon(_repaintKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widget capturado y guardado como ícono.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar widget: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _primaryLabelController.dispose();
    _secondaryLabelController.dispose();
    _bgColorController.dispose();
    _primaryColorController.dispose();
    _primaryTextColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Shield')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------------------------------------------------------
          // Sección: Configuración de texto
          // ---------------------------------------------------------------
          _SectionHeader(title: 'Configuración de texto'),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitleController,
            decoration: const InputDecoration(
              labelText: 'Subtítulo',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _primaryLabelController,
            decoration: const InputDecoration(
              labelText: 'Etiqueta botón primario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secondaryLabelController,
            decoration: const InputDecoration(
              labelText: 'Etiqueta botón secundario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------
          // Sección: Colores
          // ---------------------------------------------------------------
          _SectionHeader(title: 'Colores'),
          const SizedBox(height: 12),
          _ColorField(
            controller: _bgColorController,
            label: 'Color de fondo (hex)',
            parseHex: _parseHex,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _ColorField(
            controller: _primaryColorController,
            label: 'Color botón primario (hex)',
            parseHex: _parseHex,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _ColorField(
            controller: _primaryTextColorController,
            label: 'Color texto botón primario (hex)',
            parseHex: _parseHex,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------
          // Sección: Estilo de fondo
          // ---------------------------------------------------------------
          _SectionHeader(title: 'Estilo de fondo (blur)'),
          const SizedBox(height: 12),
          SegmentedButton<ShieldBackgroundBlurStyle>(
            segments: const [
              ButtonSegment(
                value: ShieldBackgroundBlurStyle.dark,
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ShieldBackgroundBlurStyle.light,
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ShieldBackgroundBlurStyle.none,
                label: Text('None'),
              ),
            ],
            selected: {_blurStyle},
            onSelectionChanged: (selected) {
              setState(() => _blurStyle = selected.first);
            },
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------
          // Botón: Aplicar configuración
          // ---------------------------------------------------------------
          FilledButton.icon(
            onPressed: _applyConfig,
            icon: const Icon(Icons.check),
            label: const Text('Aplicar configuración'),
          ),
          const SizedBox(height: 32),

          // ---------------------------------------------------------------
          // Sección: Ícono personalizado
          // ---------------------------------------------------------------
          _SectionHeader(title: 'Ícono personalizado'),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Para seleccionar un PNG desde la galería, agrega '
                      '"image_picker" como dependencia en el pubspec.yaml del '
                      'ejemplo y reconstruye el proyecto.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Demo: capturar widget como ícono',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _repaintKey,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FlutterLogo(size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'flutter_screentime',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Shield Icon Preview',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _captureWidgetAsIcon,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capturar este widget como ícono'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de UI
// ---------------------------------------------------------------------------

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

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.controller,
    required this.label,
    required this.parseHex,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Color? Function(String) parseHex;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final color = parseHex(value.text);
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: color == null
                  ? const Icon(Icons.block, size: 20, color: Colors.grey)
                  : null,
            ),
          ],
        );
      },
    );
  }
}
