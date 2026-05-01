import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ===== Constantes de design =====
  static const double _radius = 14;
  static const double _radiusSmall = 10;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scaffoldBg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        text: AppColors.lightText,
        textMuted: AppColors.lightTextMuted,
        border: AppColors.border,
        overlay: SystemUiOverlayStyle.dark,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scaffoldBg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        text: AppColors.darkText,
        textMuted: AppColors.darkTextMuted,
        border: AppColors.borderDark,
        overlay: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surface,
    required Color text,
    required Color textMuted,
    required Color border,
    required SystemUiOverlayStyle overlay,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: surface,
      error: AppColors.danger,
    );

    final textTheme = TextTheme(
      // Display / headline
      displaySmall: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: text, height: 1.2),
      headlineLarge: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: text, height: 1.2),
      headlineMedium: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: text, height: 1.25),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: text, height: 1.3),
      // Titles
      titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: text, height: 1.35),
      titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: text, height: 1.4),
      titleSmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: text, height: 1.4),
      // Body
      bodyLarge: TextStyle(fontSize: 15, color: text, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13.5, color: text, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
      // Labels
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: text),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'Roboto',
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
        hintStyle: TextStyle(color: textMuted, fontSize: 13.5),
        labelStyle: TextStyle(color: textMuted, fontSize: 13.5),
        floatingLabelStyle:
            const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              brightness == Brightness.light ? Colors.grey.shade300 : Colors.grey.shade800,
          disabledForegroundColor: textMuted,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall + 2),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSmall + 2),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
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
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
        ),
      ),

      // ===== Floating Action Button =====
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        extendedTextStyle: TextStyle(
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        subtitleTextStyle: TextStyle(fontSize: 12, color: textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
        ),
      ),

      // ===== Chips =====
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFEFF1F5)
            : Colors.white.withValues(alpha: 0.05),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        secondarySelectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
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
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13.5,
          color: text,
          height: 1.5,
        ),
      ),

      // ===== Snackbars =====
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: const TextStyle(
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
        textStyle: TextStyle(fontSize: 13.5, color: text),
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
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ===== Tabs =====
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),

      // ===== Switch / checkbox =====
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.4);
          }
          return Colors.grey.shade300;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        side: BorderSide(color: textMuted, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return textMuted;
        }),
      ),

      // ===== Progress =====
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0xFFE7EAEF),
        circularTrackColor: Color(0xFFE7EAEF),
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
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
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
