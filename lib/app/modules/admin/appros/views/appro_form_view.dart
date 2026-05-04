import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/vente_model.dart' show ModePaiement;
import '../../../../theme/app_colors.dart';
import '../controllers/appro_form_controller.dart';

class ApproFormView extends GetView<ApproFormController> {
  const ApproFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final boutNom = controller.boutiqueNomCourante;
          return Column(
            children: [
              const Text('Nouvel approvisionnement',
                  style: TextStyle(fontSize: 14)),
              if (boutNom.isNotEmpty)
                Text(boutNom, style: const TextStyle(fontSize: 11)),
            ],
          );
        }),
        actions: [
          Obx(() => controller.lignes.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Vider',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: controller.clearLignes,
                )),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (controller.canPickBoutique) _BoutiquePicker(c: controller),
            _FournisseurPicker(c: controller),
            const SizedBox(height: 6),
            Expanded(
              child: Obx(() {
                if (controller.isLoadingProduits.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.lignes.isEmpty) {
                  return _EmptyLignes(
                    onAdd: () => _openProduitPicker(context),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: controller.lignes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _LigneTile(c: controller, index: i),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _openProduitPicker(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter un article'),
                      ),
                    ),
                  ],
                );
              }),
            ),
            _SummaryAndAction(c: controller),
          ],
        ),
      ),
    );
  }

  void _openProduitPicker(BuildContext context) {
    Get.bottomSheet(
      _ProduitPickerSheet(c: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

// ============================================================================
// Boutique picker (super-admin)
// ============================================================================

class _BoutiquePicker extends StatelessWidget {
  final ApproFormController c;
  const _BoutiquePicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Obx(() {
        final list = c.boutiques;
        if (list.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<String?>(
          initialValue: c.currentBoutiqueId.value,
          decoration: const InputDecoration(
            labelText: 'Boutique',
            prefixIcon: Icon(Icons.store_rounded),
            isDense: true,
          ),
          items: list
              .map((b) =>
                  DropdownMenuItem<String?>(value: b.id, child: Text(b.nom)))
              .toList(),
          onChanged: (v) => c.currentBoutiqueId.value = v,
        );
      }),
    );
  }
}

// ============================================================================
// Fournisseur picker (bottom sheet, pattern vente)
// ============================================================================

class _FournisseurPicker extends StatelessWidget {
  final ApproFormController c;
  const _FournisseurPicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openFournisseurPicker(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fournisseur *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Obx(() => Text(
                        c.fournisseurLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.fournisseurSelectionne == null
                              ? Colors.grey.shade500
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  Obx(() {
                    final f = c.fournisseurSelectionne;
                    if (f == null) return const SizedBox.shrink();
                    if (f.solde == 0) return const SizedBox.shrink();
                    final isDette = f.solde > 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        isDette
                            ? 'Dette en cours : ${Fmt.number(f.solde)}'
                            : 'Avance disponible : ${Fmt.number(-f.solde)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDette
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_right_rounded,
                color: AppColors.lightTextMuted),
          ],
        ),
      ),
    );
  }

  void _openFournisseurPicker(BuildContext context) {
    Get.bottomSheet(
      _FournisseurPickerSheet(controller: c),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

class _FournisseurPickerSheet extends StatefulWidget {
  final ApproFormController controller;
  const _FournisseurPickerSheet({required this.controller});

  @override
  State<_FournisseurPickerSheet> createState() =>
      _FournisseurPickerSheetState();
}

class _FournisseurPickerSheetState extends State<_FournisseurPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
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
                    const Expanded(
                      child: Text(
                        'Choisir un fournisseur',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un fournisseur (nom, téléphone)...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.controller.fournisseurs.where((f) {
                    if (q.isEmpty) return true;
                    return f.nom.toLowerCase().contains(q) ||
                        (f.telephone?.toLowerCase().contains(q) ?? false);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun fournisseur enregistré.\nCréez-en un d\'abord depuis le menu.'
                              : 'Aucun fournisseur ne correspond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final f = list[i];
                      final selected =
                          f.id == widget.controller.fournisseurId.value;
                      final hasDette = f.solde > 0;
                      final hasAvance = f.solde < 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            f.nom.isEmpty ? '?' : f.nom[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(f.nom),
                        subtitle: f.telephone == null
                            ? null
                            : Text(f.telephone!,
                                style: const TextStyle(fontSize: 12)),
                        trailing: hasDette
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  Fmt.number(f.solde),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              )
                            : hasAvance
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Avance ${Fmt.number(-f.solde)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  )
                                : selected
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary)
                                    : null,
                        onTap: () {
                          widget.controller.selectFournisseur(f.id);
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Bandeau « Avance fournisseur disponible » (intégré dans la section
// encaissement, n'apparaît que si le fournisseur a un solde négatif).
// ============================================================================

class _AvanceBanner extends StatelessWidget {
  final ApproFormController c;
  const _AvanceBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    final dispo = c.avanceDisponible;
    final utilisee = c.avanceUtilisee.value;
    final maxApp = c.avanceMaxApplicable;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              const Text(
                'Avance fournisseur',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.money(dispo, currency: c.devise),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (utilisee == 0)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed:
                        maxApp <= 0 ? null : () => c.appliquerAvanceMax(),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      'Utiliser ${Fmt.money(maxApp, currency: c.devise)}',
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: Text(
                    'Utilisée : ${Fmt.money(utilisee, currency: c.devise)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.grey.shade600,
                  ),
                  onPressed: () => c.retirerAvance(),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'Retirer',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================

class _EmptyLignes extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLignes({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aucun article dans cet appro',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cliquez sur le bouton ci-dessous pour ajouter un produit reçu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un article'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tile ligne d'appro
// ============================================================================

class _LigneTile extends StatelessWidget {
  final ApproFormController c;
  final int index;
  const _LigneTile({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (index >= c.lignes.length) return const SizedBox.shrink();
      final l = c.lignes[index];
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.produit.nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PA : ${Fmt.money(l.prixAchatUnitaire, currency: c.devise)}'
                    '  •  Sous-total : ${Fmt.money(l.sousTotal, currency: c.devise)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _QtyStepper(
              quantite: l.quantite,
              onMinus: () => c.decrementLigne(index),
              onPlus: () => c.incrementLigne(index),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.tune_rounded,
                  size: 18, color: Colors.grey.shade700),
              tooltip: 'Modifier PA',
              onPressed: () => _editPa(context, index, l.prixAchatUnitaire),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded,
                  size: 18, color: Colors.red.shade400),
              tooltip: 'Retirer',
              onPressed: () => c.removeLigne(index),
            ),
          ],
        ),
      );
    });
  }

  void _editPa(BuildContext context, int idx, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    Get.dialog(
      AlertDialog(
        title: const Text('Modifier le prix d\'achat unitaire'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'PA unitaire',
            suffixText: c.devise,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v =
                  double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              if (v > 0) c.setPrixAchatLigne(idx, v);
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantite;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    required this.quantite,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 16),
            onPressed: onMinus,
          ),
          Text(
            '$quantite',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 16),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sheet : sélection produit + saisie qté/PA
// ============================================================================

class _ProduitPickerSheet extends StatefulWidget {
  final ApproFormController c;
  const _ProduitPickerSheet({required this.c});

  @override
  State<_ProduitPickerSheet> createState() => _ProduitPickerSheetState();
}

class _ProduitPickerSheetState extends State<_ProduitPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
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
                    const Expanded(
                      child: Text(
                        'Choisir un produit',
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.c.produits.where((p) {
                    if (q.isEmpty) return true;
                    return p.nom.toLowerCase().contains(q);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun produit dans cette boutique.'
                              : 'Aucun produit ne correspond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final ligneExistante = widget.c.lignes
                          .firstWhereOrNull((l) => l.produit.id == p.id);
                      final dejaAjoute = ligneExistante != null;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (dejaAjoute
                                    ? AppColors.success
                                    : AppColors.primary)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            dejaAjoute
                                ? Icons.check_circle_rounded
                                : Icons.inventory_2_rounded,
                            color: dejaAjoute
                                ? AppColors.success
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(p.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'PA actuel : ${Fmt.money(p.prixAchat, currency: widget.c.devise)}'
                          '  •  Stock : ${p.quantiteStock}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: dejaAjoute
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Ajouté ×${ligneExistante.quantite}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          _openLigneSheet(context, p);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLigneSheet(BuildContext rootContext, ProduitModel produit) {
    Get.bottomSheet(
      _AjoutLigneSheet(c: widget.c, produit: produit),
      isScrollControlled: true,
      backgroundColor: Theme.of(rootContext).cardTheme.color,
    );
  }
}

class _AjoutLigneSheet extends StatefulWidget {
  final ApproFormController c;
  final ProduitModel produit;
  const _AjoutLigneSheet({required this.c, required this.produit});

  @override
  State<_AjoutLigneSheet> createState() => _AjoutLigneSheetState();
}

class _AjoutLigneSheetState extends State<_AjoutLigneSheet> {
  late final TextEditingController _qteCtrl;
  late final TextEditingController _paCtrl;
  int _quantite = 1;
  late double _pa;

  @override
  void initState() {
    super.initState();
    _qteCtrl = TextEditingController(text: '1');
    _pa = widget.produit.prixAchat > 0 ? widget.produit.prixAchat : 0;
    _paCtrl = TextEditingController(text: _pa == 0 ? '' : _pa.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _paCtrl.dispose();
    super.dispose();
  }

  void _setQuantite(int n) {
    setState(() {
      _quantite = n.clamp(1, 1 << 30);
      _qteCtrl.text = _quantite.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final devise = widget.c.devise;
    final sousTotal = _pa * _quantite;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, (viewInsets > 0 ? viewInsets : viewPadding) + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'PA actuel : ${Fmt.money(p.prixAchat, currency: devise)}'
                        '  •  Stock : ${p.quantiteStock}',
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
            const Text('Quantité reçue',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _QtyStepper(
                  quantite: _quantite,
                  onMinus: () => _setQuantite(_quantite - 1),
                  onPlus: () => _setQuantite(_quantite + 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qteCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '1',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v) ?? 1;
                      _setQuantite(n);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Prix d\'achat unitaire *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _paCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                prefixIcon:
                    const Icon(Icons.local_atm_outlined, size: 18),
                suffixText: devise,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _pa = n);
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Sous-total ligne',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    Fmt.money(sousTotal, currency: devise),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _pa <= 0
                  ? null
                  : () {
                      final ok = widget.c.addLigne(
                        produit: p,
                        quantite: _quantite,
                        prixAchatUnitaire: _pa,
                      );
                      if (ok) Get.back();
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ajouter à l\'appro'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Récap totaux + paiement + valider
// ============================================================================

// ============================================================================
// Barre du bas compacte : TOTAL + accès paiement (sheet) + Valider.
// Le détail (mode paiement, note, encaissement) est déporté dans un
// bottom sheet pour libérer de l'espace vertical à la liste d'articles.
// ============================================================================

class _SummaryAndAction extends StatelessWidget {
  final ApproFormController c;
  const _SummaryAndAction({required this.c});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ligne TOTAL + chip statut paiement + bouton Paiement (icône).
            Obx(() => Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Fmt.money(c.total, currency: c.devise),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _PaiementInfoChip(c: c),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Paiement & options',
                        onPressed: () => _PaiementSheet.open(context, c),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Obx(
              () => ElevatedButton.icon(
                onPressed: c.isSaving.value || c.lignes.isEmpty
                    ? null
                    : c.validerAppro,
                icon: c.isSaving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Valider l\'appro'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip statut paiement à droite du TOTAL : montre le mode courant ou
/// signal "Dette X" / "Trop versé X" si reste non nul. Cliquable.
class _PaiementInfoChip extends StatelessWidget {
  final ApproFormController c;
  const _PaiementInfoChip({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reste = c.resteAPayer;
      final hasDette = reste > 0;
      final hasOver = reste < 0;
      Color color;
      String label;
      if (hasDette) {
        color = AppColors.warning;
        label = 'Dette ${Fmt.money(reste, currency: c.devise)}';
      } else if (hasOver) {
        color = AppColors.success;
        label =
            'Trop versé ${Fmt.money(reste.abs(), currency: c.devise)}';
      } else {
        color = Colors.grey.shade700;
        label = c.modePaiement.value.label;
      }
      return InkWell(
        onTap: () => _PaiementSheet.open(context, c),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasDette
                    ? Icons.warning_amber_rounded
                    : (hasOver
                        ? Icons.check_circle_rounded
                        : Icons.payments_rounded),
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Sheet plein écran qui regroupe les options de paiement de l'appro
/// (note, mode paiement, encaissement avec avance + montant payé + reste).
class _PaiementSheet extends StatelessWidget {
  final ApproFormController c;
  const _PaiementSheet({required this.c});

  static void open(BuildContext context, ApproFormController c) {
    Get.bottomSheet(
      _PaiementSheet(c: c),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, (viewInsets > 0 ? viewInsets : viewPadding) + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Paiement & options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Récap totaux compact
              Obx(() => Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      children: [
                        _RowKv('Sous-total',
                            Fmt.money(c.sousTotal, currency: c.devise)),
                        if (c.remiseGlobale.value > 0) ...[
                          const SizedBox(height: 2),
                          _RowKv(
                            'Remise',
                            '-${Fmt.money(c.remiseGlobale.value, currency: c.devise)}',
                            color: AppColors.success,
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Divider(
                            height: 1,
                            color:
                                AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        _RowKv(
                          'TOTAL',
                          Fmt.money(c.total, currency: c.devise),
                          big: true,
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              // Note
              TextField(
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Note (optionnel)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  isDense: true,
                ),
                onChanged: (v) => c.note.value = v,
              ),
              const SizedBox(height: 12),
              Text(
                'Mode de paiement',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Obx(
                () => Wrap(
                  spacing: 6,
                  children: ModePaiement.values
                      .map((m) => ChoiceChip(
                            label: Text(m.label,
                                style: const TextStyle(fontSize: 11)),
                            selected: c.modePaiement.value == m,
                            onSelected: (_) => c.modePaiement.value = m,
                          ))
                      .toList(),
                ),
              ),
              // Section encaissement masquée tant qu'aucune ligne (total = 0,
              // bandeau avance sans effet à ce stade).
              Obx(() => c.lignes.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _EncaissementSection(c: c),
                    )),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section Encaissement : avance + montant payé + reste à payer/trop-versé
// ============================================================================

class _EncaissementSection extends StatefulWidget {
  final ApproFormController c;
  const _EncaissementSection({required this.c});

  @override
  State<_EncaissementSection> createState() => _EncaissementSectionState();
}

class _EncaissementSectionState extends State<_EncaissementSection> {
  late final TextEditingController _txt;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(
        text: _format(widget.c.montantPaye.value));
    // Quand le contrôleur ré-aligne montantPaye sur total (auto-sync),
    // on rafraîchit le champ texte sans perdre le curseur s'il est ouvert.
    _worker = ever(widget.c.montantPaye, (double v) {
      final newText = _format(v);
      if (_txt.text != newText) {
        _txt.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    });
  }

  String _format(double v) => v == 0 ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _worker?.dispose();
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      final reste = c.resteAPayer;
      final hasDette = reste > 0;
      final tropVerse = reste < 0;

      Color resteColor;
      String resteLabel;
      if (hasDette) {
        resteColor = AppColors.warning;
        resteLabel = 'Reste à payer (dette fournisseur)';
      } else if (tropVerse) {
        resteColor = AppColors.success;
        resteLabel = 'Trop-versé (avance créée chez fournisseur)';
      } else {
        resteColor = Colors.grey.shade600;
        resteLabel = 'Réglé intégralement';
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau Avance disponible (si applicable)
            if (c.avanceDisponible > 0) ...[
              _AvanceBanner(c: c),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Montant payé (cash)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => c.resetMontantPayeAuto(),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text(
                    'Tout payer',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _txt,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: c.devise,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                c.setMontantPaye(n);
              },
            ),
            const SizedBox(height: 10),
            if (c.avanceUtilisee.value > 0) ...[
              Row(
                children: [
                  const Icon(Icons.savings_rounded,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  const Text(
                    'Avance utilisée',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '-${Fmt.money(c.avanceUtilisee.value, currency: c.devise)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    resteLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: resteColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Fmt.money(reste.abs(), currency: c.devise),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: resteColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _RowKv extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? color;
  const _RowKv(this.label, this.value, {this.big = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 15 : 12.5,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 20 : 13.5,
            fontWeight: big ? FontWeight.w800 : FontWeight.w700,
            color: color ?? (big ? AppColors.primary : null),
            letterSpacing: big ? -0.3 : null,
          ),
        ),
      ],
    );
  }
}
