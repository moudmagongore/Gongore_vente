import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/variante_model.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/produits_controller.dart';

class ProduitsListView extends GetView<ProduitsController> {
  const ProduitsListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Gestion catalogue réservée à l'ADMIN de boutique. super-admin et
    // vendeur sont en lecture seule (pas de FAB ni d'actions sur les tiles).
    final canEdit = UserController.to.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (nom, description)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: canEdit
          ? const AdminDrawer(currentRoute: AppRoutes.adminProduits)
          : const VendeurDrawer(currentRoute: AppRoutes.adminProduits),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          const SizedBox(height: 12),
          _Filters(controller: controller),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filtered;
              if (list.isEmpty) {
                return _Empty(hasSearch: controller.search.value.isNotEmpty);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ProduitTile(produit: list[i], canEdit: canEdit),
              );
            }),
          ),
        ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.adminProduitForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau produit'),
            )
          : null,
    );
  }
}

class _Filters extends StatelessWidget {
  final ProduitsController controller;
  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (controller.boutiques.isNotEmpty)
                _DropdownChip(
                  hint: 'Toutes boutiques',
                  value: controller.filterBoutiqueId.value,
                  items: [
                    const _DropOpt(null, 'Toutes boutiques'),
                    ...controller.boutiques.map((b) => _DropOpt(b.id, b.nom)),
                  ],
                  onChanged: (v) => controller.filterBoutiqueId.value = v,
                ),
              const SizedBox(width: 8),
              if (controller.categories.isNotEmpty)
                _DropdownChip(
                  hint: 'Toutes catégories',
                  value: controller.filterCategorieId.value,
                  items: [
                    const _DropOpt(null, 'Toutes catégories'),
                    ...controller.categories.map(
                      (c) => _DropOpt(c.id, c.nom),
                    ),
                  ],
                  onChanged: (v) => controller.filterCategorieId.value = v,
                ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Actifs uniquement',
                    style: TextStyle(fontSize: 12)),
                selected: controller.onlyActive.value,
                onSelected: (v) => controller.onlyActive.value = v,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropOpt {
  final String? id;
  final String label;
  const _DropOpt(this.id, this.label);
}

class _DropdownChip extends StatelessWidget {
  final String hint;
  final String? value;
  final List<_DropOpt> items;
  final ValueChanged<String?> onChanged;

  const _DropdownChip({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<String?>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        hint: Text(hint, style: const TextStyle(fontSize: 12)),
        items: items
            .map(
              (o) => DropdownMenuItem<String?>(
                value: o.id,
                child: Text(o.label, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ProduitTile extends StatefulWidget {
  final ProduitModel produit;
  final bool canEdit;
  const _ProduitTile({required this.produit, required this.canEdit});

  @override
  State<_ProduitTile> createState() => _ProduitTileState();
}

class _ProduitTileState extends State<_ProduitTile> {
  bool _showVariantes = false;

  ProduitModel get produit => widget.produit;
  bool get canEdit => widget.canEdit;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProduitsController>();
    final cat = controller.categorieNom(produit.categorieId);
    final devise = controller.deviseDe(produit.boutiqueId);

    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: canEdit
                ? () => Get.toNamed(
                      AppRoutes.adminProduitForm,
                      arguments: produit,
                    )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
            children: [
              _ProductIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            produit.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!produit.active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INACTIF',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_rounded,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    controller
                                        .boutiqueNom(produit.boutiqueId),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Catégorie : ligne dédiée juste au-dessus du prix.
                    if (cat != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.category_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              cat,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  Fmt.money(produit.prixVente,
                                      currency: devise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (produit.prixAchat > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${Fmt.money(produit.marge, currency: devise)}',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        Get.toNamed(AppRoutes.adminProduitForm,
                            arguments: produit);
                        break;
                      case 'toggle':
                        controller.toggleActive(produit);
                        break;
                      case 'delete':
                        controller.confirmDelete(produit);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Modifier'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(produit.active
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined),
                        title:
                            Text(produit.active ? 'Désactiver' : 'Activer'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading:
                            Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Supprimer',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
          // Footer cliquable + panneau variantes (uniquement si le produit
          // a des variantes ; lazy-loadé via stream à l'expansion).
          if (produit.hasVariantes) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () =>
                  setState(() => _showVariantes = !_showVariantes),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.style_rounded,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Variantes (stock total : ${produit.quantiteStock})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showVariantes
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showVariantes)
              _VariantesPanel(produit: produit),
          ],
        ],
      ),
    );
  }
}

/// Panneau qui charge en live les variantes d'un produit et les affiche
/// sous forme de chips compactes (libellé + stock + état seuil).
class _VariantesPanel extends StatelessWidget {
  final ProduitModel produit;
  const _VariantesPanel({required this.produit});

  @override
  Widget build(BuildContext context) {
    final repo = ProduitRepository();
    return StreamBuilder<List<VarianteModel>>(
      stream: repo.watchVariantes(produit.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              height: 16,
              width: 16,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final variantes = snap.data ?? const <VarianteModel>[];
        if (variantes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Aucune variante.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: variantes.map((v) {
              final low = v.stock <= produit.seuilAlerte;
              final color = v.stock <= 0
                  ? Colors.red
                  : (low ? AppColors.warning : AppColors.success);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.libelleAffichage,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ': ${v.stock}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ProductIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_rounded,
        color: AppColors.primary,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasSearch;
  const _Empty({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun produit ne correspond.'
                  : 'Aucun produit pour l\'instant.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
