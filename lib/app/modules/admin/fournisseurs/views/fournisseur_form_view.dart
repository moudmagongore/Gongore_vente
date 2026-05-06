import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/fournisseur_form_controller.dart';

class FournisseurFormView extends GetView<FournisseurFormController> {
  const FournisseurFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.title)),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle('Identité'),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du fournisseur *',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: controller.validateNom,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.telephoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+224 ...',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.adresseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 24),

              _SectionTitle('Affectation'),
              const SizedBox(height: 12),
              if (controller.canPickBoutique)
                Obx(() {
                  if (controller.boutiques.isEmpty) {
                    return _WarnBox(
                      message:
                          'Aucune boutique active. Créez d\'abord une boutique.',
                    );
                  }
                  final safeId = controller.boutiques.any(
                          (b) => b.id == controller.boutiqueId.value)
                      ? controller.boutiqueId.value
                      : null;
                  return DropdownButtonFormField<String>(
                    initialValue: safeId,
                    decoration: const InputDecoration(
                      labelText: 'Boutique *',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    items: controller.boutiques
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => controller.boutiqueId.value = v,
                    validator: controller.validateBoutique,
                  );
                })
              else
                Obx(() {
                  final b = controller.boutiques.firstWhereOrNull(
                    (x) => x.id == controller.boutiqueId.value,
                  );
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
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
                }),
              const SizedBox(height: 24),

              _SectionTitle('Note'),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note interne (optionnel)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
              ),
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
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(controller.isEdit
                          ? Icons.check_rounded
                          : Icons.add_business_rounded),
                  label: Text(
                    controller.isEdit
                        ? 'Enregistrer'
                        : 'Créer le fournisseur',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                      color: AppColors.primary, width: 1.4),
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

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

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

class _WarnBox extends StatelessWidget {
  final String message;
  const _WarnBox({required this.message});

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
