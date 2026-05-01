import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/user_controller.dart';
import 'app_routes.dart';

/// Bloque l'accès aux routes admin pour les non-admins.
/// Un vendeur connecté est redirigé vers son accueil ; un visiteur
/// non authentifié vers le login.
class AdminGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final uc = UserController.to;
    if (!uc.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    if (uc.isAnyAdmin) return null;
    return const RouteSettings(name: AppRoutes.vendeurHome);
  }
}

/// Bloque l'accès aux routes vendeur pour les non-connectés.
/// Un admin reste autorisé (utile pour la caisse partagée).
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final uc = UserController.to;
    if (!uc.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
