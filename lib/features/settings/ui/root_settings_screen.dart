import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/features/agent/data/screen_control_service.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';

/// Root detection + privileged shell command runner.
class RootSettingsScreen extends StatefulWidget {
  const RootSettingsScreen({super.key});

  @override
  State<RootSettingsScreen> createState() => _RootSettingsScreenState();
}

class _RootSettingsScreenState extends State<RootSettingsScreen> {
  final _commandController = TextEditingController();
  String _status = 'Detecting root…';
  bool _checking = true;
  bool _rooted = false;
  String _lastOutput = '';

  @override
  void initState() {
    super.initState();
    _detect();
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() => _checking = true);
    final hasSu = await ScreenControlService.isRooted();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _rooted = hasSu;
      _status = hasSu
          ? 'Root detected (su available on this device).'
          : 'No root detected. Commands will run without elevated privileges.';
    });
  }

  void _run() {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) return;
    ScreenControlService.runAsRoot(cmd).then((out) {
      if (!mounted) return;
      setState(() {
        _lastOutput = out;
        _status = 'Last run: $cmd';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Root & Privileged Tools',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => context.pop(),
              ),
              actions: [
                TextButton(
                    onPressed: _detect, child: const Text('Re-detect')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: glass.glassColor,
                borderRadius: BorderRadius.circular(glass.radiusSm),
                border: Border.all(color: glass.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _checking
                            ? AppIcons.rotateCcw
                            : (_rooted
                                ? AppIcons.shieldCheck
                                : AppIcons.alertCircle),
                        color: _checking
                            ? glass.textSecondary
                            : (_rooted ? Colors.green : Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _checking ? 'Detecting…' : _status,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (!_rooted) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rooted-only tools are disabled on this device. '
                      'The agent will still see them, but execution will '
                      'fail gracefully.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: glass.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Run command as root',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. getprop ro.build.version.release',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _run,
                    child: const Text('Run as root')),
              ],
            ),
            if (_lastOutput.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Last output',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: glass.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: glass.glassColor,
                  borderRadius: BorderRadius.circular(glass.radiusSm),
                  border: Border.all(color: glass.glassBorder),
                ),
                child: SelectableText(
                  _lastOutput,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
