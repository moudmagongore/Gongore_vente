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
    // Gestion catalogue réservée à l'ADMIN de boutique. super-admin et
    // vendeur sont en lecture seule (pas de FAB ni d'actions sur les tiles).
    final canEdit = UserController.to.isAdmin;
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
                          color: Colors.grey.shade600,
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
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.store_rounded,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
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
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Exemples : Boissons, Alimentaire, Cosmétiques...',
                style: TextStyle(
                  color: Colors.grey.shade500,
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
