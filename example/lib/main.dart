import 'package:flutter/material.dart';

import 'screens/family_controls_screen.dart';
import 'screens/managed_settings_screen.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_screentime'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                builder: (_) => const _PlaceholderScreen(
                  title: 'DeviceActivity',
                  message: 'DeviceActivity - próximamente',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            title: 'ShieldExtension',
            subtitle: 'Configurar la pantalla de bloqueo',
            icon: Icons.shield,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const _PlaceholderScreen(
                  title: 'ShieldExtension',
                  message: 'ShieldExtension - próximamente',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(message)),
    );
  }
}
