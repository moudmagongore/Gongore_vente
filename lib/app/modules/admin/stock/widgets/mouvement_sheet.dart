import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/variante_model.dart';
import '../../../../data/repositories/mouvement_stock_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../theme/app_colors.dart';

/// Bottom sheet de saisie d'un mouvement de stock manuel pour un
/// produit donné.
///
/// - `sortie/perte/casse/entree` : `quantite` = nb d'unités à appliquer
/// - `ajustement` : `quantite` = nouvelle qté cible (valeur absolue)
class MouvementSheet extends StatefulWidget {
  final ProduitModel produit;

  /// Variante ciblée (uniquement quand `produit.hasVariantes`).
  final VarianteModel? variante;

  const MouvementSheet({
    super.key,
    required this.produit,
    this.variante,
  });

  /// Ouvre le sheet. Si le produit a des variantes, intercale d'abord
  /// un picker pour choisir la variante à ajuster.
  static void open(BuildContext context, ProduitModel produit) {
    if (produit.hasVariantes) {
      Get.bottomSheet(
        _MouvementVariantePickerSheet(produit: produit),
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardTheme.color,
      );
      return;
    }
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

  /// Stock courant pertinent pour le mouvement : variante si présente,
  /// sinon stock total du produit.
  int get _stockCourant => widget.variante?.stock ?? widget.produit.quantiteStock;

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
        _qteCtrl.text = _stockCourant.toString();
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
      final v = widget.variante;
      await MouvementStockRepository().create(
        produitId: widget.produit.id,
        boutiqueId: widget.produit.boutiqueId,
        userId: userId,
        type: _type,
        quantite: qte,
        motif: _motifCtrl.text.trim().isEmpty
            ? null
            : _motifCtrl.text.trim(),
        varianteId: v?.id,
        varianteLibelle: v?.libelleAffichage,
      );
      Get.back();
      Get.snackbar(
        'Mouvement enregistré',
        v != null
            ? '${_type.label} sur ${widget.produit.nom} — ${v.libelleAffichage}'
            : '${_type.label} sur ${widget.produit.nom}',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        '$e',
        snackPosition: SnackPosition.TOP,
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
    final actuel = _stockCourant;
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
          // Get.bottomSheet décale déjà le sheet au-dessus du clavier ;
          // on ajoute juste viewPadding (home indicator iOS / barre Android).
          padding: EdgeInsets.fromLTRB(20, 20, 20, viewPadding + 20),
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
                            widget.variante != null
                                ? '${p.nom} — ${widget.variante!.libelleAffichage}'
                                : p.nom,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Stock actuel : $_stockCourant',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
    );
  }
}

// ============================================================================
// Picker variante côté mouvements stock : liste les variantes du produit et
// ouvre `MouvementSheet` avec celle choisie.
// ============================================================================

class _MouvementVariantePickerSheet extends StatelessWidget {
  final ProduitModel produit;
  const _MouvementVariantePickerSheet({required this.produit});

  @override
  Widget build(BuildContext context) {
    final repo = ProduitRepository();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: androidOnlySafeArea(
          Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.style_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Quelle variante ajuster ?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            produit.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<VarianteModel>>(
                  stream: repo.watchVariantes(produit.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? const <VarianteModel>[];
                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Ce produit n\'a aucune variante.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final v = list[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              v.libelle.isEmpty
                                  ? '?'
                                  : v.libelle.substring(
                                      0,
                                      v.libelle.length > 2
                                          ? 2
                                          : v.libelle.length),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(v.libelleAffichage),
                          subtitle: Text(
                            'Stock actuel : ${v.stock}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Get.bottomSheet(
                              MouvementSheet(
                                produit: produit,
                                variante: v,
                              ),
                              isScrollControlled: true,
                              backgroundColor:
                                  Theme.of(context).cardTheme.color,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

