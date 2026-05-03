import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/admin_drawer.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/boutiques_controller.dart';

class BoutiquesListView extends GetView<BoutiquesController> {
  const BoutiquesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isSuperAdmin ? 'Boutiques' : 'Ma boutique'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher une boutique...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminBoutiques),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _FilterBar(controller: controller),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _EmptyState(hasSearch: controller.search.value.isNotEmpty);
                }
                return RefreshIndicator(
                  onRefresh: () async => Future.delayed(
                    const Duration(milliseconds: 300),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BoutiqueTile(boutique: list[i]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: controller.isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.adminBoutiqueForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle boutique'),
            )
          : null,
    );
  }
}

class _FilterBar extends StatelessWidget {
  final BoutiquesController controller;

  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(() {
        final f = controller.filterActive.value;
        return Row(
          children: [
            _Chip(
              label: 'Toutes (${controller.totalCount})',
              selected: f == null,
              onTap: () => controller.setFilter(null),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Actives (${controller.activeCount})',
              selected: f == true,
              onTap: () => controller.setFilter(true),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Inactives',
              selected: f == false,
              onTap: () => controller.setFilter(false),
            ),
          ],
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BoutiqueTile extends StatelessWidget {
  final BoutiqueModel boutique;

  const _BoutiqueTile({required this.boutique});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BoutiquesController>();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminBoutiqueForm,
          arguments: boutique,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            boutique.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!boutique.active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'INACTIVE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (boutique.adresse?.isNotEmpty ?? false)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              boutique.adresse!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (boutique.telephone?.isNotEmpty ?? false)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            boutique.telephone!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Get.toNamed(
                        AppRoutes.adminBoutiqueForm,
                        arguments: boutique,
                      );
                      break;
                    case 'toggle':
                      controller.toggleActive(boutique);
                      break;
                    case 'delete':
                      controller.confirmDelete(boutique);
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
                  if (controller.isSuperAdmin)
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(
                          boutique.active
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                        ),
                        title: Text(
                          boutique.active ? 'Désactiver' : 'Activer',
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (controller.isSuperAdmin) const PopupMenuDivider(),
                  if (controller.isSuperAdmin)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        title: Text(
                          'Supprimer',
                          style: TextStyle(color: Colors.red),
                        ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

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
                  : Icons.store_mall_directory_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucune boutique ne correspond à votre recherche'
                  : 'Aucune boutique pour l\'instant',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Appuyez sur « Nouvelle boutique » pour commencer.',
                textAlign: TextAlign.center,
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
