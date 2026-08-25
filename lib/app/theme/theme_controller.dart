import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  static const _storageKey = 'theme_mode';
  final _box = GetStorage();

  // Mode observable pour que GetMaterialApp se reconstruise à chaque
  // changement (et propage la nouvelle brightness à tout l'arbre, y
  // compris les widgets qui utilisent les getters adaptatifs comme
  // AppColors.primary(context) / AppColors.greyText).
  late final Rx<ThemeMode> mode = _loadInitialMode().obs;
  final currentRoute = '/'.obs;

  ThemeMode _loadInitialMode() {
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

  ThemeMode get currentMode => mode.value;

  bool get isDark => Get.isDarkMode;

  void setMode(ThemeMode newMode) {
    mode.value = newMode;
    Get.changeThemeMode(newMode);
    _box.write(_storageKey, newMode.name);
  }

  void toggle() {
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}