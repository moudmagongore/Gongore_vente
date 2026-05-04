import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../controllers/produit_form_controller.dart';

class ProduitFormView extends GetView<ProduitFormController> {
  const ProduitFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.title))),
      body: SafeArea(
        top: false,
        child: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ============ Identité ============
            _Section('Informations'),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: controller.validateNom,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // ============ Boutique & catégorie ============
            _Section(
              controller.canPickBoutique ? 'Boutique et catégorie' : 'Catégorie',
            ),
            const SizedBox(height: 12),
            // Sélecteur boutique uniquement pour super-admin
            if (controller.canPickBoutique)
              Obx(() {
                if (controller.boutiques.isEmpty) {
                  return _Warning(
                    'Aucune boutique active. Créez d\'abord une boutique.',
                  );
                }
                // Si la boutique du produit n'est plus dans la liste
                // (désactivée, supprimée), on tombe sur null pour éviter le crash.
                final safeBoutiqueId = controller.boutiques
                        .any((b) => b.id == controller.boutiqueId.value)
                    ? controller.boutiqueId.value
                    : null;
                return DropdownButtonFormField<String>(
                  initialValue: safeBoutiqueId,
                  decoration: const InputDecoration(
                    labelText: 'Boutique *',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  items: controller.boutiques
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.nom),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => controller.boutiqueId.value = v,
                  validator: controller.validateBoutique,
                );
              }),
            const SizedBox(height: 14),
            Obx(
              () {
                // Si la catégorie du produit n'existe plus dans la liste
                // (filtre boutique multi-tenant), retombe sur null.
                final safeCategorieId = controller.categories
                        .any((c) => c.id == controller.categorieId.value)
                    ? controller.categorieId.value
                    : null;
                return DropdownButtonFormField<String?>(
                  initialValue: safeCategorieId,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Aucune catégorie'),
                    ),
                    ...controller.categories.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.nom),
                      ),
                    ),
                  ],
                  onChanged: (v) => controller.categorieId.value = v,
                );
              },
            ),
            const SizedBox(height: 24),

            // ============ Prix ============
            _Section('Prix'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.prixAchatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prix d\'achat',
                      prefixIcon: Icon(Icons.shopping_cart_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    validator: controller.validatePrixAchat,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.prixVenteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prix de vente *',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    validator: controller.validatePrixVente,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ============ Stock ============
            _Section('Unité & seuil d\'alerte'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.uniteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unité',
                      prefixIcon: Icon(Icons.straighten_rounded),
                      hintText: 'pièce, kg, L...',
                    ),
                    textCapitalization: TextCapitalization.none,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.seuilCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seuil d\'alerte',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                      helperText: 'Stock bas si en dessous',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: controller.validateSeuil,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ============ Statut ============
            _Section('Statut'),
            const SizedBox(height: 6),
            Obx(
              () => SwitchListTile(
                value: controller.active.value,
                onChanged: (v) => controller.active.value = v,
                title: const Text(
                  'Produit actif',
                  style: TextStyle(fontFamily: AppTheme.fontFamily),
                ),
                subtitle: const Text(
                  'Les produits inactifs ne sont pas vendables.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 32),

            // ============ Save ============
            Obx(
              () => ElevatedButton.icon(
                onPressed: controller.isSaving.value ? null : controller.save,
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
                label: Text(
                  controller.isEdit ? 'Enregistrer' : 'Créer le produit',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Annuler'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.lightTextMuted,
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String message;
  const _Warning(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
