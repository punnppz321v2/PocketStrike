import 'package:flutter/services.dart';

/// Thin Dart facade over the native Android screen-control + root channel.
///
/// Exposes live MediaProjection frame paths and input injection primitives
/// (tap / swipe / type / key) plus root-aware shell execution on
/// a rooted device. On non-Android platforms every call degrades to a
/// clearly-worded "not available" string instead of throwing, so agent
/// tools can call into this uniformly.
class ScreenControlService {
  ScreenControlService._();

  static const _channel = MethodChannel('com.pocketstrike.app/screen');
  static const _rootChannel = MethodChannel('com.pocketstrike.app/root');

  /// Requests the user-grant for MediaProjection; triggers Android's
  /// "show screen content" consent flow.
  static Future<String> beginCapture() async {
    try {
      final res = await _channel.invokeMethod<String>('beginCapture');
      return res ?? 'REQUEST_SENT';
    } on MissingPluginException {
      return 'Screen control is only available on Android.';
    }
  }

  /// Stops the capture service.
  static Future<String> stopCapture() async {
    try {
      final res = await _channel.invokeMethod<String>('stopCapture');
      return res ?? 'STOPPED';
    } on MissingPluginException {
      return 'Screen control is only available on Android.';
    }
  }

  /// Returns the path of the most recent live frame JPEG, or null when the
  /// service is not producing frames.
  static Future<String?> getLiveFrame() async {
    try {
      return await _channel.invokeMethod<String>('getLiveFrame');
    } on MissingPluginException {
      return null;
    }
  }

  /// Injects a tap at (x, y) in screen coordinates.
  static Future<String> injectTap(int x, int y) async {
    try {
      final res = await _channel.invokeMethod<String>('injectClick', {
        'x': x,
        'y': y,
      });
      return res ?? 'CLICKED $x,$y';
    } on MissingPluginException {
      return 'Input injection is only available on Android.';
    }
  }

  /// Injects a swipe between two points.
  static Future<String> injectSwipe(int fromX, int fromY, int toX, int toY) async {
    try {
      final res = await _channel.invokeMethod<String>('injectSwipe', {
        'fromX': fromX,
        'fromY': fromY,
        'toX': toX,
        'toY': toY,
      });
      return res ?? 'SWIPED';
    } on MissingPluginException {
      return 'Input injection is only available on Android.';
    }
  }

  /// Injects a keyboard text string.
  static Future<String> injectType(String text) async {
    try {
      final res = await _channel.invokeMethod<String>('injectType', {
        'text': text,
      });
      return res ?? 'TYPED';
    } on MissingPluginException {
      return 'Input injection is only available on Android.';
    }
  }

  /// Injects a keyevent keycode (see KeyEvent docs for codes).
  static Future<String> injectKey(int keyCode) async {
    try {
      final res = await _channel.invokeMethod<String>('injectKey', {
        'keycode': keyCode,
      });
      return res ?? 'KEY_SENT';
    } on MissingPluginException {
      return 'Input injection is only available on Android.';
    }
  }

  /// Reports screen size in pixels.
  static Future<Map<String, int>> getScreenSize() async {
    try {
      final res = await _channel.invokeMethod<Map>('getScreenSize');
      return {
        'width': res?['width'] as int? ?? 0,
        'height': res?['height'] as int? ?? 0,
        'dpi': res?['dpi'] as int? ?? 0,
      };
    } on MissingPluginException {
      return {'width': 0, 'height': 0, 'dpi': 0};
    }
  }

  /// Probes whether the device has an `su` binary available.
  static Future<bool> isRooted() async {
    try {
      final res = await _rootChannel.invokeMethod<Map>('isRooted');
      return res?['hasSu'] as bool? ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Runs a shell command with elevated privileges.
  static Future<String> runAsRoot(String command) async {
    try {
      final res = await _rootChannel.invokeMethod<Map>('runAsRoot', {
        'command': command,
      });
      final out = res?['stdout'] as String? ?? '';
      final err = res?['stderr'] as String? ?? '';
      final code = res?['exitCode'] as int? ?? -1;
      final stderrBlock = err.isNotEmpty ? '\n[stderr]\n$err' : '';
      return 'exit=$code\n$out$stderrBlock';
    } on MissingPluginException {
      return 'Root execution is only available on Android.';
    }
  }
}
