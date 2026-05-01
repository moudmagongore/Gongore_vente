import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_controller.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  static const _minSplashDuration = Duration(milliseconds: 1200);

  @override
  void onReady() {
    super.onReady();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    if (!AuthService.to.isLoggedIn) {
      await _waitMinDuration(stopwatch);
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    final ok = await UserController.to.refreshFromAuth();
    await _waitMinDuration(stopwatch);

    if (!ok) {
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    // Super-admin OU admin de boutique → /admin
    // Vendeur → /vendeur
    final route = UserController.to.isAnyAdmin
        ? AppRoutes.adminHome
        : AppRoutes.vendeurHome;
    Get.offAllNamed(route);
  }

  Future<void> _waitMinDuration(Stopwatch sw) async {
    final remaining = _minSplashDuration - sw.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }
}
