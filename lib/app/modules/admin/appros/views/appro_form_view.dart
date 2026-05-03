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
            _AvanceBanner(c: controller),
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
// Fournisseur picker
// ============================================================================

class _FournisseurPicker extends StatelessWidget {
  final ApproFormController c;
  const _FournisseurPicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Obx(() {
        final list = c.fournisseurs;
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Aucun fournisseur. Créez-en un d\'abord depuis le menu.',
              style: TextStyle(fontSize: 12),
            ),
          );
        }
        final safe =
            list.any((f) => f.id == c.fournisseurId.value)
                ? c.fournisseurId.value
                : null;
        return DropdownButtonFormField<String?>(
          initialValue: safe,
          decoration: const InputDecoration(
            labelText: 'Fournisseur *',
            prefixIcon: Icon(Icons.local_shipping_rounded),
            isDense: true,
          ),
          isExpanded: true,
          items: list
              .map((f) => DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(f.nom,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => c.selectFournisseur(v),
        );
      }),
    );
  }
}

// ============================================================================
// Avance fournisseur disponible
// ============================================================================

class _AvanceBanner extends StatelessWidget {
  final ApproFormController c;
  const _AvanceBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dispo = c.avanceDisponible;
      if (dispo <= 0) return const SizedBox.shrink();
      final used = c.avanceUtilisee.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.savings_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  used > 0
                      ? 'Avance utilisée : ${Fmt.money(used, currency: c.devise)}'
                      : 'Avance disponible : ${Fmt.money(dispo, currency: c.devise)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
              if (used > 0)
                TextButton(
                  onPressed: c.retirerAvance,
                  child: const Text('Retirer'),
                )
              else
                TextButton(
                  onPressed: c.appliquerAvanceMax,
                  child: Text(
                      'Utiliser ${Fmt.money(c.avanceMaxApplicable, currency: c.devise)}'),
                ),
            ],
          ),
        ),
      );
    });
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
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        title: Text(p.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'PA actuel : ${Fmt.money(p.prixAchat, currency: widget.c.devise)}'
                          '  •  Stock : ${p.quantiteStock}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
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

class _SummaryAndAction extends StatelessWidget {
  final ApproFormController c;
  const _SummaryAndAction({required this.c});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 10),
            // Mode paiement
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
            const SizedBox(height: 8),
            // Totaux
            Obx(() {
              final reste = c.resteAPayer;
              final hasCredit = reste > 0;
              final tropVerse = reste < 0;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _RowKv('Sous-total',
                        Fmt.money(c.sousTotal, currency: c.devise)),
                    if (c.remiseGlobale.value > 0)
                      _RowKv(
                        'Remise',
                        '-${Fmt.money(c.remiseGlobale.value, currency: c.devise)}',
                        color: AppColors.success,
                      ),
                    const Divider(height: 14),
                    _RowKv(
                      'TOTAL',
                      Fmt.money(c.total, currency: c.devise),
                      big: true,
                    ),
                    const SizedBox(height: 6),
                    _MontantPayeRow(c: c),
                    if (c.avanceUtilisee.value > 0)
                      _RowKv('Avance utilisée',
                          Fmt.money(c.avanceUtilisee.value,
                              currency: c.devise),
                          color: AppColors.success),
                    if (hasCredit)
                      _RowKv(
                        'Reste à payer',
                        '${Fmt.money(reste, currency: c.devise)} (dette)',
                        color: AppColors.warning,
                      )
                    else if (tropVerse)
                      _RowKv(
                        'Trop-versé',
                        Fmt.money(reste.abs(), currency: c.devise),
                        color: AppColors.success,
                      ),
                  ],
                ),
              );
            }),
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
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MontantPayeRow extends StatefulWidget {
  final ApproFormController c;
  const _MontantPayeRow({required this.c});

  @override
  State<_MontantPayeRow> createState() => _MontantPayeRowState();
}

class _MontantPayeRowState extends State<_MontantPayeRow> {
  final _ctrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_editing) {
        return InkWell(
          onTap: () {
            setState(() {
              _editing = true;
              _ctrl.text = widget.c.montantPaye.value.toStringAsFixed(0);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  'Payé (cash)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Text(
                  Fmt.money(widget.c.montantPaye.value,
                      currency: widget.c.devise),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined,
                    size: 13, color: Colors.grey.shade600),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Payé (cash)',
                ),
                onSubmitted: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  widget.c.setMontantPaye(n);
                  setState(() => _editing = false);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Auto (= total)',
              onPressed: () {
                widget.c.resetMontantPayeAuto();
                setState(() => _editing = false);
              },
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {
                final n =
                    double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
                widget.c.setMontantPaye(n);
                setState(() => _editing = false);
              },
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: big ? 14 : 12,
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 18 : 13,
              fontWeight: big ? FontWeight.w800 : FontWeight.w700,
              color: color ?? (big ? AppColors.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
