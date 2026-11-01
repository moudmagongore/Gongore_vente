import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../data/models/mouvement_caisse_model.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/caisses_controller.dart';

/// Apport, retrait ou correction de caisse (RG-25). **Admin uniquement.**
///
/// Ces mouvements n'ont aucune opération derrière eux : le motif est donc
/// obligatoire, c'est la seule trace de leur raison. Ils n'entrent ni dans
/// le chiffre d'affaires ni dans les charges (RG-28) — ils ne vivent que
/// dans `mouvementsCaisse`, qu'aucun rapport de vente ne lit.
class MouvementManuelSheet extends StatefulWidget {
  final CaissesController controller;
  final CaisseModel? caisse;

  const MouvementManuelSheet({
    super.key,
    required this.controller,
    this.caisse,
  });

  static void open(
    BuildContext context,
    CaissesController controller, {
    CaisseModel? caisse,
  }) {
    Get.bottomSheet(
      MouvementManuelSheet(controller: controller, caisse: caisse),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<MouvementManuelSheet> createState() => _MouvementManuelSheetState();
}

class _MouvementManuelSheetState extends State<MouvementManuelSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  String? _caisseId;
  TypeMouvementCaisse _type = TypeMouvementCaisse.apport;

  /// Sens choisi, utile uniquement pour une correction : un apport est
  /// toujours une entrée, un retrait toujours une sortie.
  SensMouvement _sensCorrection = SensMouvement.entree;

  bool _saving = false;

  CaissesController get c => widget.controller;

  SensMouvement get _sens {
    switch (_type) {
      case TypeMouvementCaisse.apport:
        return SensMouvement.entree;
      case TypeMouvementCaisse.retrait:
        return SensMouvement.sortie;
      default:
        return _sensCorrection;
    }
  }

  @override
  void initState() {
    super.initState();
    final dispo = c.caissesActives;
    _caisseId = widget.caisse?.id ?? (dispo.isNotEmpty ? dispo.first.id : null);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  CaisseModel? get _caisse =>
      c.caisses.firstWhereOrNull((x) => x.id == _caisseId);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final caisse = _caisse;
    if (caisse == null) return;
    final user = UserController.to.user;

    setState(() => _saving = true);
    try {
      await CaisseRepository().mouvementManuel(
        boutiqueId: caisse.boutiqueId,
        caisseId: caisse.id,
        montant: double.parse(_montantCtrl.text.trim()),
        sens: _sens,
        type: _type,
        motif: _motifCtrl.text.trim(),
        userId: user?.id ?? '',
        userNom: user?.nom ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.snackbar('${_type.label} enregistré', caisse.nom,
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar(
        'Enregistrement impossible',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    final estSortie = _sens == SensMouvement.sortie;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(20, 8, 20, mq.viewPadding.bottom + 20),
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
                        color: (estSortie
                                ? AppColors.danger
                                : AppColors.success)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        estSortie
                            ? Icons.call_made_rounded
                            : Icons.call_received_rounded,
                        color:
                            estSortie ? AppColors.danger : AppColors.success,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Mouvement de caisse',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in [
                      TypeMouvementCaisse.apport,
                      TypeMouvementCaisse.retrait,
                      TypeMouvementCaisse.correction,
                    ])
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                if (_type == TypeMouvementCaisse.correction) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sens de la correction',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greyText(context, 700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: SensMouvement.values
                        .map((s) => ChoiceChip(
                              label: Text(s == SensMouvement.entree
                                  ? 'Ajouter au solde'
                                  : 'Retirer du solde'),
                              selected: _sensCorrection == s,
                              onSelected: (_) =>
                                  setState(() => _sensCorrection = s),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Obx(() {
                  // Les caisses désactivées sont proposées ici : une
                  // correction sert justement à rattraper un solde faux sur
                  // une caisse qu'on a cessé d'utiliser.
                  final dispo = c.caisses.toList();
                  return DropdownButtonFormField<String>(
                    initialValue:
                        dispo.any((x) => x.id == _caisseId) ? _caisseId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Caisse *',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      isDense: true,
                    ),
                    items: dispo
                        .map((x) => DropdownMenuItem(
                              value: x.id,
                              child: Text(
                                x.active
                                    ? '${x.nom} — '
                                        '${Fmt.money(x.solde, currency: 'GNF')}'
                                    : '${x.nom} (désactivée) — '
                                        '${Fmt.money(x.solde, currency: 'GNF')}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _caisseId = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Caisse requise' : null,
                  );
                }),
                const SizedBox(height: 12),
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
                  validator: (v) {
                    final montant = double.tryParse((v ?? '').trim());
                    if (montant == null || montant <= 0) {
                      return 'Montant requis';
                    }
                    final caisse = _caisse;
                    if (estSortie &&
                        caisse != null &&
                        !caisse.autoriseNegatif &&
                        montant > caisse.solde) {
                      return 'Solde insuffisant sur ${caisse.nom}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motifCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motif *',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'Apport du propriétaire, erreur de saisie...',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 2,
                  // RG-25 : obligatoire, c'est la seule trace de la raison
                  // du mouvement.
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Motif obligatoire' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Les apports et retraits ne sont ni des ventes ni des '
                  'dépenses : ils n\'entrent pas dans le chiffre d\'affaires '
                  'ni dans les charges.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.greyText(context, 600),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor:
                        estSortie ? AppColors.danger : AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text('Enregistrer ${_type.label.toLowerCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
