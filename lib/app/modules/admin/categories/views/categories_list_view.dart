import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canEdit
            ? () => Get.toNamed(
                  AppRoutes.adminCategorieForm,
                  arguments: categorie,
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                      Obx(() => _BoutiqueBadge(
                            label: controller.boutiqueNom(categorie.boutiqueId),
                          )),
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
                  ],
                ),
              ),
              if (canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Get.toNamed(
                    AppRoutes.adminCategorieForm,
                    arguments: categorie,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => controller.confirmDelete(categorie),
                ),
              ],
            ],
          ),
        ),
      ),
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
