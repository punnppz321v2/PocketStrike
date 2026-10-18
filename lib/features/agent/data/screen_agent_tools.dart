import '../domain/agent_tool.dart';
import 'screen_control_service.dart';

/// Live screen control + input injection + root-privileged shell tools.
///
/// These are gated by user consent in the native layer: [ScreenAgentTools]
/// first calls `begin_capture` (Android's MediaProjection consent flow)
/// before reading frames, and [RootAgentTools] are flagged destructive and
/// require the confirmation policy.
class ScreenAgentTools {
  const ScreenAgentTools._();

  static List<AgentTool> all() => [
        beginCapture(),
        stopCapture(),
        getLiveFrame(),
        screenTap(),
        screenSwipe(),
        typeText(),
        pressKey(),
        screenSize(),
      ];

  static AgentTool beginCapture() => AgentTool(
        name: 'begin_screen_capture',
        description:
            'Triggers the Android "show screen content" consent flow. Call this before any other screen tool.',
        inputSchema: const {'type': 'object', 'properties': <String, dynamic>{}, 'required': <String>[]},
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.beginCapture(),
      );

  static AgentTool stopCapture() => AgentTool(
        name: 'stop_screen_capture',
        description: 'Stops the live screen-capture pipeline.',
        inputSchema: const {'type': 'object', 'properties': <String, dynamic>{}, 'required': <String>[]},
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.stopCapture(),
      );

  static AgentTool getLiveFrame() => AgentTool(
        name: 'get_screen_frame',
        description: 'Returns the path of the latest captured screen frame (JPEG). Call begin_screen_capture first.',
        inputSchema: const {'type': 'object', 'properties': <String, dynamic>{}, 'required': <String>[]},
        risk: ToolRisk.external,
        run: (args) async {
          final path = await ScreenControlService.getLiveFrame();
          return path == null ? 'No frame available. Start screen capture first.' : 'Frame: $path';
        },
      );

  static AgentTool screenTap() => AgentTool(
        name: 'screen_tap',
        description: 'Taps the screen at integer pixel coordinates.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'x': {'type': 'integer', 'description': 'X coordinate in px'},
            'y': {'type': 'integer', 'description': 'Y coordinate in px'},
          },
          'required': ['x', 'y'],
        },
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.injectTap(
              args['x'] as int? ?? 0,
              args['y'] as int? ?? 0,
            ),
      );

  static AgentTool screenSwipe() => AgentTool(
        name: 'screen_swipe',
        description: 'Performs a swipe between two points.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'from_x': {'type': 'integer'},
            'from_y': {'type': 'integer'},
            'to_x': {'type': 'integer'},
            'to_y': {'type': 'integer'},
          },
          'required': ['from_x', 'from_y', 'to_x', 'to_y'],
        },
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.injectSwipe(
              args['from_x'] as int? ?? 0,
              args['from_y'] as int? ?? 0,
              args['to_x'] as int? ?? 0,
              args['to_y'] as int? ?? 0,
            ),
      );

  static AgentTool typeText() => AgentTool(
        name: 'type_text',
        description: 'Types text into the active input field via the Android `input text` command.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'text': {'type': 'string', 'description': 'Text to type'},
          },
          'required': ['text'],
        },
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.injectType(args['text'] as String? ?? ''),
      );

  static AgentTool pressKey() => AgentTool(
        name: 'press_key',
        description: 'Sends an Android keyevent keycode (e.g. 4 = back, 3 = home, 82 = enter, 187 = menu).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'keycode': {'type': 'integer', 'description': 'Android keycode'},
          },
          'required': ['keycode'],
        },
        risk: ToolRisk.external,
        run: (args) async => ScreenControlService.injectKey(args['keycode'] as int? ?? 0),
      );

  static AgentTool screenSize() => AgentTool(
        name: 'get_screen_size',
        description: 'Returns screen width, height and DPI in pixels.',
        inputSchema: const {'type': 'object', 'properties': <String, dynamic>{}, 'required': <String>[]},
        risk: ToolRisk.safe,
        run: (args) async {
          final s = await ScreenControlService.getScreenSize();
          return 'width=${s['width']} height=${s['height']} dpi=${s['dpi']}';
        },
      );
}

class RootAgentTools {
  const RootAgentTools._();

  static List<AgentTool> all() => [
        detectRoot(),
        runRootCommand(),
      ];

  static AgentTool detectRoot() => AgentTool(
        name: 'detect_root',
        description: 'Checks whether the device has a usable `su` binary (root access).',
        inputSchema: const {'type': 'object', 'properties': <String, dynamic>{}, 'required': <String>[]},
        risk: ToolRisk.safe,
        run: (args) async {
          final hasSu = await ScreenControlService.isRooted();
          return hasSu ? 'Root available (su found).' : 'Root not detected on this device.';
        },
      );

  static AgentTool runRootCommand() => AgentTool(
        name: 'run_root_command',
        description:
            'Runs a shell command with root privileges (su -c). Use only on devices that are known to be rooted and trusted.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': 'Shell command to run as root'},
          },
          'required': ['command'],
        },
        risk: ToolRisk.destructive,
        run: (args) async => ScreenControlService.runAsRoot(args['command'] as String? ?? ''),
      );
}
