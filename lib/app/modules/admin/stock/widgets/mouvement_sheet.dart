import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/repositories/mouvement_stock_repository.dart';
import '../../../../theme/app_colors.dart';

/// Bottom sheet de saisie d'un mouvement de stock manuel pour un
/// produit donné.
///
/// - `sortie/perte/casse/entree` : `quantite` = nb d'unités à appliquer
/// - `ajustement` : `quantite` = nouvelle qté cible (valeur absolue)
class MouvementSheet extends StatefulWidget {
  final ProduitModel produit;
  const MouvementSheet({super.key, required this.produit});

  static void open(BuildContext context, ProduitModel produit) {
    Get.bottomSheet(
      MouvementSheet(produit: produit),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<MouvementSheet> createState() => _MouvementSheetState();
}

class _MouvementSheetState extends State<MouvementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qteCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  MouvementStockType _type = MouvementStockType.sortie;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pour ajustement, pré-remplir avec la qté actuelle (l'utilisateur
    // ajuste autour).
    _qteCtrl.text = '';
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(MouvementStockType t) {
    setState(() {
      _type = t;
      if (t == MouvementStockType.ajustement) {
        _qteCtrl.text = widget.produit.quantiteStock.toString();
      } else {
        _qteCtrl.clear();
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final qte = int.tryParse(_qteCtrl.text.trim()) ?? -1;
    if (qte < 0) return;

    setState(() => _saving = true);
    try {
      final userId = UserController.to.user?.id ?? '';
      await MouvementStockRepository().create(
        produitId: widget.produit.id,
        boutiqueId: widget.produit.boutiqueId,
        userId: userId,
        type: _type,
        quantite: qte,
        motif: _motifCtrl.text.trim().isEmpty
            ? null
            : _motifCtrl.text.trim(),
      );
      Get.back();
      Get.snackbar(
        'Mouvement enregistré',
        '${_type.label} sur ${widget.produit.nom}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _previewQteApres() {
    final qte = int.tryParse(_qteCtrl.text.trim());
    if (qte == null || qte < 0) return '—';
    final actuel = widget.produit.quantiteStock;
    switch (_type) {
      case MouvementStockType.entree:
        return '${actuel + qte}';
      case MouvementStockType.sortie:
      case MouvementStockType.perte:
      case MouvementStockType.casse:
        final apres = actuel - qte;
        if (apres < 0) return '$apres ⚠️';
        return '$apres';
      case MouvementStockType.ajustement:
        return '$qte';
    }
  }

  String _quantiteLabel() {
    switch (_type) {
      case MouvementStockType.ajustement:
        return 'Quantité finale (cible) *';
      default:
        return 'Quantité *';
    }
  }

  String? _quantiteHelper() {
    switch (_type) {
      case MouvementStockType.ajustement:
        return 'Le stock prendra cette valeur exactement';
      case MouvementStockType.entree:
        return 'Préférez un appro pour conserver le CMUP';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, (viewInsets > 0 ? viewInsets : viewPadding) + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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

                // En-tête produit + qté actuelle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.nom,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Stock actuel : ${p.quantiteStock}'
                            '${p.unite != null ? ' ${p.unite}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Type de mouvement
                const Text(
                  'Type de mouvement',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MouvementStockType.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => _onTypeChanged(t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Quantité
                TextFormField(
                  controller: _qteCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: _quantiteLabel(),
                    helperText: _quantiteHelper(),
                    prefixIcon: const Icon(Icons.numbers_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim()) ?? -1;
                    if (n < 0) return 'Quantité requise';
                    if (_type != MouvementStockType.ajustement && n == 0) {
                      return 'Doit être > 0';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 14),

                // Preview qté après
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Stock après mouvement :',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        _previewQteApres(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Motif (recommandé pour perte/casse)
                TextFormField(
                  controller: _motifCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motif (recommandé)',
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
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer le mouvement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
