import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/appro_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/appro_detail_controller.dart';

class ApproDetailView extends GetView<ApproDetailController> {
  const ApproDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'appro'),
        actions: [
          Obx(() {
            final a = controller.appro.value;
            if (a == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Imprimer / Partager le bon',
              icon: const Icon(Icons.print_outlined),
              onPressed: () async {
                final boutique = controller.boutique.value;
                final fournisseur = controller.fournisseur.value;
                if (boutique == null || fournisseur == null) return;
                try {
                  await ApproReceiptService.sharePrint(
                    appro: a,
                    boutique: boutique,
                    fournisseur: fournisseur,
                    user: controller.user.value,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Erreur',
                    'Impression impossible : $e',
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },
            );
          }),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          final a = controller.appro.value;
          if (controller.isLoading.value || a == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Body(appro: a, c: controller);
        }),
      ),
      bottomNavigationBar: Obx(() {
        final a = controller.appro.value;
        if (a == null) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Get.offAllNamed(
                    UserController.to.isAnyAdmin
                        ? AppRoutes.adminHome
                        : AppRoutes.vendeurHome,
                  ),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Retour à l\'accueil'),
                ),
                if (controller.peutAnnuler) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: controller.isCanceling.value
                        ? null
                        : controller.confirmCancel,
                    icon: controller.isCanceling.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler l\'appro'),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final ApprovisionnementModel appro;
  final ApproDetailController c;
  const _Body({required this.appro, required this.c});

  @override
  Widget build(BuildContext context) {
    final annulee = appro.statut == ApproStatut.annulee;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statut
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: annulee
                ? Colors.red.withValues(alpha: 0.10)
                : AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                annulee ? Icons.cancel_outlined : Icons.check_circle_rounded,
                color: annulee ? Colors.red : AppColors.success,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appro.statut.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: annulee ? Colors.red : AppColors.success,
                      ),
                    ),
                    Text(
                      Fmt.dateTime(appro.date),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                    if (appro.motifAnnulation?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Motif : ${appro.motifAnnulation}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Infos
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoLine(
                  icon: Icons.tag_rounded,
                  label: 'N° bon',
                  value: appro.numeroAffichage,
                ),
                Obx(() => _InfoLine(
                      icon: Icons.store_outlined,
                      label: 'Boutique',
                      value: c.boutique.value?.nom ?? '…',
                    )),
                Obx(() => _InfoLine(
                      icon: Icons.local_shipping_rounded,
                      label: 'Fournisseur',
                      value: c.fournisseurLabel,
                    )),
                Obx(() => _InfoLine(
                      icon: Icons.badge_outlined,
                      label: 'Réceptionné par',
                      value: c.user.value?.nom ?? '—',
                    )),
                _InfoLine(
                  icon: Icons.payments_outlined,
                  label: 'Mode de paiement',
                  value: appro.modePaiement.label,
                ),
                _InfoLine(
                  icon: Icons.shopping_basket_outlined,
                  label: 'Articles',
                  value: '${appro.nbArticles} unité(s)',
                  isLast: !(appro.note?.isNotEmpty ?? false),
                ),
                if (appro.note?.isNotEmpty ?? false)
                  _InfoLine(
                    icon: Icons.notes_rounded,
                    label: 'Note',
                    value: appro.note!,
                    isLast: true,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Articles
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Articles reçus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextMuted,
            ),
          ),
        ),
        Card(
          child: Column(
            children: appro.articles
                .asMap()
                .entries
                .map((e) => _ArticleLine(
                      article: e.value,
                      isLast: e.key == appro.articles.length - 1,
                      devise: c.devise,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Totaux
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _TotalLine(
                  label: 'Sous-total',
                  value: Fmt.money(appro.sousTotal, currency: c.devise),
                ),
                if (appro.remise > 0)
                  _TotalLine(
                    label: 'Remise',
                    value:
                        '-${Fmt.money(appro.remise, currency: c.devise)}',
                    color: AppColors.success,
                  ),
                const Divider(),
                _TotalLine(
                  label: 'TOTAL',
                  value: Fmt.money(appro.total, currency: c.devise),
                  big: true,
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                _TotalLine(
                  label: 'Payé (cash)',
                  value:
                      Fmt.money(appro.montantPaye, currency: c.devise),
                ),
                if (appro.avanceUtilisee > 0)
                  _TotalLine(
                    label: 'Avance utilisée',
                    value: Fmt.money(appro.avanceUtilisee,
                        currency: c.devise),
                    color: AppColors.success,
                  ),
                if (appro.resteAPayer > 0)
                  _TotalLine(
                    label: 'Reste à payer',
                    value:
                        '${Fmt.money(appro.resteAPayer, currency: c.devise)} (dette)',
                    color: AppColors.warning,
                  )
                else if (appro.resteAPayer < 0)
                  _TotalLine(
                    label: 'Trop-versé',
                    value: Fmt.money(appro.resteAPayer.abs(),
                        currency: c.devise),
                    color: AppColors.success,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

class _ArticleLine extends StatelessWidget {
  final ApproArticle article;
  final bool isLast;
  final String devise;

  const _ArticleLine({
    required this.article,
    required this.isLast,
    required this.devise,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${article.quantite}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.nomComplet,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${Fmt.money(article.prixAchatUnitaire, currency: devise)} x ${article.quantite}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Fmt.money(article.sousTotal, currency: devise),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? color;

  const _TotalLine({
    required this.label,
    required this.value,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: big ? 16 : 13,
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 22 : 14,
              fontWeight: big ? FontWeight.w800 : FontWeight.w600,
              color: color ?? (big ? AppColors.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
