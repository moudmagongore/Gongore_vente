import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/categorie_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/categories_controller.dart';

class CategoriesListView extends GetView<CategoriesController> {
  const CategoriesListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Gestion catalogue : super-admin (sans restriction) ou admin de
    // boutique. Vendeur en lecture seule (pas de FAB ni d'actions tile).
    final canEdit = UserController.to.canManageCatalog;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher une catégorie...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: canEdit
          ? const AdminDrawer(currentRoute: AppRoutes.adminCategories)
          : const VendeurDrawer(currentRoute: AppRoutes.adminCategories),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Filtre boutique : visible uniquement pour le super-admin.
            Obx(() {
              if (!controller.isSuperAdmin ||
                  controller.boutiques.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BoutiqueFilterChip(
                    value: controller.filterBoutiqueId.value,
                    boutiques: controller.boutiques,
                    onChanged: (v) => controller.filterBoutiqueId.value = v,
                  ),
                ),
              );
            }),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _CategorieTile(categorie: list[i], canEdit: canEdit),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.adminCategorieForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle catégorie'),
            )
          : null,
    );
  }
}

class _CategorieTile extends StatelessWidget {
  final CategorieModel categorie;
  final bool canEdit;

  const _CategorieTile({required this.categorie, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CategoriesController>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit
            ? () => Get.toNamed(
                  AppRoutes.adminCategorieForm,
                  arguments: categorie,
                )
            : null,
        child: Obx(() {
          final stock = controller.stockDe(categorie.id);
          final color = _stockColor(context, stock);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categorie.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (controller.isSuperAdmin) ...[
                            const SizedBox(height: 6),
                            _BoutiqueBadge(
                              label:
                                  controller.boutiqueNom(categorie.boutiqueId),
                            ),
                          ],
                          if (categorie.description?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 6),
                            Text(
                              categorie.description!,
                              style: TextStyle(
                                color: AppColors.greyText(context, 600),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _StockChips(stock: stock),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StockPill(stock: stock, color: color),
                    if (canEdit)
                      _TileMenu(categorie: categorie, controller: controller)
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
              _StockHealthBar(stock: stock),
            ],
          );
        }),
      ),
    );
  }

  /// Couleur d'état : rouge si au moins une rupture, orange si stock bas,
  /// vert si tout est au-dessus du seuil, gris si la catégorie est vide.
  Color _stockColor(BuildContext context, CategorieStock stock) {
    if (stock.isEmpty) return AppColors.greyText(context, 500);
    if (stock.nbRupture > 0) return AppColors.danger;
    if (stock.nbBas > 0) return AppColors.warning;
    return AppColors.success;
  }
}

