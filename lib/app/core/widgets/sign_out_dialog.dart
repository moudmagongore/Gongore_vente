import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../services/user_controller.dart';

/// Demande confirmation puis déconnecte l'utilisateur.
/// Appelé depuis le bouton « Déconnexion » des drawers.
Future<void> confirmSignOut(BuildContext context) async {
  // Ferme d'abord le drawer si ouvert
  Navigator.of(context).maybePop();

  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('Déconnexion'),
      content: const Text(
        'Êtes-vous sûr de vouloir vous déconnecter ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Annuler'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Get.back(result: true),
          child: const Text('Déconnexion'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  await UserController.to.signOut();
  Get.offAllNamed(AppRoutes.login);
}
