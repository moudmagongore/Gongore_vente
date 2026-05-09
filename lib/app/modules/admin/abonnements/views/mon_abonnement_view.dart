import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/subscription_badge_card.dart';
import '../../../../data/models/abonnement_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/mon_abonnement_controller.dart';

class MonAbonnementView extends GetView<MonAbonnementController> {
  const MonAbonnementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final boutique = controller.boutique;
          if (boutique == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune boutique associée à votre compte.',
                  style: TextStyle(color: AppColors.greyText(context, 700)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final status =
              SubscriptionStatus.from(boutique.subscriptionEndsAt);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _StatusCard(status: status, boutiqueNom: boutique.nom),
              const SizedBox(height: 20),
              const _SectionTitle('Historique des paiements'),
              const SizedBox(height: 8),
              if (controller.historique.isEmpty)
                _EmptyHistorique()
              else
                ...controller.historique
                    .map((a) => _AbonnementTile(abonnement: a)),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SubscriptionStatus status;
  final String boutiqueNom;
  const _StatusCard({required this.status, required this.boutiqueNom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            status.color.withValues(alpha: 0.18),
            status.color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  boutiqueNom,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          if (status.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              status.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText(context, 700),
              ),
            ),
          ],
          if (status.isExpired) ...[
            const SizedBox(height: 12),
            Text(
              'Pour réactiver l\'accès, contactez le support pour enregistrer un nouveau paiement.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText(context, 700),
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (status.isCritical) ...[
            const SizedBox(height: 12),
            Text(
              'Pensez à renouveler votre abonnement avant la fin de période.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText(context, 700),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.greyText(context, 700),
      ),
    );
  }
}

class _AbonnementTile extends StatelessWidget {
  final AbonnementModel abonnement;
  const _AbonnementTile({required this.abonnement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.payments_rounded,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        abonnement.periode.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fmt.money(abonnement.montant,
                            currency: abonnement.devise),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Du ${_fmtDate(abonnement.dateDebut)} au ${_fmtDate(abonnement.dateFin)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.greyText(context, 700),
                    ),
                  ),
                  if (abonnement.note != null && abonnement.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        abonnement.note!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText(context, 600),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyHistorique extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: AppColors.greyText(context, 500), size: 36),
          const SizedBox(height: 8),
          Text(
            'Aucun paiement enregistré pour le moment.',
            style: TextStyle(color: AppColors.greyText(context, 600)),
          ),
        ],
      ),
    );
  }
}
