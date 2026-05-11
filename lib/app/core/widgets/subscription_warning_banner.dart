import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/abonnement_params_model.dart';
import '../../data/models/boutique_model.dart';
import '../../data/repositories/abonnement_params_repository.dart';
import '../../data/repositories/boutique_repository.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../services/user_controller.dart';

/// Bandeau d'avertissement affiché en haut du tableau de bord d'un admin
/// ou d'un gestionnaire quand son abonnement entre en zone critique :
/// - ≤ seuil configuré → fond orange + nb de jours avant fin
/// - en période de grâce post-expiration → fond rouge + nb de jours de
///   grâce restants avant blocage
///
/// Caché pour le super-admin et les comptes sans boutique. Tap → navigue
/// vers « Mon abonnement », **mais uniquement pour l'admin de boutique**.
/// Le vendeur (gestionnaire pur) voit le bandeau en lecture seule, sans
/// chevron, car il n'a pas accès à l'historique des paiements.
class SubscriptionWarningBanner extends StatelessWidget {
  const SubscriptionWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Obx pour réagir au switch de boutique active d'un admin multi-boutique.
    return Obx(() {
      final user = UserController.to.user;
      if (user == null || user.isSuperAdmin) return const SizedBox.shrink();
      // Boutique ACTIVE (et non principale) — important pour un admin
      // multi-boutique qui a switché vers une boutique additionnelle.
      final bid = UserController.to.scopeBoutiqueId;
      if (bid == null || bid.isEmpty) return const SizedBox.shrink();
      final canOpenDetails = user.isAdmin;

      return StreamBuilder<List<BoutiqueModel>>(
        stream: BoutiqueRepository().watchScoped(scope: bid),
        builder: (context, snap) {
          final boutique = snap.data?.firstOrNull;
          if (boutique == null) return const SizedBox.shrink();
          return StreamBuilder<AbonnementParamsModel>(
            stream: AbonnementParamsRepository().watch(),
            builder: (context, paramsSnap) {
              final params =
                  paramsSnap.data ?? const AbonnementParamsModel();
              final info = _WarningInfo.compute(
                endsAt: boutique.subscriptionEndsAt,
                graceDays: params.graceDays,
                warningThresholdDays: params.warningThresholdDays,
              );
              if (info == null) return const SizedBox.shrink();
              return _BannerCard(info: info, tappable: canOpenDetails);
            },
          );
        },
      );
    });
  }
}

class _BannerCard extends StatelessWidget {
  final _WarningInfo info;
  final bool tappable;
  const _BannerCard({required this.info, required this.tappable});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: info.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: info.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText(context, 800),
                  ),
                ),
              ],
            ),
          ),
          // Chevron affiché uniquement quand le bandeau est cliquable
          // (admin de boutique). Le gestionnaire le voit en lecture seule.
          if (tappable) Icon(Icons.chevron_right_rounded, color: info.color),
        ],
      ),
    );

    if (!tappable) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.toNamed(AppRoutes.monAbonnement),
        child: body,
      ),
    );
  }
}

class _WarningInfo {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _WarningInfo({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  static _WarningInfo? compute({
    required DateTime? endsAt,
    required int graceDays,
    required int warningThresholdDays,
  }) {
    if (endsAt == null) return null; // pas d'abo : géré par checkAccess
    final now = DateTime.now();

    if (endsAt.isAfter(now)) {
      // Encore actif : alerte si ≤ seuil configuré.
      final daysRemaining = endsAt.difference(now).inDays;
      if (daysRemaining > warningThresholdDays) return null;
      final j = daysRemaining <= 0
          ? 'moins d\'un jour'
          : (daysRemaining == 1 ? '1 jour' : '$daysRemaining jours');
      return _WarningInfo(
        title: 'Abonnement bientôt expiré',
        message: 'Il reste $j avant la fin de votre abonnement.',
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }

    // Déjà expiré : période de grâce ?
    final deadline = endsAt.add(Duration(days: graceDays));
    if (now.isBefore(deadline) || now.isAtSameMomentAs(deadline)) {
      final graceLeft = deadline.difference(now).inDays;
      final j = graceLeft <= 0
          ? 'moins d\'un jour'
          : (graceLeft == 1 ? '1 jour' : '$graceLeft jours');
      return _WarningInfo(
        title: 'Période de grâce',
        message:
            'Abonnement expiré. Il reste $j avant le blocage de la boutique.',
        color: AppColors.danger,
        icon: Icons.error_outline_rounded,
      );
    }
    return null;
  }
}
