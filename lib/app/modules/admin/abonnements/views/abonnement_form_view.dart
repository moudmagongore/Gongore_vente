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
      appBar: AppBar(
        title: Obx(() => Text(
              controller.isEditing
                  ? 'Modifier le paiement'
                  : 'Enregistrer un paiement',
            )),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Sélection boutique — verrouillée en mode édition (un
              // paiement existant ne peut pas être "déplacé" d'une boutique
              // à une autre, ses dates dépendent de l'historique).
              Obx(() {
                final list = controller.boutiques.toList()
                  ..sort((a, b) => a.nom.toLowerCase()
                      .compareTo(b.nom.toLowerCase()));
                final isEditing = controller.isEditing;
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
                  onChanged: isEditing
                      ? null
                      : (v) => controller.boutiqueId.value = v,
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
              //   • En mode édition → affiche le paiement édité (sa
              //     période actuelle, ses dates immuables).
              //   • Si abonnement actuel pour la boutique → affiche les
              //     dates EXACTES du dernier paiement.
              //   • Sinon (boutique sans abonnement) → forecast.
              Obx(() {
                final editing = controller.editing.value;
                final latest = controller.latestAbonnement;
                final ref = editing ?? latest;
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
                        editing != null
                            ? 'Paiement en cours d\'édition'
                            : (latest != null
                                ? 'Abonnement actuel'
                                : 'Période ajoutée'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (ref != null) ...[
                        Text(
                          '${ref.periode.label} — du '
                          '${_fmt(ref.dateDebut)} au ${_fmt(ref.dateFin)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          editing != null
                              ? 'Modifier la période recalculera la date '
                                  'de fin de ce paiement et l\'abonnement '
                                  'de la boutique.'
                              : 'Un nouveau paiement (${p.nbMois} mois) '
                                  'prolongera cet abonnement à partir du '
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

              // Submit — libellé dynamique selon mode création / édition.
              Obx(() {
                final saving = controller.isSaving.value;
                final editing = controller.isEditing;
                return FilledButton.icon(
                  onPressed: saving ? null : controller.save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(editing
                          ? Icons.save_rounded
                          : Icons.check_rounded),
                  label: Text(saving
                      ? (editing ? 'Modification...' : 'Enregistrement...')
                      : (editing
                          ? 'Enregistrer la modification'
                          : 'Enregistrer le paiement')),
                );
              }),

              // Bouton "Annuler la modification" visible uniquement en mode
              // édition — retour en mode création (pré-remplissage depuis
              // le dernier paiement).
              Obx(() {
                if (!controller.isEditing) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: controller.cancelEdit,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Annuler la modification'),
                  ),
                );
              }),

              // Historique des paiements pour la boutique sélectionnée.
              // Chaque ligne : période, dates couvertes, montant, +
              // boutons modifier / supprimer.
              Obx(() {
                final history = controller.historyAbonnements.toList();
                if (history.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded,
                              color: AppColors.primary(context), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Historique des paiements',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.greyText(context, 800),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${history.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greyText(context, 600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...history.map(
                        (abo) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryTile(abo: abo),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Ligne d'historique : affiche un paiement (période, dates, montant) avec
/// les boutons modifier / supprimer. Réagit aux changements de mode
/// édition pour griser la ligne active.
class _HistoryTile extends StatelessWidget {
  final AbonnementModel abo;
  const _HistoryTile({required this.abo});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtMontant(double m) {
    final s = m.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AbonnementFormController>();
    return Obx(() {
      final isCurrent = c.editing.value?.id == abo.id;
      final color = AppColors.primary(context);
      // Nom de la boutique du paiement, résolu depuis la liste live
      // chargée par le contrôleur. Tombe sur '—' si la boutique n'est
      // pas encore arrivée (premier frame avant émission du stream).
      final boutiqueNom = c.boutiques
              .firstWhereOrNull((b) => b.id == abo.boutiqueId)
              ?.nom ??
          '—';
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrent
              ? color.withValues(alpha: 0.08)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? color : AppColors.borderOf(context),
            width: isCurrent ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de la boutique en première ligne pour repérer
                  // immédiatement à quelle boutique appartient ce paiement.
                  Row(
                    children: [
                      Icon(Icons.store_rounded,
                          size: 14, color: AppColors.greyText(context, 700)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          boutiqueNom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greyText(context, 800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        abo.periode.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmtMontant(abo.montant)} ${abo.devise}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'du ${_fmt(abo.dateDebut)} au ${_fmt(abo.dateFin)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.greyText(context, 700),
                    ),
                  ),
                  if (abo.note != null && abo.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      abo.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText(context, 600),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => c.startEdit(abo),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: Colors.red,
              onPressed: () => c.deleteAbonnement(abo),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    });
  }
}
