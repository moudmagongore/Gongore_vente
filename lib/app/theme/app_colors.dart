import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Couleurs primaires : navy en mode clair, teal en mode sombre.
  //
  // [primary] requiert un BuildContext pour résoudre la couleur via
  // Theme.of(context). Cet appel enregistre le widget appelant comme
  // dépendant du Theme InheritedWidget : tout changement de thème déclenche
  // alors un rebuild immédiat — y compris pour les widgets `const`
  // imbriqués sous un Obx qui n'observe pas le thème.
  static const Color _primaryLight = Color(0XFF194565);
  static const Color _primaryDarkMode = Color(0XFF34a0a7);

  static Color primary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _primaryDarkMode
          : _primaryLight;

  // Variante navy fixe (non-adaptative) pour les rares cas où une vraie
  // constante est requise (ex: ColorScheme.fromSeed à la création du thème).
  static const Color primaryFixed = _primaryLight;

  static const Color primaryDark = Color(0XFF34a0a7);
  static const Color secondary = Color(0xFF00ACC1);
  static const Color accent = Color(0xFFFFB300);

  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color danger = Color(0xFFE53935);
  static const Color info = Color(0XFF194565);

  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF1F2937);
  static const Color lightTextMuted = Color(0xFF6B7280);

  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkText = Colors.white;
  static const Color darkTextMuted = Colors.white;

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF334155);

  /// Texte/icône gris adaptatif : blanc en mode sombre, nuance fournie en
  /// mode clair. [context] est requis pour s'enregistrer auprès du Theme
  /// InheritedWidget et garantir un rebuild immédiat au changement de mode.
  static Color greyText(BuildContext context, int shade) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : (Colors.grey[shade] ?? Colors.grey.shade600);

  /// Couleur de bordure adaptative pour les cards/containers : slate sombre
  /// (peu visible) en mode sombre, gris clair en mode clair. Identique à la
  /// bordure du `cardTheme` afin que toutes les bordures de l'app aient
  /// le même rendu.
  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : border;
}
