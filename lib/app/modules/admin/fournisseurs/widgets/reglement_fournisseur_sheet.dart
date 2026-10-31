import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/reglement_fournisseur_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/utils/caisse_calculator.dart';
import '../../../../core/utils/caisse_contexte.dart';
import '../../../../core/widgets/paiements_caisse_field.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/paiement_caisse.dart';
import '../../../../data/models/reglement_fournisseur_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/reglement_fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../theme/app_colors.dart';

/// Bottom sheet de saisie d'un règlement fournisseur (versement).
/// Pré-remplit le montant avec la dette en cours (si > 0).
class ReglementFournisseurSheet extends StatefulWidget {
  final FournisseurModel fournisseur;
  final VoidCallback? onDone;
  const ReglementFournisseurSheet({
    super.key,
    required this.fournisseur,
    this.onDone,
  });

  static void open(
    BuildContext context,
    FournisseurModel fournisseur, {
    VoidCallback? onDone,
  }) {
    Get.bottomSheet(
      ReglementFournisseurSheet(
        fournisseur: fournisseur,
        onDone: onDone,
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<ReglementFournisseurSheet> createState() =>
      _ReglementFournisseurSheetState();
}

class _ReglementFournisseurSheetState
    extends State<ReglementFournisseurSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  /// `null` tant que les caisses ne sont pas chargées : le bouton reste
  /// désactivé, sinon un versement pourrait partir sans sortie de caisse
  /// alors que la boutique est équipée.
  CaisseContexte? _ctx;
  List<PaiementCaisse> _paiements = const [];

  @override
  void initState() {
    super.initState();
    if (widget.fournisseur.solde > 0) {
      _montantCtrl.text = widget.fournisseur.solde.toStringAsFixed(0);
    }
    CaisseContexte.charger(widget.fournisseur.boutiqueId).then((ctx) {
      if (mounted) setState(() => _ctx = ctx);
    });
  }

  double get _montantSaisi =>
      double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? 0;
    if (montant <= 0) return;

    final ctx = _ctx ?? CaisseContexte.vide;
    if (ctx.manquante) {
      Get.snackbar('Versement impossible',
          'Aucune caisse disponible, contactez votre administrateur.',
          snackPosition: SnackPosition.TOP);
      return;
    }
    if (ctx.disponible) {
      // RG-11 et RG-14 : le versement doit sortir de caisses identifiées,
      // pour exactement son montant.
      final probleme =
          verifierRepartition(paiements: _paiements, attendu: montant);
      if (_paiements.isEmpty || probleme != null) {
        Get.snackbar(
          'Caisse requise',
          probleme ?? 'Indiquez depuis quelle caisse le versement est fait.',
          snackPosition: SnackPosition.TOP,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final user = UserController.to.user;
      final userId = user?.id ?? '';
      final reg = ReglementFournisseurModel(
        id: '',
        fournisseurId: widget.fournisseur.id,
        boutiqueId: widget.fournisseur.boutiqueId,
        userId: userId,
        montant: montant,
        paiements: _paiements,
        date: DateTime.now(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      final saved = await ReglementFournisseurRepository()
          .create(reg, userNom: user?.nom ?? '');
      widget.onDone?.call();
      Get.back();
      Get.snackbar(
        'Règlement enregistré',
        '${Fmt.number(montant)} versé à ${widget.fournisseur.nom}',
        snackPosition: SnackPosition.TOP,
      );
      await _proposerImpression(saved);
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Enregistrement impossible : $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _proposerImpression(ReglementFournisseurModel saved) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Imprimer le reçu ?'),
        content: Text(
          'Voulez-vous imprimer ou partager un reçu pour le règlement de '
          '${Fmt.number(saved.montant)} versé à ${widget.fournisseur.nom} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final boutique =
          await BoutiqueRepository().getById(saved.boutiqueId);
      if (boutique == null) {
        Get.snackbar(
          'Erreur',
          'Boutique introuvable pour le reçu.',
          snackPosition: SnackPosition.TOP,
        );
        return;
      }
      final user = saved.userId.isEmpty
          ? null
          : await UserRepository().getById(saved.userId);
      // Solde après imputation : solde courant - montant du règlement.
      final soldeApres = widget.fournisseur.solde - saved.montant;
      await ReglementFournisseurReceiptService.sharePrint(
        reglement: saved,
        boutique: boutique,
        fournisseur: widget.fournisseur,
        user: user,
        soldeApres: soldeApres,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impression impossible : $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fournisseur;
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final viewPadding = mq.viewPadding.bottom;
    // Plafond basé sur la hauteur VISIBLE (écran - clavier) pour toujours
    // laisser un espace en haut quand le clavier est ouvert.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, (viewInsets > 0 ? viewInsets : viewPadding) + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.payments_rounded,
                        color: AppColors.primary(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Verser à ${f.nom}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          f.solde > 0
                              ? 'Dette à payer : ${Fmt.number(f.solde)}'
                              : (f.solde < 0
                                  ? 'Avance versée : ${Fmt.number(-f.solde)}'
                                  : 'Aucune dette en cours'),
                          style: TextStyle(
                            fontSize: 12,
                            color: f.solde > 0
                                ? AppColors.warning
                                : AppColors.greyText(context, 700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _montantCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Montant *',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final n = double.tryParse(
                          (v ?? '').replaceAll(',', '.')) ??
                      0;
                  if (n <= 0) return 'Montant requis';
                  return null;
                },
                // La ligne de caisse unique recopie ce montant : il faut
                // reconstruire à chaque frappe.
                onChanged: (_) => setState(() {}),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              PaiementsCaisseBloc(
                contexte: _ctx,
                montant: _montantSaisi,
                onChanged: (p) => _paiements = p,
                estSortie: true,
              ),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                // Désactivé tant que le contexte caisse n'est pas connu.
                onPressed: _saving || _ctx == null ? null : _save,
                icon: _saving
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
                label: const Text('Enregistrer le règlement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
