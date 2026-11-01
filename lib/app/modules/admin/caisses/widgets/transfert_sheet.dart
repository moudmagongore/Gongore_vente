import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/caisses_controller.dart';

/// Transfert d'argent entre deux caisses (RG-20 à RG-23).
///
/// L'admin transfère entre toutes les caisses de sa boutique ; le
/// gestionnaire uniquement entre deux caisses qui lui sont accessibles —
/// la liste proposée est déjà filtrée pour lui par le stream.
class TransfertSheet extends StatefulWidget {
  final CaissesController controller;

  /// Caisse pré-sélectionnée comme source (appel depuis une carte).
  final CaisseModel? source;

  const TransfertSheet({super.key, required this.controller, this.source});

  static void open(
    BuildContext context,
    CaissesController controller, {
    CaisseModel? source,
  }) {
    Get.bottomSheet(
      TransfertSheet(controller: controller, source: source),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<TransfertSheet> createState() => _TransfertSheetState();
}

class _TransfertSheetState extends State<TransfertSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();

  String? _sourceId;
  String? _destinationId;
  bool _saving = false;

  CaissesController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final dispo = c.caissesActives;
    _sourceId = widget.source?.id ?? (dispo.isNotEmpty ? dispo.first.id : null);
    // Première caisse différente de la source : évite d'ouvrir le sheet sur
    // une saisie invalide.
    _destinationId =
        dispo.firstWhereOrNull((x) => x.id != _sourceId)?.id;
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  CaisseModel? get _source =>
      c.caissesActives.firstWhereOrNull((x) => x.id == _sourceId);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final src = _sourceId;
    final dst = _destinationId;
    if (src == null || dst == null) return;
    final user = UserController.to.user;
    final boutiqueId = _source?.boutiqueId ?? '';

    setState(() => _saving = true);
    try {
      await CaisseRepository().transferer(
        boutiqueId: boutiqueId,
        sourceId: src,
        destinationId: dst,
        montant: double.parse(_montantCtrl.text.trim()),
        userId: user?.id ?? '',
        userNom: user?.nom ?? '',
        commentaire: _commentaireCtrl.text.trim().isEmpty
            ? null
            : _commentaireCtrl.text.trim(),
      );
      if (!mounted) return;
      // `Navigator.pop` et non `Get.back()` : ce dernier viserait la route
      // la plus haute, or un snackbar GetX en est une.
      Navigator.of(context).pop();
      Get.snackbar('Transfert effectué', 'Les deux soldes sont à jour.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar(
        'Transfert impossible',
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
                        color: AppColors.primary(context)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.swap_horiz_rounded,
                          color: AppColors.primary(context), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Transférer entre caisses',
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
                Obx(() {
                  final dispo = c.caissesActives;
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            dispo.any((x) => x.id == _sourceId)
                                ? _sourceId
                                : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Depuis *',
                          prefixIcon: Icon(Icons.arrow_upward_rounded),
                          isDense: true,
                        ),
                        items: dispo
                            .map((x) => DropdownMenuItem(
                                  value: x.id,
                                  child: Text(
                                    '${x.nom} — '
                                    '${Fmt.money(x.solde, currency: 'GNF')}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _sourceId = v;
                          if (_destinationId == v) _destinationId = null;
                        }),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Caisse requise' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            dispo.any((x) => x.id == _destinationId)
                                ? _destinationId
                                : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vers *',
                          prefixIcon: Icon(Icons.arrow_downward_rounded),
                          isDense: true,
                        ),
                        // La source ne figure pas dans la liste : deux
                        // caisses identiques seraient refusées de toute
                        // façon, autant ne pas les proposer.
                        items: dispo
                            .where((x) => x.id != _sourceId)
                            .map((x) => DropdownMenuItem(
                                  value: x.id,
                                  child: Text(
                                    '${x.nom} — '
                                    '${Fmt.money(x.solde, currency: 'GNF')}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _destinationId = v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Caisse requise' : null,
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montantCtrl,
                  decoration: InputDecoration(
                    labelText: 'Montant *',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: 'GNF',
                    isDense: true,
                    helperText: _source == null
                        ? null
                        : 'Disponible : '
                            '${Fmt.money(_source!.solde, currency: 'GNF')}',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final montant = double.tryParse((v ?? '').trim());
                    if (montant == null || montant <= 0) {
                      return 'Montant requis';
                    }
                    final src = _source;
                    // Contrôle indicatif : la transaction refait le calcul
                    // sur le solde frais, qui peut avoir bougé entre-temps.
                    if (src != null &&
                        !src.autoriseNegatif &&
                        montant > src.solde) {
                      return 'Solde insuffisant sur ${src.nom}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentaireCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (facultatif)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'Versement à la banque, appoint...',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
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
                      : const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transférer',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
