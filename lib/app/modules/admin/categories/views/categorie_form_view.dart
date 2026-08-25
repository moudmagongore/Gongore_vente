import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/categorie_form_controller.dart';

class CategorieFormView extends GetView<CategorieFormController> {
  const CategorieFormView({super.key});

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
            TextFormField(
              controller: controller.nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                prefixIcon: Icon(Icons.label_outline_rounded),
                hintText: 'Ex. Boissons',
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
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 14),
            // Sélecteur boutique : super-admin choisit, admin a sa boutique forcée
            if (controller.canPickBoutique)
              Obx(() {
                final safeId = controller.boutiques
                        .any((b) => b.id == controller.boutiqueId.value)
                    ? controller.boutiqueId.value
                    : null;
                return DropdownButtonFormField<String>(
                  initialValue: safeId,
                  decoration: const InputDecoration(
                    labelText: 'Boutique *',
                    prefixIcon: Icon(Icons.store_outlined),
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
              })
            else
              Obx(() {
                final bId = controller.boutiqueId.value;
                final b = controller.boutiques
                    .firstWhereOrNull((x) => x.id == bId);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store_rounded,
                          color: AppColors.primary(context)),
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
              }),
            const SizedBox(height: 32),
            Obx(
              () => ElevatedButton.icon(
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
                label: Text(
                  controller.isEdit ? 'Enregistrer' : 'Créer la catégorie',
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary(context),
                side: BorderSide(
                    color: AppColors.primary(context), width: 1.4),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
