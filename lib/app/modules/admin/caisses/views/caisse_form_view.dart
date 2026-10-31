import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/caisse_form_controller.dart';

class CaisseFormView extends GetView<CaisseFormController> {
  const CaisseFormView({super.key});

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
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  hintText: 'Ex. Tiroir espèces, Orange Money, Banque',
                ),
                textCapitalization: TextCapitalization.words,
                validator: controller.validateNom,
              ),
              const SizedBox(height: 14),

              // Solde de départ : à la création uniquement. Ensuite le
              // solde ne bouge que par des mouvements (RG-5), il n'y a
              // donc rien à saisir ici.
              if (!controller.isEdit) ...[
                TextFormField(
                  controller: controller.soldeDepartCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Solde de départ',
                    prefixIcon: Icon(Icons.savings_outlined),
                    suffixText: 'GNF',
                    helperText:
                        'Argent déjà présent dans la caisse aujourd\'hui. '
                        'Enregistré comme mouvement « Ouverture ».',
                    helperMaxLines: 3,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: controller.validateSoldeDepart,
                ),
                const SizedBox(height: 14),
              ] else
                const _SoldeVerrouille(),

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
                    onChanged: controller.setBoutique,
                    validator: controller.validateBoutique,
                  );
                })
              else
                Obx(() {
                  final b = controller.boutiques.firstWhereOrNull(
                      (x) => x.id == controller.boutiqueId.value);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary(context).withValues(alpha: 0.06),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),

              const _AccesGestionnaires(),
              const Divider(height: 28),

              Obx(
                () => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: controller.autoriseNegatif.value,
                  onChanged: (v) => controller.autoriseNegatif.value = v,
                  title: const Text('Autoriser le solde négatif'),
                  subtitle: Text(
                    controller.autoriseNegatif.value
                        ? 'Les sorties sont acceptées même sans fonds suffisants.'
                        : 'Une sortie supérieure au solde sera refusée.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.greyText(context, 600),
                    ),
                  ),
                ),
              ),
              Obx(
                () => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: controller.active.value,
                  onChanged: (v) => controller.active.value = v,
                  title: const Text('Proposée dans les opérations'),
                  subtitle: Text(
                    controller.active.value
                        ? 'Disponible pour les ventes, dépenses et règlements.'
                        : 'Masquée des opérations. Solde et relevés restent lisibles.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.greyText(context, 600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: controller.ordreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ordre d\'affichage',
                  prefixIcon: Icon(Icons.sort_rounded),
                  helperText: 'Les plus petits apparaissent en premier.',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),

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
                    controller.isEdit ? 'Enregistrer' : 'Créer la caisse',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary(context),
                  side:
                      BorderSide(color: AppColors.primary(context), width: 1.4),
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

/// Rappelle, en modification, pourquoi le solde n'est pas saisissable.
class _SoldeVerrouille extends StatelessWidget {
  const _SoldeVerrouille();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.greyText(context, 400).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.greyText(context, 700)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Le solde ne se modifie pas ici. Il ne bouge que par les '
                'opérations, les transferts et les corrections.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.greyText(context, 700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Case « Accessible aux gestionnaires » et choix des gestionnaires (RG-2).
class _AccesGestionnaires extends StatelessWidget {
  const _AccesGestionnaires();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CaisseFormController>();
    return Obx(() {
      // Lecture explicite : la liste des gestionnaires arrive par stream
      // et les options sont construites plus bas, hors de portée du scope
      // si on ne touche pas la liste ici.
      final dispo = c.gestionnairesDisponibles;
      final aucun = dispo.isEmpty;
      final coche = c.accessibleGestionnaires.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: coche && !aucun,
            // Boutique sans gestionnaire : case inactive (RG-2).
            onChanged: aucun ? null : c.setAccessibleGestionnaires,
            title: const Text('Accessible aux gestionnaires'),
            subtitle: Text(
              aucun
                  ? 'Aucun gestionnaire dans cette boutique.'
                  : coche
                      ? 'Choisissez qui peut l\'utiliser.'
                      : 'Seuls les administrateurs y auront accès.',
              style: TextStyle(
                fontSize: 11.5,
                color: aucun
                    ? AppColors.warning
                    : AppColors.greyText(context, 600),
              ),
            ),
          ),
          if (coche && !aucun) ...[
            const SizedBox(height: 4),
            if (dispo.length == 1)
              // Un seul gestionnaire : il est sélectionné d'office, on
              // affiche son nom pour confirmation plutôt qu'une case à
              // cocher inutile.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 18, color: AppColors.primary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${dispo.first.nom} aura accès à cette caisse.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...dispo.map(
                (u) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: c.gestionnaireIds.contains(u.id),
                  onChanged: (_) => c.toggleGestionnaire(u.id),
                  title: Text(u.nom, style: const TextStyle(fontSize: 14)),
                  subtitle: u.telephone == null || u.telephone!.isEmpty
                      ? null
                      : Text(
                          u.telephone!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                ),
              ),
          ],
        ],
      );
    });
  }
}
