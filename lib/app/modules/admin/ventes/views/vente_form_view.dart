import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/vente_form_controller.dart';

class VenteFormView extends GetView<VenteFormController> {
  const VenteFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle vente'),
        actions: [
          Obx(() => controller.lignes.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Vider',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context),
                )),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
        if (controller.boutiques.isEmpty) {
          return _NoBoutique();
        }
        return Column(
          children: [
            _ClientBar(controller: controller),
            const Divider(height: 1),
            Expanded(child: _LignesSection(controller: controller)),
            const Divider(height: 1),
            _SummaryAndAction(controller: controller),
          ],
        );
      }),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Vider la vente ?'),
        content: const Text('Tous les articles seront retirés.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              controller.clearLignes();
              Get.back();
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Section : barre client en haut
// ============================================================================

class _ClientBar extends StatelessWidget {
  final VenteFormController controller;
  const _ClientBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openClientPicker(context),
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
              child: Obx(() => Icon(
                    controller.isClientDivers
                        ? Icons.person_outline_rounded
                        : Icons.person_rounded,
                    color: AppColors.primary,
                    size: 22,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Client',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Obx(() => Text(
                        controller.clientLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  Obx(() {
                    final c = controller.clientSelectionne;
                    if (c == null) return const SizedBox.shrink();
                    if (c.solde <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Crédit en cours : ${Fmt.number(c.solde)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
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

  void _openClientPicker(BuildContext context) {
    Get.bottomSheet(
      _ClientPickerSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final VenteFormController controller;
  const _ClientPickerSheet({required this.controller});

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _libreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _libreCtrl.text = widget.controller.clientNomLibre.value;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _libreCtrl.dispose();
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
                        'Choisir un client',
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
              // Section client divers
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client de passage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _libreCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nom libre (ex. M. Camara au comptant)',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: TextButton(
                          onPressed: () {
                            widget.controller
                                .setClientNomLibre(_libreCtrl.text);
                            Get.back();
                          },
                          child: const Text('Valider'),
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (v) {
                        widget.controller.setClientNomLibre(v);
                        Get.back();
                      },
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        widget.controller.resetClient();
                        Get.back();
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text(
                        'Aucun client (Client divers anonyme)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client (nom, téléphone)...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.controller.clients.where((c) {
                    if (q.isEmpty) return true;
                    return c.nom.toLowerCase().contains(q) ||
                        (c.telephone?.toLowerCase().contains(q) ?? false);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun client enregistré.\nUtilisez « Client de passage » au-dessus.'
                              : 'Aucun client ne correspond.',
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
                      final c = list[i];
                      final selected = c.id == widget.controller.clientId.value;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            c.nom.isEmpty ? '?' : c.nom[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(c.nom),
                        subtitle: c.telephone == null
                            ? null
                            : Text(c.telephone!,
                                style: const TextStyle(fontSize: 12)),
                        trailing: c.solde > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  Fmt.number(c.solde),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              )
                            : selected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary)
                                : null,
                        onTap: () {
                          widget.controller.selectClient(c.id);
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Section : liste des lignes ajoutées
// ============================================================================

class _LignesSection extends StatelessWidget {
  final VenteFormController controller;
  const _LignesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.lignes.isEmpty) {
        return _EmptyLignes(onAdd: () => _openProduitPicker(context));
      }
      return Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: controller.lignes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _LigneTile(controller: controller, index: i),
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
    });
  }

  void _openProduitPicker(BuildContext context) {
    Get.bottomSheet(
      _ProduitPickerSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

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
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aucun article dans la vente',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cliquez sur le bouton ci-dessous pour ajouter un produit.',
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

class _LigneTile extends StatelessWidget {
  final VenteFormController controller;
  final int index;
  const _LigneTile({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (index >= controller.lignes.length) return const SizedBox.shrink();
      final l = controller.lignes[index];
      final devise = controller.devise;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.produit.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.money(l.prixUnitaire, currency: devise)} l\'unité',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.money(l.sousTotal, currency: devise),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (l.remise > 0)
                      Text(
                        '-${Fmt.money(l.remise, currency: devise)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey.shade500),
                  onPressed: () => controller.removeLigne(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _QtyStepper(
                  quantite: l.quantite,
                  onMinus: () => controller.decrementLigne(index),
                  onPlus: () => controller.incrementLigne(index),
                ),
                const Spacer(),
                _RemiseChip(
                  active: l.remise > 0,
                  onTap: () => _showRemiseDialog(context, index, l.sousTotalBrut),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showRemiseDialog(BuildContext context, int index, double max) {
    final montantCtrl = TextEditingController();
    final pourcentCtrl = TextEditingController();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    Get.bottomSheet(
      SafeArea(
        top: false,
        bottom: false,
        child: Container(
          color: Theme.of(context).cardTheme.color,
          padding: EdgeInsets.fromLTRB(
              16, 20, 16,
              (viewInsets > 0 ? viewInsets : viewPadding) + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Remise sur la ligne',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Sous-total brut : ${Fmt.number(max)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montantCtrl,
                decoration: InputDecoration(
                  labelText: 'Montant fixe (${controller.devise})',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pourcentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pourcentage (%)',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.setRemiseLigne(index, 0);
                        Get.back();
                      },
                      child: const Text('Retirer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final m = double.tryParse(
                            montantCtrl.text.replaceAll(',', '.'));
                        final p = double.tryParse(
                            pourcentCtrl.text.replaceAll(',', '.'));
                        if (m != null) {
                          controller.setRemiseLigne(index, m);
                        } else if (p != null) {
                          controller.setRemiseLignePourcent(index, p);
                        }
                        Get.back();
                      },
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIconBtn(icon: Icons.remove_rounded, onTap: onMinus),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$quantite',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
          ),
          _StepIconBtn(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _RemiseChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _RemiseChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : Colors.grey.shade600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.success.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? AppColors.success.withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.local_offer_rounded : Icons.local_offer_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'Remise appliquée' : 'Remise',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section : sélection produit (modal)
// ============================================================================

class _ProduitPickerSheet extends StatefulWidget {
  final VenteFormController controller;
  const _ProduitPickerSheet({required this.controller});

  @override
  State<_ProduitPickerSheet> createState() => _ProduitPickerSheetState();
}

class _ProduitPickerSheetState extends State<_ProduitPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _filterCategorieId = '';

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
                        'Choisir un article',
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (nom, code-barre)...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 38,
                child: Obx(() {
                  if (widget.controller.categories.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _CatPill(
                          label: 'Tout',
                          selected: _filterCategorieId.isEmpty,
                          onTap: () => setState(() => _filterCategorieId = ''),
                        ),
                        for (final c in widget.controller.categories) ...[
                          const SizedBox(width: 8),
                          _CatPill(
                            label: c.nom,
                            selected: _filterCategorieId == c.id,
                            onTap: () =>
                                setState(() => _filterCategorieId = c.id),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (widget.controller.isLoadingProduits.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.controller.produits.where((p) {
                    if (_filterCategorieId.isNotEmpty &&
                        p.categorieId != _filterCategorieId) {
                      return false;
                    }
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
                      final isOut = p.quantiteStock <= 0;
                      return ListTile(
                        enabled: !isOut,
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
                          Fmt.money(p.prixVente,
                              currency: widget.controller.devise),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isOut ? Colors.red : AppColors.success)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut ? 'Rupture' : 'Stock ${p.quantiteStock}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isOut ? Colors.red : AppColors.success,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openAjoutLigneDialog(context, p);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAjoutLigneDialog(BuildContext rootContext, ProduitModel produit) {
    Get.bottomSheet(
      _AjoutLigneSheet(
        controller: widget.controller,
        produit: produit,
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(rootContext).cardTheme.color,
    );
  }
}

class _CatPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.primary : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : AppColors.lightText),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section : ajout d'une ligne (qty + remise après sélection produit)
// ============================================================================

class _AjoutLigneSheet extends StatefulWidget {
  final VenteFormController controller;
  final ProduitModel produit;
  const _AjoutLigneSheet({
    required this.controller,
    required this.produit,
  });

  @override
  State<_AjoutLigneSheet> createState() => _AjoutLigneSheetState();
}

class _AjoutLigneSheetState extends State<_AjoutLigneSheet> {
  late final TextEditingController _qteCtrl;
  late final TextEditingController _remiseCtrl;
  int _quantite = 1;
  double _remise = 0;

  @override
  void initState() {
    super.initState();
    _qteCtrl = TextEditingController(text: '1');
    _remiseCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _remiseCtrl.dispose();
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
    final devise = widget.controller.devise;
    // Stock dispo en live (basé sur le stream produits du controller).
    final dispo = widget.controller.stockDispoUi(p.id) ?? p.quantiteStock;
    final sousTotalBrut = p.prixVente * _quantite;
    final sousTotal = sousTotalBrut - _remise;

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
            // Drag handle
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
            // Header produit
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
                        '${Fmt.money(p.prixVente, currency: devise)} l\'unité',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (dispo <= 0 ? Colors.red : AppColors.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dispo <= 0 ? 'Rupture' : 'Dispo $dispo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dispo <= 0 ? Colors.red : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Quantité
            const Text(
              'Quantité',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QtyStepper(
                  quantite: _quantite,
                  onMinus: () => _setQuantite(_quantite - 1),
                  onPlus: () {
                    if (_quantite >= dispo) return;
                    _setQuantite(_quantite + 1);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qteCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '1',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v) ?? 1;
                      _setQuantite(n > dispo ? dispo : n);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Remise
            const Text(
              'Remise (optionnelle)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remiseCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                suffixText: devise,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() {
                  _remise = n.clamp(0, sousTotalBrut).toDouble();
                });
              },
            ),
            const SizedBox(height: 18),
            // Récap sous-total
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    'Sous-total ligne',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
              onPressed: dispo <= 0
                  ? null
                  : () {
                      final ok = widget.controller.addLigne(
                        produit: p,
                        quantite: _quantite,
                        remise: _remise,
                      );
                      if (ok) Get.back();
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ajouter à la vente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section : récap totaux + mode paiement + valider
// ============================================================================

class _SummaryAndAction extends StatelessWidget {
  final VenteFormController controller;
  const _SummaryAndAction({required this.controller});

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
            _NoteField(controller: controller),
            const SizedBox(height: 10),
            // Mode paiement
            Text(
              'Mode de paiement',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(() {
                  final current = controller.modePaiement.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < ModePaiement.values.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _CatPill(
                          label: ModePaiement.values[i].label,
                          selected: current == ModePaiement.values[i],
                          onTap: () => controller.modePaiement.value =
                              ModePaiement.values[i],
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            // Totaux
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
                      _Row(
                        label: 'Sous-total',
                        value: Fmt.money(controller.sousTotal,
                            currency: controller.devise),
                      ),
                      if (controller.remiseGlobale.value > 0) ...[
                        const SizedBox(height: 2),
                        _Row(
                          label: 'Remise globale',
                          value:
                              '-${Fmt.money(controller.remiseGlobale.value, currency: controller.devise)}',
                          color: AppColors.success,
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Divider(
                          height: 1,
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      _Row(
                        label: 'TOTAL',
                        value: Fmt.money(controller.total,
                            currency: controller.devise),
                        big: true,
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            _EncaissementSection(controller: controller),
            const SizedBox(height: 12),
            Obx(() => ElevatedButton.icon(
                  onPressed: controller.isSaving.value ||
                          controller.lignes.isEmpty
                      ? null
                      : controller.validerVente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    controller.isSaving.value
                        ? 'Validation...'
                        : 'Valider la vente',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  final VenteFormController controller;
  const _NoteField({required this.controller});

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _txt;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(text: widget.controller.note.value);
    _expanded = _txt.text.isNotEmpty;
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: Colors.grey.shade700,
          ),
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.notes_rounded, size: 16),
          label: const Text(
            'Ajouter une note',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    return TextField(
      controller: _txt,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Note (optionnel)',
        prefixIcon: const Icon(Icons.notes_rounded, size: 18),
        suffixIcon: IconButton(
          tooltip: 'Masquer',
          icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: () {
            _txt.clear();
            widget.controller.note.value = '';
            setState(() => _expanded = false);
          },
        ),
        isDense: true,
      ),
      onChanged: (v) => widget.controller.note.value = v,
    );
  }
}

class _EncaissementSection extends StatefulWidget {
  final VenteFormController controller;
  const _EncaissementSection({required this.controller});

  @override
  State<_EncaissementSection> createState() => _EncaissementSectionState();
}

class _EncaissementSectionState extends State<_EncaissementSection> {
  late final TextEditingController _txt;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(text: _format(widget.controller.montantPaye.value));
    // Quand le contrôleur ré-aligne montantPaye sur total (auto-sync),
    // on rafraîchit le champ texte sans perdre le curseur s'il est ouvert.
    _worker = ever(widget.controller.montantPaye, (double v) {
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
    final c = widget.controller;
    return Obx(() {
      final reste = c.resteAPayer;
      final hasCredit = reste > 0;
      final hasOverpay = reste < 0;
      final clientDivers = c.isClientDivers;
      final blockingCredit = hasCredit && clientDivers;

      Color resteColor;
      String resteLabel;
      if (hasCredit) {
        resteColor = AppColors.warning;
        resteLabel = 'Reste à payer';
      } else if (hasOverpay) {
        resteColor = AppColors.success;
        resteLabel = 'Trop-perçu (déduit du solde)';
      } else {
        resteColor = Colors.grey.shade600;
        resteLabel = 'Réglé intégralement';
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: blockingCredit
              ? AppColors.warning.withValues(alpha: 0.06)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: blockingCredit
                ? AppColors.warning.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau Avance disponible (si applicable)
            if (c.avanceDisponible > 0) ...[
              _AvanceBanner(controller: c),
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
                  const Icon(Icons.account_balance_wallet_rounded,
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
                Text(
                  resteLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: resteColor,
                  ),
                ),
                const Spacer(),
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
            if (blockingCredit) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sélectionnez un client identifié pour enregistrer ce crédit, '
                      'ou complétez le paiement.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (hasCredit && c.clientSelectionne != null) ...[
              const SizedBox(height: 6),
              Text(
                'Sera ajouté au solde de ${c.clientSelectionne!.nom}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else if (hasOverpay && c.clientSelectionne != null) ...[
              const SizedBox(height: 6),
              Text(
                'Sera déduit du solde de ${c.clientSelectionne!.nom}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool big;
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.big = false,
  });

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

// ============================================================================
// État vide quand aucune boutique
// ============================================================================

/// Bandeau « Avance disponible » affiché dans la section Encaissement
/// quand le client a un solde négatif (avance). Permet de l'appliquer en
/// 1 clic ou de la saisir manuellement via le champ.
class _AvanceBanner extends StatelessWidget {
  final VenteFormController controller;
  const _AvanceBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final dispo = controller.avanceDisponible;
    final utilisee = controller.avanceUtilisee.value;
    final maxApp = controller.avanceMaxApplicable;

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
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              const Text(
                'Avance disponible',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.money(dispo, currency: controller.devise),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: maxApp <= 0
                        ? null
                        : () => controller.appliquerAvanceMax(),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      'Utiliser ${Fmt.money(maxApp, currency: controller.devise)}',
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: Text(
                    'Utilisée : ${Fmt.money(utilisee, currency: controller.devise)}',
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
                  onPressed: () => controller.retirerAvance(),
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

class _NoBoutique extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucune boutique disponible.\nCréez d\'abord une boutique active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
