import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/boutique_form_controller.dart';

class BoutiqueFormView extends GetView<BoutiqueFormController> {
  const BoutiqueFormView({super.key});

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
            TextFormField(
              controller: controller.nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la boutique *',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: controller.validateNom,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.adresseCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
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
            const SizedBox(height: 20),
            Obx(
              () => SwitchListTile(
                value: controller.active.value,
                onChanged: (v) => controller.active.value = v,
                title: const Text('Boutique active'),
                subtitle: Text(
                  controller.active.value
                      ? 'Visible et utilisable par les vendeurs'
                      : 'Masquée et inutilisable',
                  style: const TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
              ),
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
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  controller.isEdit ? 'Enregistrer' : 'Créer la boutique',
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
