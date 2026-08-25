import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ===== Constantes de design =====
  static const double _radius = 14;
  static const double _radiusSmall = 10;
  static const String fontFamily = 'NunitoSans';

  // Bleu navy en mode clair, teal en mode sombre — synchronisés avec le
  // getter [AppColors.primary] qui s'adapte au thème courant.
  static const Color _primaryLightMode = Color(0xFF194565);
  static const Color _primaryDarkMode = Color(0xFF34A0A7);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scaffoldBg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        text: AppColors.lightText,
        textMuted: AppColors.lightTextMuted,
        border: AppColors.border,
        primary: _primaryLightMode,
        overlay: SystemUiOverlayStyle.dark,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scaffoldBg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        text: AppColors.darkText,
        textMuted: AppColors.darkTextMuted,
        border: AppColors.borderDark,
        primary: _primaryDarkMode,
        overlay: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surface,
    required Color text,
    required Color textMuted,
    required Color border,
    required Color primary,
    required SystemUiOverlayStyle overlay,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: AppColors.secondary,
      surface: surface,
      error: AppColors.danger,
    );

    // Tous les TextStyle référencent explicitement [fontFamily] : ThemeData
    // n'hérite pas la fontFamily aux sous-thèmes (appBar, dialog, listTile…)
    // donc on l'inscrit partout pour garantir NunitoSans sur toute l'UI.
    final textTheme = TextTheme(
      // Display / headline
      displaySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 28, fontWeight: FontWeight.w700, color: text, height: 1.2),
      headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24, fontWeight: FontWeight.w700, color: text, height: 1.2),
      headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20, fontWeight: FontWeight.w700, color: text, height: 1.25),
      headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18, fontWeight: FontWeight.w700, color: text, height: 1.3),
      // Titles
      titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16, fontWeight: FontWeight.w600, color: text, height: 1.35),
      titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14, fontWeight: FontWeight.w600, color: text, height: 1.4),
      titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13, fontWeight: FontWeight.w600, color: text, height: 1.4),
      // Body
      bodyLarge: TextStyle(
          fontFamily: fontFamily, fontSize: 15, color: text, height: 1.45),
      bodyMedium: TextStyle(
          fontFamily: fontFamily, fontSize: 13.5, color: text, height: 1.45),
      bodySmall: TextStyle(
          fontFamily: fontFamily, fontSize: 12, color: textMuted, height: 1.4),
      // Labels
      labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14, fontWeight: FontWeight.w600, color: text),
      labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
      labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: fontFamily,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: text, size: 22),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 22),

      // ===== App bar =====
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: surface,
        centerTitle: true,
        systemOverlayStyle: overlay,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: text, size: 22),
      ),

      // ===== Cards : pas d'élévation, bordure subtile =====
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      // ===== Inputs : remplis, sans bordure, focus en couleur =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFF1F3F7)
            : Colors.white.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(
            fontFamily: fontFamily, color: textMuted, fontSize: 13.5),
        labelStyle: TextStyle(
            fontFamily: fontFamily, color: textMuted, fontSize: 13.5),
        floatingLabelStyle: TextStyle(
            fontFamily: fontFamily,
            color: primary,
            fontWeight: FontWeight.w600),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // ===== Boutons =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              brightness == Brightness.light ? Colors.grey.shade300 : Colors.grey.shade800,
          disabledForegroundColor: textMuted,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shadowColor: primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall + 2),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall + 2),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall + 2),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          highlightColor: primary.withValues(alpha: 0.08),
        ),
      ),

      // ===== Floating Action Button =====
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      // ===== List tile =====
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: textMuted,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        subtitleTextStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 12, color: textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
        ),
      ),

      // ===== Chips =====
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFEFF1F5)
            : Colors.white.withValues(alpha: 0.05),
        selectedColor: primary.withValues(alpha: 0.15),
        secondarySelectedColor: primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        showCheckmark: false,
      ),

      // ===== Dividers =====
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ===== Dialogs =====
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius + 4),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          color: text,
          height: 1.5,
        ),
      ),

      // ===== Snackbars =====
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
        ),
        insetPadding: const EdgeInsets.all(12),
      ),

      // ===== Popup menus =====
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall + 2),
          side: BorderSide(color: border, width: 1),
        ),
        textStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 13.5, color: text),
      ),

      // ===== Bottom sheets =====
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),

      // ===== Bottom navigation =====
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ===== Tabs =====
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primary, width: 2.5),
        ),
      ),

      // ===== Switch / checkbox =====
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.4);
          }
          return Colors.grey.shade300;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        side: BorderSide(color: textMuted, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textMuted;
        }),
      ),

      // ===== Progress =====
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: const Color(0xFFE7EAEF),
        circularTrackColor: const Color(0xFFE7EAEF),
      ),

      // ===== Scrollbar discrète =====
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(4),
        thumbColor: WidgetStateProperty.all(textMuted.withValues(alpha: 0.4)),
      ),

      // ===== Tooltip =====
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: text.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
            fontFamily: fontFamily, color: Colors.white, fontSize: 11),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ===== Drawer =====
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }
}
