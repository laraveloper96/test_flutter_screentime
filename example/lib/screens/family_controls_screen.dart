import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_control_parental/flutter_control_parental.dart';

class FamilyControlsScreen extends StatefulWidget {
  const FamilyControlsScreen({super.key});

  @override
  State<FamilyControlsScreen> createState() => _FamilyControlsScreenState();
}

class _FamilyControlsScreenState extends State<FamilyControlsScreen> {
  final _familyControls = const FamilyControls();

  ScreenTimeAuthorizationStatus _authStatus =
      ScreenTimeAuthorizationStatus.notDetermined;
  SelectedAppsSummary _summary = const SelectedAppsSummary(
    applicationCount: 0,
    categoryCount: 0,
    webDomainCount: 0,
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _refreshSummary();
  }

  Future<void> _checkAuthorization() async {
    try {
      final status = await _familyControls.checkAuthorization();
      if (!mounted) return;
      setState(() => _authStatus = status);
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    }
  }

  Future<void> _requestAuthorization() async {
    setState(() => _isLoading = true);
    try {
      final status = await _familyControls.requestAuthorization();
      if (!mounted) return;
      setState(() => _authStatus = status);
      _showSnackBar('Autorización actualizada: ${status.platformValue}');
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeAuthorization() async {
    setState(() => _isLoading = true);
    try {
      await _familyControls.revokeAuthorization();
      if (!mounted) return;
      await _checkAuthorization();
      await _refreshSummary();
      _showSnackBar('Autorización revocada');
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSummary() async {
    try {
      final summary = await _familyControls.getSelectedAppsSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on PlatformException catch (e) {
      _showError(e.message ?? e.code);
    }
  }

  Future<void> _selectApps() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _familyControls.selectBlockedApps();
      if (!mounted) return;
      setState(() => _summary = summary);
      _showSnackBar(
        'Selección guardada: ${summary.applicationCount} apps, '
        '${summary.categoryCount} categorías, '
        '${summary.webDomainCount} dominios',
      );
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') {
        _showSnackBar('Selección cancelada');
      } else {
        _showError(e.message ?? e.code);
      }
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

  Color _statusColor() {
    switch (_authStatus) {
      case ScreenTimeAuthorizationStatus.approved:
        return Colors.green;
      case ScreenTimeAuthorizationStatus.denied:
        return Colors.red;
      case ScreenTimeAuthorizationStatus.notDetermined:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyControls'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Authorization status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de autorización',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _authStatus.platformValue,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _statusColor(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Authorization buttons
          FilledButton(
            onPressed: _isLoading ? null : _requestAuthorization,
            child: const Text('Solicitar autorización'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isLoading ? null : _revokeAuthorization,
            child: const Text('Revocar autorización'),
          ),
          const SizedBox(height: 24),

          // Selected apps summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Apps seleccionadas',
                        style: theme.textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _isLoading ? null : _refreshSummary,
                        tooltip: 'Actualizar resumen',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Apps',
                    count: _summary.applicationCount,
                    icon: Icons.apps,
                  ),
                  const SizedBox(height: 4),
                  _SummaryRow(
                    label: 'Categorías',
                    count: _summary.categoryCount,
                    icon: Icons.category,
                  ),
                  const SizedBox(height: 4),
                  _SummaryRow(
                    label: 'Dominios web',
                    count: _summary.webDomainCount,
                    icon: Icons.language,
                  ),
                  const Divider(height: 16),
                  _SummaryRow(
                    label: 'Total',
                    count: _summary.totalCount,
                    icon: Icons.summarize,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Open app picker
          FilledButton.icon(
            onPressed: _isLoading ? null : _selectApps,
            icon: const Icon(Icons.app_blocking),
            label: const Text('Abrir selector de apps'),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          '$count',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
