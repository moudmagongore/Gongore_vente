import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/depense_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/depenses_controller.dart';

/// Bottom sheet de déclaration (ou de correction) d'une dépense.
///
/// La date n'est pas saisissable : elle est posée automatiquement à
/// l'enregistrement. Le sheet l'affiche à titre informatif.
class DepenseSheet extends StatefulWidget {
  final DepensesController controller;

  /// Non nul → mode correction d'une dépense existante.
  final DepenseModel? editing;

  const DepenseSheet({super.key, required this.controller, this.editing});

  static void open(
    BuildContext context,
    DepensesController controller, {
    DepenseModel? editing,
  }) {
    Get.bottomSheet(
      DepenseSheet(controller: controller, editing: editing),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<DepenseSheet> createState() => _DepenseSheetState();
}

class _DepenseSheetState extends State<DepenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();

  String? _boutiqueId;
  String? _natureId;

  DepensesController get c => widget.controller;
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editing;
    if (edit != null) {
      _boutiqueId = edit.boutiqueId;
      _natureId = edit.natureId;
      _montantCtrl.text = edit.montant.toStringAsFixed(0);
      _commentaireCtrl.text = edit.commentaire ?? '';
    } else {
      // Boutique par défaut : le scope de l'utilisateur, ou la boutique
      // actuellement filtrée pour le super-admin.
      _boutiqueId = UserController.to.scopeBoutiqueId ??
          c.filterBoutiqueId.value;
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final viewPadding = mq.viewPadding.bottom;
    // Plafond calculé sur la hauteur VISIBLE (écran - clavier), sinon le
    // sheet dépasse en haut une fois le clavier ouvert.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          // Pas de `viewInsets` ici : Get.bottomSheet décale déjà le sheet
          // au-dessus du clavier, l'ajouter le remonterait deux fois. On
          // ne compense que le home indicator iOS / la barre Android.
          padding: EdgeInsets.fromLTRB(20, 8, 20, viewPadding + 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.danger, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEdit
                            ? 'Corriger la dépense'
                            : 'Déclarer une dépense',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DateBanner(date: widget.editing?.date ?? DateTime.now()),
                const SizedBox(height: 16),

                // Boutique : sélectionnable uniquement par le super-admin
                // en création (elle détermine les natures disponibles).
                if (c.isSuperAdmin && !_isEdit) ...[
                  Obx(() => DropdownButtonFormField<String>(
                        initialValue: c.boutiques
                                .any((b) => b.id == _boutiqueId)
                            ? _boutiqueId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Boutique *',
                          prefixIcon: Icon(Icons.store_outlined),
                          isDense: true,
                        ),
                        items: c.boutiques
                            .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.nom),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _boutiqueId = v;
                          _natureId = null;
                        }),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Boutique requise' : null,
                      )),
                  const SizedBox(height: 14),
                ],

                Obx(() {
                  // Lecture inconditionnelle : quand `_boutiqueId` est nul,
                  // `naturesActives` sort avant de toucher à `natures` et
                  // l'Obx se retrouverait sans observable à écouter.
                  c.natures.length;
                  final natures = c.naturesActives(_boutiqueId);
                  if (natures.isEmpty) return _NoNature(boutiqueId: _boutiqueId);
                  // Une nature devenue inactive reste sélectionnée en
                  // correction : on l'ajoute à la liste pour ne pas vider
                  // le champ silencieusement.
                  final items = [...natures];
                  if (_natureId != null &&
                      !items.any((n) => n.id == _natureId)) {
                    final orpheline = c.natures
                        .firstWhereOrNull((n) => n.id == _natureId);
                    if (orpheline != null) items.insert(0, orpheline);
                  }
                  return DropdownButtonFormField<String>(
                    initialValue:
                        items.any((n) => n.id == _natureId) ? _natureId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nature de la dépense *',
                      prefixIcon: Icon(Icons.category_outlined),
                      isDense: true,
                    ),
                    items: items
                        .map((n) => DropdownMenuItem(
                              value: n.id,
                              child: Text(
                                n.active ? n.nom : '${n.nom} (inactive)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _natureId = v),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Nature de dépense requise'
                        : null,
                  );
                }),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _montantCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Montant *',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: 'GNF',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateMontant,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _commentaireCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (facultatif)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'Référence facture, précision...',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 22),

                Obx(
                  () => ElevatedButton.icon(
                    onPressed: c.isSaving.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: c.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isEdit ? 'Enregistrer' : 'Enregistrer la dépense',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateMontant(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Montant requis';
    final montant = double.tryParse(value);
    if (montant == null) return 'Montant invalide';
    if (montant <= 0) return 'Le montant doit être supérieur à 0';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final nature = c.natures.firstWhereOrNull((n) => n.id == _natureId);
    if (nature == null) {
      Get.snackbar('Erreur', 'Nature de dépense introuvable.',
          snackPosition: SnackPosition.TOP);
      return;
    }
    final montant = double.parse(_montantCtrl.text.trim());
    final commentaire = _commentaireCtrl.text.trim().isEmpty
        ? null
        : _commentaireCtrl.text.trim();

    final ok = _isEdit
        ? await c.corriger(
            depense: widget.editing!,
            nature: nature,
            montant: montant,
            commentaire: commentaire,
          )
        : await c.declarer(
            nature: nature,
            montant: montant,
            commentaire: commentaire,
          );
    if (!ok || !mounted) return;
    // `Navigator.pop` et non `Get.back()` : ce dernier viserait la route la
    // plus haute, or un snackbar GetX affiché entre-temps en est une. On
    // ferme donc explicitement la route du sheet, PUIS on confirme.
    Navigator.of(context).pop();
    c.snackSucces(edition: _isEdit, natureNom: nature.nom);
  }
}

/// Rappel de la date retenue pour la dépense — non modifiable.
class _DateBanner extends StatelessWidget {
  final DateTime date;
  const _DateBanner({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded,
              size: 16, color: AppColors.primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Date de la dépense : ${Fmt.dateTime(date)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aucune nature active pour la boutique : la saisie est impossible tant
/// que l'admin n'a pas paramétré le référentiel.
class _NoNature extends StatelessWidget {
  final String? boutiqueId;
  const _NoNature({required this.boutiqueId});

  @override
  Widget build(BuildContext context) {
    final peutParametrer = UserController.to.canManageCatalog;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  boutiqueId == null || boutiqueId!.isEmpty
                      ? 'Sélectionnez d\'abord une boutique.'
                      : 'Aucune nature de dépense active pour cette boutique.',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (peutParametrer && (boutiqueId?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Get.back();
                Get.toNamed(AppRoutes.adminNaturesDepense);
              },
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Paramétrer les natures'),
            ),
          ] else if (!peutParametrer) ...[
            const SizedBox(height: 6),
            Text(
              'Demandez à l\'administrateur de la boutique d\'en créer.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.greyText(context, 700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
