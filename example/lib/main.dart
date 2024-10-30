import 'dart:developer';

import 'package:desktop_screenstate/desktop_screenstate.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final String _platformVersion = 'Unknown';
  final _screenstatePlugin = DesktopScreenState.instance;

  @override
  void initState() {
    DesktopScreenState.instance.isActive.addListener(() {
      log(DesktopScreenState.instance.isActive.value.toString());
    });
    DesktopScreenState.instance.isMouseActive.addListener(() {
      log(DesktopScreenState.instance.isMouseActive.value.toString());
    });
    DesktopScreenState.instance.isKeyboardActive.addListener(() {
      log(DesktopScreenState.instance.isKeyboardActive.value.toString());
    });
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            ValueListenableBuilder<ScreenState>(
              valueListenable: _screenstatePlugin.isActive,
              builder: (context, value, child) => Center(
                child: Text('Screen state on: $value'),
              ),
            ),
            ValueListenableBuilder<KeyboardState>(
              valueListenable: _screenstatePlugin.isKeyboardActive,
              builder: (context, value, child) => Center(
                child: Text('Keyboard state on: $value'),
              ),
            ),
            ValueListenableBuilder<MouseState>(
              valueListenable: _screenstatePlugin.isMouseActive,
              builder: (context, value, child) => Center(
                child: Text('Mouse state on: $value'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
