import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_update_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_guard.dart';
import '../../../core/services/user_controller.dart';
import '../../../core/widgets/force_update_dialog.dart';
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

    // Check de mise à jour forcée AVANT toute navigation : on lit la
    // config Firestore (publique) et on compare avec la version installée.
    // Si l'app est trop ancienne, on affiche un dialog non-fermable et
    // on stoppe le splash ici — l'utilisateur ne peut continuer qu'après
    // avoir mis à jour depuis le store.
    final updateRequired = await AppUpdateService.check();
    if (updateRequired != null) {
      await _waitMinDuration(stopwatch);
      // Le dialog est lancé après le frame courant pour que GetX ait
      // bien un overlay de navigation prêt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ForceUpdateDialog.show(updateRequired);
      });
      return;
    }

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

    // Vérification de l'abonnement pour les sessions auto-rétablies au
    // démarrage : si la boutique est expirée au-delà de la grâce, on
    // déconnecte et on redirige vers le login avec un message.
    final user = UserController.to.user;
    SubscriptionWarning? warning;
    if (user != null) {
      final blockMsg = await SubscriptionGuard.checkAccess(user);
      if (blockMsg != null) {
        await UserController.to.signOut();
        Get.offAllNamed(AppRoutes.login);
        // Décale la snackbar après le push pour qu'elle s'affiche sur le
        // login (sinon elle disparaît avec le splash).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.snackbar(
            'Abonnement expiré',
            blockMsg,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 6),
            margin: const EdgeInsets.all(12),
          );
        });
        return;
      }
      warning = await SubscriptionGuard.getWarning(user);
    }

    // Super-admin OU admin de boutique → /admin
    // Vendeur → /vendeur
    final route = UserController.to.isAnyAdmin
        ? AppRoutes.adminHome
        : AppRoutes.vendeurHome;
    Get.offAllNamed(route);

    // Avertissement abonnement (≤ 7 jours ou période de grâce). Décalé
    // après la navigation pour s'afficher sur l'écran d'accueil.
    if (warning != null) {
      final isGrace = warning.isGracePeriod;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          warning!.title,
          warning.message,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 7),
          backgroundColor:
              isGrace ? Colors.red.shade50 : Colors.orange.shade50,
          colorText:
              isGrace ? Colors.red.shade900 : Colors.orange.shade900,
          margin: const EdgeInsets.all(12),
          icon: Icon(
            isGrace
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: isGrace ? Colors.red.shade900 : Colors.orange.shade900,
          ),
        );
      });
    }
  }

  Future<void> _waitMinDuration(Stopwatch sw) async {
    final remaining = _minSplashDuration - sw.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }
}
