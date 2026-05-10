import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../data/models/abonnement_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/abonnement_form_controller.dart';

class AbonnementFormView extends GetView<AbonnementFormController> {
  const AbonnementFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer un paiement')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Sélection boutique
              Obx(() {
                final list = controller.boutiques.toList()
                  ..sort((a, b) => a.nom.toLowerCase()
                      .compareTo(b.nom.toLowerCase()));
                return DropdownButtonFormField<String>(
                  initialValue: controller.boutiqueId.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Boutique *',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: list
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.nom,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => controller.boutiqueId.value = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Boutique requise' : null,
                );
              }),
              const SizedBox(height: 14),

              // Période — la `key` change avec la valeur pour forcer Flutter
              // à recréer le DropdownButtonFormField quand la période est
              // modifiée par programme (chargement du dernier paiement).
              // Sans cette clé, `initialValue` est consommé une seule fois
              // au premier build et le dropdown reste visuellement bloqué
              // sur "Mensuel" même après que `controller.periode.value`
              // soit passé à "Annuel".
              Obx(
                () => DropdownButtonFormField<AbonnementPeriode>(
                  key: ValueKey('periode_${controller.periode.value.name}'),
                  initialValue: controller.periode.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Période *',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                  ),
                  items: controller.periodes
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.periode.value = v;
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Montant
              Obx(
                () => TextFormField(
                  controller: controller.montantCtrl,
                  decoration: InputDecoration(
                    labelText: 'Montant *',
                    suffixText: controller.devise,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: controller.validateMontant,
                ),
              ),
              const SizedBox(height: 14),

              // Note
              TextFormField(
                controller: controller.noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  hintText: 'Ex: Mobile Money, ref XYZ',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Récap période :
              //   • Si un abonnement EXISTE pour la boutique → affiche ses
              //     dates EXACTES (du dateDebut au dateFin) — données
              //     conformes à l'abonnement sélectionné.
              //   • Sinon (boutique sans abonnement) → forecast de la
              //     période qui sera créée à l'enregistrement.
              Obx(() {
                final latest = controller.latestAbonnement.value;
                final p = controller.periode.value;
                final boutique = controller.selectedBoutique;
                final endsAt = boutique?.subscriptionEndsAt;
                final now = DateTime.now();
                final color = AppColors.primary(context);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest != null
                            ? 'Abonnement actuel'
                            : 'Période ajoutée',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (latest != null) ...[
                        // Dates EXACTES du dernier abonnement enregistré
                        // pour cette boutique : conforme à ce que l'admin
                        // s'attend à voir quand il clique sur la fiche.
                        Text(
                          '${latest.periode.label} — du '
                          '${_fmt(latest.dateDebut)} au ${_fmt(latest.dateFin)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Un nouveau paiement (${p.nbMois} mois) prolongera '
                          'cet abonnement à partir du '
                          '${_fmt(endsAt != null && endsAt.isAfter(now) ? endsAt : now)}.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '+ ${p.nbMois} mois à partir de ${_fmt(now)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Submit
              Obx(
                () => FilledButton.icon(
                  onPressed:
                      controller.isSaving.value ? null : controller.save,
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(controller.isSaving.value
                      ? 'Enregistrement...'
                      : 'Enregistrer le paiement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
