import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/core/constants/app_constants.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/services/biometric_service.dart';
import 'app/core/services/firestore_service.dart';
import 'app/core/services/user_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();
  await initializeDateFormatting('fr_FR');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  Get.put(ThemeController(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(BiometricService(), permanent: true);
  Get.put(FirestoreService(), permanent: true);
  Get.put(UserController(), permanent: true);

  runApp(const GongoreApp());
}

class GongoreApp extends StatelessWidget {
  const GongoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    // Obx() observe themeController.mode : à chaque toggle, GetMaterialApp
    // est reconstruit avec la nouvelle valeur de themeMode, ce qui force
    // tout l'arbre de widgets à se rebuilder et donc à re-évaluer les
    // couleurs adaptatives (AppColors.primary(context), AppColors.greyText…).
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.mode.value,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        defaultTransition: Transition.cupertino,
        // Force NunitoSans à hériter sur tous les `Text` avec un TextStyle
        // custom qui ne précise pas la fontFamily (boutons, sous-titres,
        // headers de drawer custom, etc.). Sans ce wrap, les TextStyle
        // construits inline cassent l'héritage du theme.
        builder: (context, child) => DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: AppTheme.fontFamily),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
