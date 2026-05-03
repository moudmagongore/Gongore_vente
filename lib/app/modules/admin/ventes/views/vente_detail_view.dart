import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/receipt_service.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/vente_detail_controller.dart';

class VenteDetailView extends GetView<VenteDetailController> {
  const VenteDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la vente'),
        actions: [
          Obx(() {
            final v = controller.vente.value;
            if (v == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Imprimer / Partager le reçu',
              icon: const Icon(Icons.print_outlined),
              onPressed: () async {
                final boutique = controller.boutique.value;
                if (boutique == null) return;
                try {
                  await ReceiptService.sharePrint(
                    vente: v,
                    boutique: boutique,
                    vendeur: controller.vendeur.value,
                    clientLabel: controller.clientLabel,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Erreur',
                    'Impression impossible : $e',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
            );
          }),
        ],
      ),
      body: Obx(() {
        final v = controller.vente.value;
        if (controller.isLoading.value || v == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _DetailBody(vente: v, controller: controller);
      }),
      bottomNavigationBar: Obx(() {
        if (!controller.peutAnnuler) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
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
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Annuler la vente'),
            ),
          ),
        );
      }),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final VenteModel vente;
  final VenteDetailController controller;
  const _DetailBody({required this.vente, required this.controller});

  @override
  Widget build(BuildContext context) {
    final annulee = vente.statut == VenteStatut.annulee;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ====== Statut ======
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: annulee
                ? Colors.red.withValues(alpha: 0.1)
                : AppColors.success.withValues(alpha: 0.1),
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
                      vente.statut.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: annulee ? Colors.red : AppColors.success,
                      ),
                    ),
                    Text(
                      Fmt.dateTime(vente.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (vente.motifAnnulation?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Motif : ${vente.motifAnnulation}',
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

        // ====== Infos ======
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Obx(() => _InfoLine(
                      icon: Icons.store_outlined,
                      label: 'Boutique',
                      value: controller.boutique.value?.nom ?? '…',
                    )),
                Obx(() => _InfoLine(
                      icon: controller.client.value != null
                          ? Icons.person_pin_rounded
                          : Icons.person_outline_rounded,
                      label: 'Client',
                      value: controller.clientLabel,
                    )),
                Obx(() => _InfoLine(
                      icon: Icons.badge_outlined,
                      label: 'Vendeur',
                      value: controller.vendeur.value?.nom ?? '…',
                    )),
                _InfoLine(
                  icon: Icons.payments_outlined,
                  label: 'Mode de paiement',
                  value: vente.modePaiement.label,
                ),
                _InfoLine(
                  icon: Icons.shopping_basket_outlined,
                  label: 'Articles',
                  value: '${vente.nbArticles} unité(s)',
                  isLast: !(vente.note?.isNotEmpty ?? false),
                ),
                if (vente.note?.isNotEmpty ?? false)
                  _InfoLine(
                    icon: Icons.notes_rounded,
                    label: 'Note',
                    value: vente.note!,
                    isLast: true,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ====== Articles ======
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Articles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextMuted,
            ),
          ),
        ),
        Card(
          child: Column(
            children: vente.articles
                .asMap()
                .entries
                .map((e) => _ArticleLine(
                      article: e.value,
                      isLast: e.key == vente.articles.length - 1,
                      devise: controller.devise,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ====== Totaux ======
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _TotalLine(
                  label: 'Sous-total',
                  value: Fmt.money(vente.sousTotal, currency: controller.devise),
                ),
                if (vente.remise > 0)
                  _TotalLine(
                    label: 'Remise',
                    value: '-${Fmt.money(vente.remise, currency: controller.devise)}',
                    color: AppColors.success,
                  ),
                const Divider(),
                _TotalLine(
                  label: 'TOTAL',
                  value: Fmt.money(vente.total, currency: controller.devise),
                  big: true,
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                _TotalLine(
                  label: 'Montant payé (cash)',
                  value: Fmt.money(vente.montantPaye,
                      currency: controller.devise),
                ),
                if (vente.avanceUtilisee > 0)
                  _TotalLine(
                    label: 'Avance utilisée',
                    value: Fmt.money(vente.avanceUtilisee,
                        currency: controller.devise),
                    color: AppColors.secondary,
                  ),
                if (vente.resteAPayer > 0)
                  _TotalLine(
                    label: 'Reste à payer',
                    value:
                        '${Fmt.money(vente.resteAPayer, currency: controller.devise)} (crédit)',
                    color: AppColors.warning,
                  )
                else if (vente.resteAPayer < 0)
                  _TotalLine(
                    label: 'Trop-perçu',
                    value: Fmt.money(vente.resteAPayer.abs(),
                        currency: controller.devise),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
  final VenteArticle article;
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
                      article.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${Fmt.money(article.prixUnitaire, currency: devise)} x ${article.quantite}'
                      '${article.remise > 0 ? '  • remise ${Fmt.money(article.remise, currency: devise)}' : ''}',
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
