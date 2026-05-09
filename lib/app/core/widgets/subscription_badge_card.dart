import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/boutique_model.dart';
import '../../data/repositories/boutique_repository.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../services/user_controller.dart';

/// Card affichant le statut d'abonnement de la boutique courante : nombre
/// de jours restants + couleur selon proximité de l'expiration. Tap pour
/// naviguer vers la vue détaillée « Mon abonnement ».
///
/// Affiché sur le tableau de bord de l'admin de boutique. Caché pour le
/// super-admin (il a la vue globale via le menu Abonnements).
class SubscriptionBadgeCard extends StatelessWidget {
  const SubscriptionBadgeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = UserController.to.user;
    if (user == null) return const SizedBox.shrink();
    if (user.isSuperAdmin) return const SizedBox.shrink();
    final boutiqueId = user.boutiqueId;
    if (boutiqueId == null || boutiqueId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<BoutiqueModel>>(
      stream: BoutiqueRepository().watchScoped(scope: boutiqueId),
      builder: (context, snapshot) {
        final boutique = snapshot.data?.firstOrNull;
        if (boutique == null) return const SizedBox.shrink();
        final status = SubscriptionStatus.from(boutique.subscriptionEndsAt);
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Get.toNamed(AppRoutes.monAbonnement),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(status.icon, color: status.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Abonnement',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (status.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            status.subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.greyText(context, 600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Statut d'abonnement avec helpers d'affichage. Public pour réutilisation
/// dans les vues liste / détail / dashboard.
class SubscriptionStatus {
  final String label;
  final String? subtitle;
  final Color color;
  final IconData icon;

  /// `true` quand la date de fin est dépassée (au-delà de la grâce —
  /// la grâce est gérée séparément côté login).
  final bool isExpired;

  /// `true` quand la fin est dans 7 jours ou moins.
  final bool isCritical;

  /// `null` si pas d'abonnement.
  final int? daysRemaining;

  const SubscriptionStatus({
    required this.label,
    this.subtitle,
    required this.color,
    required this.icon,
    this.isExpired = false,
    this.isCritical = false,
    this.daysRemaining,
  });

  static SubscriptionStatus from(DateTime? endsAt) {
    if (endsAt == null) {
      return const SubscriptionStatus(
        label: 'Aucun abonnement',
        subtitle: 'Pas encore de paiement enregistré',
        color: AppColors.warning,
        icon: Icons.help_outline,
      );
    }
    final now = DateTime.now();
    final daysRemaining = endsAt.difference(now).inDays;
    if (daysRemaining < 0) {
      final daysSince = -daysRemaining;
      return SubscriptionStatus(
        label: 'Expiré depuis $daysSince j',
        subtitle: 'Fin : ${_fmtDate(endsAt)}',
        color: AppColors.danger,
        icon: Icons.error_outline,
        isExpired: true,
        daysRemaining: daysRemaining,
      );
    }
    if (daysRemaining <= 7) {
      return SubscriptionStatus(
        label: '$daysRemaining j restants',
        subtitle: 'Fin : ${_fmtDate(endsAt)}',
        color: AppColors.danger,
        icon: Icons.warning_amber_rounded,
        isCritical: true,
        daysRemaining: daysRemaining,
      );
    }
    if (daysRemaining <= 30) {
      return SubscriptionStatus(
        label: '$daysRemaining j restants',
        subtitle: 'Fin : ${_fmtDate(endsAt)}',
        color: AppColors.warning,
        icon: Icons.schedule_rounded,
        daysRemaining: daysRemaining,
      );
    }
    return SubscriptionStatus(
      label: '$daysRemaining j restants',
      subtitle: 'Fin : ${_fmtDate(endsAt)}',
      color: AppColors.success,
      icon: Icons.check_circle_outline,
      daysRemaining: daysRemaining,
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
