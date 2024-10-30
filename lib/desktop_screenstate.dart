import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

enum ScreenState { sleep, awaked, locked, unlocked }

enum MouseState { active, inActive }

enum KeyboardState { active, inActive }

class DesktopScreenState {
  static const MethodChannel _channel = MethodChannel('screenstate');
  static bool _isMonitoring = false;
  static Pointer<NativeFunction<HOOKPROC>> _keyboardHook = nullptr;
  static Pointer<NativeFunction<HOOKPROC>> _mouseHook = nullptr;

  static DesktopScreenState? _instance;

  static DesktopScreenState get instance {
    if (_instance == null) {
      _instance = DesktopScreenState._();
      if (Platform.isWindows || Platform.isMacOS) {
        _channel.setMethodCallHandler(_instance!._handleMethodCall);
      } else if (Platform.isLinux) {
        linuxCode();
      }
    }
    return _instance!;
  }

  static void linuxCode() {
    Process.start('dbus-monitor', [
      '--session',
      "type='signal',interface='org.gnome.ScreenSaver'"
    ]).then((Process process) {
      // Capture stdout and stderr streams
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        // Filter lines containing "boolean true" or "boolean false"
        if (line.contains(RegExp(r"boolean true|boolean false"))) {
          if (line.trim() == "boolean true") {
            _activeState.value = ScreenState.locked;
          } else {
            _activeState.value = ScreenState.unlocked;
          }
          // Handle the output as needed
        }
      });

      // Listen for process exit
      process.exitCode.then((int code) {
        debugPrint('Process exited with code $code');
        // Handle process exit, if needed
      });
    }).catchError((error) {
      debugPrint('Error starting process: $error');
      // Handle any errors that occur during process startup
    });
  }

  static void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    _keyboardHook = SetWindowsHookEx(
      WINDOWS_HOOK_ID.WH_KEYBOARD_LL,
      Pointer.fromFunction<HOOKPROC>(_keyboardProc, 0),
      GetModuleHandle(nullptr),
      0,
    ) as Pointer<NativeFunction<HOOKPROC>>;

    _mouseHook = SetWindowsHookEx(
      WINDOWS_HOOK_ID.WH_MOUSE_LL,
      Pointer.fromFunction<HOOKPROC>(_mouseProc, 0),
      GetModuleHandle(nullptr),
      0,
    ) as Pointer<NativeFunction<HOOKPROC>>;
  }

  static void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;

    UnhookWindowsHookEx(_keyboardHook as int);
    UnhookWindowsHookEx(_mouseHook as int);
  }

  static int _keyboardProc(int nCode, int wParam, int lParam) {
    if (nCode >= 0 && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)) {}
    return CallNextHookEx(_keyboardHook as int, nCode, wParam, lParam);
  }

  static int _mouseProc(int nCode, int wParam, int lParam) {
    if (nCode >= 0 && (wParam == WM_MOUSEMOVE || wParam == WM_LBUTTONDOWN)) {}
    return CallNextHookEx(_mouseHook as int, nCode, wParam, lParam);
  }

  DesktopScreenState._();

  static final ValueNotifier<ScreenState> _activeState =
      ValueNotifier(ScreenState.awaked);

  ValueListenable<ScreenState> get isActive {
    return _activeState;
  }

  static final ValueNotifier<MouseState> _mouseState =
      ValueNotifier(MouseState.active);

  ValueListenable<MouseState> get isMouseActive {
    return _mouseState;
  }

  static final ValueNotifier<KeyboardState> _keyBoardState =
      ValueNotifier(KeyboardState.active);

  ValueListenable<KeyboardState> get isKeyboardActive {
    return _keyBoardState;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onScreenStateChange":
        _onApplicationFocusChange(call.arguments as String);
        break;
      case "mouseState":
        _onMouseState(call.arguments as String);
        break;
      case "keyboardState":
        _onkeyboardState(call.arguments as String);
        break;
      default:
        break;
    }
  }

  void _onApplicationFocusChange(String active) {
    _activeState.value = ScreenState.values.firstWhere(
      (e) => e.toString().split('.').last == active,
      orElse: () => ScreenState.awaked,
    );
  }

  void _onMouseState(String active) {
    _mouseState.value =
        active == "active" ? MouseState.active : MouseState.inActive;
  }

  void _onkeyboardState(String active) {
    _keyBoardState.value =
        active == "active" ? KeyboardState.active : KeyboardState.inActive;
  }
}
