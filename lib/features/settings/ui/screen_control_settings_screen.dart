import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/features/agent/data/screen_control_service.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';

/// Live screen view + control UI: MediaProjection consent flow, polling the
/// native frame pipeline, and manual input injection controls.
class ScreenControlSettingsScreen extends StatefulWidget {
  const ScreenControlSettingsScreen({super.key});

  @override
  State<ScreenControlSettingsScreen> createState() =>
      _ScreenControlSettingsScreenState();
}

class _ScreenControlSettingsScreenState
    extends State<ScreenControlSettingsScreen> {
  bool _started = false;
  String? _lastFramePath;
  Timer? _poller;
  final _tapX = TextEditingController();
  final _tapY = TextEditingController();
  final _swipeFromX = TextEditingController();
  final _swipeFromY = TextEditingController();
  final _swipeToX = TextEditingController();
  final _swipeToY = TextEditingController();
  final _textController = TextEditingController();
  final _keycodeController = TextEditingController();
  String _status = 'Not started. Tap "Start capture" to grant screen permission.';

  @override
  void dispose() {
    _poller?.cancel();
    _tapX.dispose();
    _tapY.dispose();
    _swipeFromX.dispose();
    _swipeFromY.dispose();
    _swipeToX.dispose();
    _swipeToY.dispose();
    _textController.dispose();
    _keycodeController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final res = await ScreenControlService.beginCapture();
    if (!mounted) return;
    setState(() {
      _started = true;
      _status = res;
    });
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(milliseconds: 800), (_) {
      ScreenControlService.getLiveFrame().then((p) {
        if (!mounted) return;
        if (p != null && p != _lastFramePath) {
          setState(() {
            _lastFramePath = p;
          });
        }
      });
    });
  }

  Future<void> _stop() async {
    final res = await ScreenControlService.stopCapture();
    _poller?.cancel();
    _poller = null;
    if (!mounted) return;
    setState(() {
      _started = false;
      _status = res;
      _lastFramePath = null;
    });
  }

  void _tap() {
    final x = int.tryParse(_tapX.text.trim()) ?? 0;
    final y = int.tryParse(_tapY.text.trim()) ?? 0;
    ScreenControlService.injectTap(x, y).then((s) {
      if (mounted) setState(() => _status = 'Tap: $s');
    });
  }

  void _swipe() {
    final fx = int.tryParse(_swipeFromX.text.trim()) ?? 0;
    final fy = int.tryParse(_swipeFromY.text.trim()) ?? 0;
    final tx = int.tryParse(_swipeToX.text.trim()) ?? 0;
    final ty = int.tryParse(_swipeToY.text.trim()) ?? 0;
    ScreenControlService.injectSwipe(fx, fy, tx, ty).then((s) {
      if (mounted) setState(() => _status = 'Swipe: $s');
    });
  }

  void _type() {
    final t = _textController.text.trim();
    if (t.isEmpty) return;
    ScreenControlService.injectType(t).then((s) {
      if (mounted) {
        setState(() {
          _status = 'Type: $s';
          _textController.clear();
        });
      }
    });
  }

  void _pressKey() {
    final c = int.tryParse(_keycodeController.text.trim()) ?? 4;
    ScreenControlService.injectKey(c).then((s) {
      if (mounted) setState(() => _status = 'Key: $s');
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
              title: const Text('Screen Control',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => context.pop(),
              ),
              actions: [
                _started
                    ? FilledButton.tonal(
                        onPressed: _stop,
                        child: const Text('Stop capture'),
                      )
                    : FilledButton(
                        onPressed: _start,
                        child: const Text('Start capture'),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lastFramePath != null && File(_lastFramePath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(glass.radiusSm),
                child: Image.file(
                  File(_lastFramePath!),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: glass.glassColor,
                  borderRadius: BorderRadius.circular(glass.radiusSm),
                  border: Border.all(color: glass.glassBorder),
                ),
                child: Column(
                  children: [
                    Icon(AppIcons.smartphone, size: 40, color: glass.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      _started
                          ? 'Waiting for first frame…'
                          : 'No capture in progress',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: glass.textSecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(_status,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: glass.textSecondary)),
            const SizedBox(height: 16),
            _section('Tap', [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: _tapX,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'X')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: _tapY,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Y')),
                  ),
                  IconButton(
                      onPressed: _tap, icon: const Icon(AppIcons.checkCircle2)),
                ],
              ),
            ]),
            _section('Swipe', [
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _swipeFromX,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'FX'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _swipeFromY,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'FY'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _swipeToX,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'TX'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _swipeToY,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'TY'))),
                ],
              ),
              Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(onPressed: _swipe, child: const Text('Swipe'))),
            ]),
            _section('Type text', [
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                              labelText: 'Text to type'))),
                  IconButton(
                      onPressed: _type, icon: const Icon(AppIcons.send)),
                ],
              ),
            ]),
            _section('Press key (keycode)', [
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _keycodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Keycode (4=back, 3=home)'))),
                  IconButton(
                      onPressed: _pressKey,
                      icon: const Icon(AppIcons.chevronDown)),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
