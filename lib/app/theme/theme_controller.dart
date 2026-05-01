import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  static const _storageKey = 'theme_mode';
  final _box = GetStorage();

  ThemeMode get currentMode {
    final saved = _box.read<String>(_storageKey);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  bool get isDark => Get.isDarkMode;

  void setMode(ThemeMode mode) {
    Get.changeThemeMode(mode);
    _box.write(_storageKey, mode.name);
  }

  void toggle() {
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}