import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../services/app_update_service.dart';

/// Dialog non-fermable qui force la mise à jour de l'app : pas de retour
/// arrière, pas de tap-outside, et un seul bouton « Mettre à jour » qui
/// ouvre le store correspondant. Affiché par le SplashController quand
/// [AppUpdateService.check] renvoie un résultat.
class ForceUpdateDialog extends StatelessWidget {
  final AppUpdateRequired info;
  const ForceUpdateDialog({super.key, required this.info});

  /// Ouvre le dialog en plein écran. Bloque jusqu'à ce que l'utilisateur
  /// tape « Mettre à jour » (qui ouvre le store) — il revient ensuite à
  /// l'app et peut retenter, mais le dialog se réaffiche tant que
  /// l'install n'est pas faite.
  static Future<void> show(AppUpdateRequired info) {
    return Get.dialog<void>(
      ForceUpdateDialog(info: info),
      barrierDismissible: false,
    );
  }

  Future<void> _openStore() async {
    final url = info.storeUrl;
    if (url.isEmpty) {
      Get.snackbar(
        'Mise à jour',
        'L\'URL du store n\'est pas configurée. Contactez le support.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    return PopScope(
      canPop: false, // bouton retour Android désactivé
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mise à jour requise',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                info.message?.trim().isNotEmpty == true
                    ? info.message!.trim()
                    : 'Une nouvelle version de l\'application est disponible. '
                        'Veuillez mettre à jour pour continuer à utiliser '
                        'Gongore App.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.greyText(context, 700),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.greyText(context, 500)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Version installée : ${info.installedVersion} · '
                  'Version requise : ${info.minVersion}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.greyText(context, 800),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openStore,
                  icon: const Icon(Icons.system_update_rounded),
                  label: const Text('Mettre à jour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
