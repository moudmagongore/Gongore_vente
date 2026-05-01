import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/mouvement_controller.dart';

class MouvementFormView extends GetView<MouvementController> {
  const MouvementFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.title))),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Sous-type pour les sorties
            Obx(() {
              if (![
                MouvementType.sortie,
                MouvementType.perte,
                MouvementType.casse,
              ].contains(controller.type.value)) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SegmentedButton<MouvementType>(
                  segments: const [
                    ButtonSegment(
                      value: MouvementType.sortie,
                      label: Text('Sortie'),
                      icon: Icon(Icons.north_rounded),
                    ),
                    ButtonSegment(
                      value: MouvementType.perte,
                      label: Text('Perte'),
                      icon: Icon(Icons.report_problem_outlined),
                    ),
                    ButtonSegment(
                      value: MouvementType.casse,
                      label: Text('Casse'),
                      icon: Icon(Icons.broken_image_outlined),
                    ),
                  ],
                  selected: {controller.sortieType.value},
                  onSelectionChanged: (s) =>
                      controller.sortieType.value = s.first,
                ),
              );
            }),

            // Boutique source — verrouillée pour admin de boutique
            Obx(() {
              if (!controller.isSuperAdmin) {
                final b = controller.boutiques.firstWhereOrNull(
                    (x) => x.id == controller.boutiqueId.value);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Boutique : ${b?.nom ?? '—'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: controller.boutiqueId.value,
                decoration: InputDecoration(
                  labelText: controller.needsDestination
                      ? 'Boutique source *'
                      : 'Boutique *',
                  prefixIcon: const Icon(Icons.store_outlined),
                ),
                items: controller.boutiques
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.nom),
                        ))
                    .toList(),
                onChanged: (v) => controller.boutiqueId.value = v,
                validator: controller.validateBoutique,
              );
            }),

            // Boutique destination (transfert seulement)
            Obx(() {
              if (!controller.needsDestination) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: DropdownButtonFormField<String>(
                  initialValue: controller.boutiqueDestId.value,
                  decoration: const InputDecoration(
                    labelText: 'Boutique destination *',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  items: controller.boutiques
                      .where((b) => b.id != controller.boutiqueId.value)
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.nom),
                          ))
                      .toList(),
                  onChanged: (v) => controller.boutiqueDestId.value = v,
                  validator: controller.validateBoutiqueDest,
                ),
              );
            }),
            const SizedBox(height: 14),

            // Produit
            Obx(() => DropdownButtonFormField<String>(
                  initialValue: controller.produitId.value,
                  decoration: const InputDecoration(
                    labelText: 'Produit *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: controller.produits
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: controller.boutiqueId.value == null
                      ? null
                      : (v) => controller.produitId.value = v,
                  validator: controller.validateProduit,
                )),
            const SizedBox(height: 8),

            // Stock actuel info
            Obx(() {
              if (controller.produitId.value == null) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Stock actuel : ${controller.stockActuel.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),

            // Quantité
            Obx(() => TextFormField(
                  controller: controller.quantiteCtrl,
                  decoration: InputDecoration(
                    labelText: controller.type.value == MouvementType.ajustement
                        ? 'Nouvelle quantité *'
                        : 'Quantité *',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: controller.validateQuantite,
                )),
            const SizedBox(height: 14),

            // Motif
            Obx(() => TextFormField(
                  controller: controller.motifCtrl,
                  decoration: InputDecoration(
                    labelText: controller.type.value == MouvementType.ajustement
                        ? 'Motif *'
                        : 'Motif (optionnel)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    hintText: _hintMotif(controller.type.value),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  validator: controller.validateMotif,
                )),
            const SizedBox(height: 32),

            Obx(() => ElevatedButton.icon(
                  onPressed:
                      controller.isSaving.value ? null : controller.save,
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Valider le mouvement'),
                )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  String _hintMotif(MouvementType t) {
    switch (t) {
      case MouvementType.entree:
        return 'Ex. Livraison fournisseur X';
      case MouvementType.sortie:
        return 'Ex. Sortie pour usage interne';
      case MouvementType.perte:
        return 'Ex. Vol, expiration...';
      case MouvementType.casse:
        return 'Ex. Article cassé';
      case MouvementType.transfert:
        return 'Ex. Approvisionnement';
      case MouvementType.ajustement:
        return 'Inventaire physique du JJ/MM';
      case MouvementType.vente:
        return '';
    }
  }
}
