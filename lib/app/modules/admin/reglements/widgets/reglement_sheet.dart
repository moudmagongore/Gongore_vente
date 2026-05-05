import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/reglement_receipt_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/reglement_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/reglement_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../theme/app_colors.dart';

/// Bottom sheet de saisie d'un règlement pour un client donné.
/// Pré-remplit le montant avec la dette en cours (si > 0).
/// `onDone` est appelé après création réussie (utile pour refresh la fiche).
class ReglementSheet extends StatefulWidget {
  final ClientModel client;
  final VoidCallback? onDone;
  const ReglementSheet({super.key, required this.client, this.onDone});

  /// Helper d'ouverture pratique — uniformise l'animation et la couleur.
  static void open(BuildContext context, ClientModel client,
      {VoidCallback? onDone}) {
    Get.bottomSheet(
      ReglementSheet(client: client, onDone: onDone),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<ReglementSheet> createState() => _ReglementSheetState();
}

class _ReglementSheetState extends State<ReglementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  ModePaiement _mode = ModePaiement.especes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.client.solde > 0) {
      _montantCtrl.text = widget.client.solde.toStringAsFixed(0);
    }
  }

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

    setState(() => _saving = true);
    try {
      final userId = UserController.to.user?.id ?? '';
      final reg = ReglementModel(
        id: '',
        clientId: widget.client.id,
        boutiqueId: widget.client.boutiqueId,
        userId: userId,
        montant: montant,
        modePaiement: _mode,
        date: DateTime.now(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      final saved = await ReglementRepository().create(reg);
      widget.onDone?.call();
      Get.back();
      Get.snackbar(
        'Règlement enregistré',
        '${Fmt.number(montant)} encaissé sur ${widget.client.nom}',
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

  /// Propose à l'utilisateur d'imprimer un reçu après l'enregistrement.
  /// Récupère boutique et vendeur en parallèle pour pré-remplir le PDF.
  Future<void> _proposerImpression(ReglementModel saved) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Imprimer le reçu ?'),
        content: Text(
          'Voulez-vous imprimer ou partager un reçu pour le règlement de '
          '${Fmt.number(saved.montant)} ${widget.client.nom} ?',
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
      final boutique = await BoutiqueRepository().getById(saved.boutiqueId);
      if (boutique == null) {
        Get.snackbar(
          'Erreur',
          'Boutique introuvable pour le reçu.',
          snackPosition: SnackPosition.TOP,
        );
        return;
      }
      final vendeur = saved.userId.isEmpty
          ? null
          : await UserRepository().getById(saved.userId);
      // Solde après imputation : solde courant - montant du règlement.
      final soldeApres = widget.client.solde - saved.montant;
      await ReglementReceiptService.sharePrint(
        reglement: saved,
        boutique: boutique,
        client: widget.client,
        vendeur: vendeur,
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
    final c = widget.client;
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final viewPadding = mq.viewPadding.bottom;
    // Plafond basé sur la hauteur VISIBLE (écran - clavier) pour toujours
    // laisser un espace en haut quand le clavier est ouvert.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    return ConstrainedBox(
      // Évite que le sheet remplisse tout l'écran quand le clavier s'ouvre.
      constraints: BoxConstraints(maxHeight: maxH),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // viewInsets = clavier ; viewPadding = barre de gestes Android.
          // On garde le max des deux pour ne pas masquer le contenu.
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
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Encaisser ${c.nom}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c.solde > 0
                              ? 'Solde dû : ${Fmt.number(c.solde)}'
                              : 'Aucune dette en cours',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.solde > 0
                                ? AppColors.warning
                                : Colors.grey.shade700,
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
                autofocus: true,
              ),
              const SizedBox(height: 14),
              const Text(
                'Mode',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ModePaiement.values
                    .map(
                      (m) => ChoiceChip(
                        label: Text(m.label),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
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
                onPressed: _saving ? null : _save,
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
                label: const Text('Enregistrer le règlement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
