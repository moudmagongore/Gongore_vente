import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
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
                      color: AppColors.primary(context).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary(context).withValues(alpha: 0.2),
                      ),
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
              const SizedBox(height: 24),

              Obx(() {
                // Une fois une opération enregistrée, le solde initial n'a plus de
                // sens : on affiche le solde actuel, tenu par les opérations.
                if (controller.soldeVerrouille.value) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionTitle('Solde actuel'),
                      const SizedBox(height: 12),
                      _SoldeActuelBox(
                        solde: controller.soldeActuel,
                        libelleDette: 'à payer',
                        libelleAvance: 'avance',
                        explication: 'Mis à jour automatiquement par les '
                            'approvisionnements et règlements.',
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle('Solde / dette'),
                    const SizedBox(height: 6),
                    Text(
                      'Montant que vous devez déjà à ce fournisseur. Mettez 0 si '
                      'vous êtes à jour. Augmente automatiquement sur les '
                      'approvisionnements non soldés.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.greyText(context, 600)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.soldeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Solde initial',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        hintText: '0',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                    ),
                  ],
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

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.greyText(context, 700),
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

/// Solde actuel en lecture seule, affiché à la place du solde initial
/// une fois que des opérations existent.
class _SoldeActuelBox extends StatelessWidget {
  final double solde;
  final String libelleDette;
  final String libelleAvance;
  final String explication;

  const _SoldeActuelBox({
    required this.solde,
    required this.libelleDette,
    required this.libelleAvance,
    required this.explication,
  });

  @override
  Widget build(BuildContext context) {
    final dette = solde > 0;
    final avance = solde < 0;
    final couleur = dette
        ? AppColors.warning
        : (avance ? AppColors.success : AppColors.greyText(context, 600));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dette
            ? AppColors.warning.withValues(alpha: 0.12)
            : (avance
                ? AppColors.success.withValues(alpha: 0.10)
                : Colors.grey.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.money(solde.abs()),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: couleur,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dette ? libelleDette : (avance ? libelleAvance : 'à jour'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  explication,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.greyText(context, 600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