/// Pastille de droite : quantité totale en stock de la catégorie.
class _StockPill extends StatelessWidget {
  final CategorieStock stock;
  final Color color;
  const _StockPill({required this.stock, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.number(stock.quantite),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'en stock',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de puces sous le nom : nombre de produits + alertes éventuelles.
class _StockChips extends StatelessWidget {
  final CategorieStock stock;
  const _StockChips({required this.stock});

  @override
  Widget build(BuildContext context) {
    if (stock.isEmpty) {
      return _MiniChip(
        icon: Icons.inventory_2_outlined,
        label: 'Aucun produit',
        color: AppColors.greyText(context, 600),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MiniChip(
          icon: Icons.inventory_2_outlined,
          label: stock.nbProduits > 1
              ? '${stock.nbProduits} produits'
              : '1 produit',
          color: AppColors.greyText(context, 700),
        ),
        if (stock.nbRupture > 0)
          _MiniChip(
            icon: Icons.remove_shopping_cart_outlined,
            label: '${stock.nbRupture} en rupture',
            color: AppColors.danger,
          ),
        if (stock.nbBas > 0)
          _MiniChip(
            icon: Icons.trending_down_rounded,
            label: '${stock.nbBas} stock bas',
            color: AppColors.warning,
          ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liseré de santé du stock en pied de carte : proportion de produits
/// normaux / bas / en rupture. Masqué si la catégorie n'a aucun produit.
class _StockHealthBar extends StatelessWidget {
  final CategorieStock stock;
  const _StockHealthBar({required this.stock});

  @override
  Widget build(BuildContext context) {
    if (stock.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 3,
      child: Row(
        children: [
          if (stock.nbNormal > 0)
            Expanded(
              flex: stock.nbNormal,
              child: const ColoredBox(color: AppColors.success),
            ),
          if (stock.nbBas > 0)
            Expanded(
              flex: stock.nbBas,
              child: const ColoredBox(color: AppColors.warning),
            ),
          if (stock.nbRupture > 0)
            Expanded(
              flex: stock.nbRupture,
              child: const ColoredBox(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

/// Menu d'actions compact — remplace les deux IconButtons pour laisser la
/// place à la pastille de stock.
class _TileMenu extends StatelessWidget {
  final CategorieModel categorie;
  final CategoriesController controller;
  const _TileMenu({required this.categorie, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: AppColors.greyText(context, 600),
      ),
      tooltip: 'Actions',
      onSelected: (v) {
        if (v == 'edit') {
          Get.toNamed(AppRoutes.adminCategorieForm, arguments: categorie);
        } else if (v == 'delete') {
          controller.confirmDelete(categorie);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}

class _BoutiqueBadge extends StatelessWidget {
  final String label;
  const _BoutiqueBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_rounded,
            size: 12,
            color: AppColors.primary(context),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary(context),
            ),
          ),
        ],
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
                  : Icons.category_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucune catégorie ne correspond.'
                  : 'Aucune catégorie pour l\'instant.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Exemples : Boissons, Alimentaire, Cosmétiques...',
                style: TextStyle(
                  color: AppColors.greyText(context, 500),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip de filtre boutique pour super-admin. Click → bottom sheet de
/// sélection avec option "Toutes les boutiques".
class _BoutiqueFilterChip extends StatelessWidget {
  final String? value;
  final List<dynamic> boutiques;
  final void Function(String?) onChanged;
  const _BoutiqueFilterChip({
    required this.value,
    required this.boutiques,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = boutiques.firstWhereOrNull((b) => b.id == value);
    final label = selected?.nom ?? 'Toutes boutiques';
    return InputChip(
      avatar: Icon(
        Icons.store_rounded,
        size: 16,
        color: value != null
            ? AppColors.primary(context)
            : AppColors.greyText(context, 600),
      ),
      label: Text(label,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis),
      selected: value != null,
      showCheckmark: false,
      onPressed: () => _open(context),
      onDeleted: value == null ? null : () => onChanged(null),
      deleteIconColor: AppColors.greyText(context, 700),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.all_inclusive_rounded,
                color: value == null ? AppColors.primary(ctx) : null,
              ),
              title: Text(
                'Toutes les boutiques',
                style: TextStyle(
                  fontWeight:
                      value == null ? FontWeight.w700 : FontWeight.w500,
                  color: value == null ? AppColors.primary(ctx) : null,
                ),
              ),
              trailing: value == null
                  ? Icon(Icons.check_rounded, color: AppColors.primary(ctx))
                  : null,
              onTap: () {
                Navigator.of(ctx).pop();
                onChanged(null);
              },
            ),
            const Divider(height: 1),
            ...boutiques.map((b) {
              final isActive = b.id == value;
              return ListTile(
                leading: Icon(
                  Icons.store_rounded,
                  color: isActive ? AppColors.primary(ctx) : null,
                ),
                title: Text(
                  b.nom,
                  style: TextStyle(
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.primary(ctx) : null,
                  ),
                ),
                trailing: isActive
                    ? Icon(Icons.check_rounded,
                        color: AppColors.primary(ctx))
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onChanged(b.id);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
