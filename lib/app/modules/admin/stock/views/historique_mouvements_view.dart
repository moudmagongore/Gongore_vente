import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/historique_mouvements_controller.dart';

class HistoriqueMouvementsView
    extends GetView<HistoriqueMouvementsController> {
  const HistoriqueMouvementsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des mouvements')),
      body: Column(
        children: [
          _BoutiqueSelector(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.boutiques.isEmpty) {
                return const Center(
                  child: Text('Aucune boutique disponible'),
                );
              }
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.mouvements.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun mouvement enregistré.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: controller.mouvements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _MouvementTile(mouvement: controller.mouvements[i]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BoutiqueSelector extends StatelessWidget {
  final HistoriqueMouvementsController controller;
  const _BoutiqueSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Obx(() {
        if (controller.boutiques.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: controller.boutiqueId.value,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  items: controller.boutiques
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.nom)))
                      .toList(),
                  onChanged: (v) => controller.boutiqueId.value = v,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MouvementTile extends StatelessWidget {
  final MouvementStockModel mouvement;
  const _MouvementTile({required this.mouvement});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HistoriqueMouvementsController>();
    final config = _typeConfig(mouvement.type, mouvement.quantite);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: config.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.produitNom(mouvement.produitId),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        config.qtyLabel,
                        style: TextStyle(
                          color: config.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mouvement.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: config.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (mouvement.boutiqueDestinationId != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      mouvement.quantite > 0
                          ? '⬅ depuis ${controller.boutiqueNom(mouvement.boutiqueDestinationId!)}'
                          : '➡ vers ${controller.boutiqueNom(mouvement.boutiqueDestinationId!)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                  if (mouvement.motif?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      mouvement.motif!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    Fmt.dateTime(mouvement.date),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _Config _typeConfig(MouvementType t, int qty) {
    switch (t) {
      case MouvementType.entree:
        return _Config(Icons.south_rounded, AppColors.success, '+$qty');
      case MouvementType.sortie:
        return _Config(Icons.north_rounded, Colors.orange, '-$qty');
      case MouvementType.perte:
        return _Config(Icons.report_problem_outlined, Colors.red, '-$qty');
      case MouvementType.casse:
        return _Config(Icons.broken_image_outlined, Colors.red, '-$qty');
      case MouvementType.vente:
        return _Config(Icons.point_of_sale_rounded, AppColors.primary, '-$qty');
      case MouvementType.transfert:
        return _Config(
          Icons.swap_horiz_rounded,
          AppColors.primary,
          qty >= 0 ? '+$qty' : '$qty',
        );
      case MouvementType.ajustement:
        return _Config(
          Icons.tune_rounded,
          AppColors.secondary,
          qty >= 0 ? '+$qty' : '$qty',
        );
    }
  }
}

class _Config {
  final IconData icon;
  final Color color;
  final String qtyLabel;
  _Config(this.icon, this.color, this.qtyLabel);
}
