import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/admin_drawer.dart';
import '../../../../data/models/nature_depense_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/natures_depense_controller.dart';

/// Référentiel des natures de dépense d'une boutique. Écran réservé à
/// l'admin (et au super-admin) : c'est lui qui décide des postes de
/// dépense que les gestionnaires pourront utiliser.
class NaturesDepenseListView extends GetView<NaturesDepenseController> {
  const NaturesDepenseListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natures de dépense'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher une nature...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminNaturesDepense),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Obx(
                () => Row(
                  children: [
                    if (controller.isSuperAdmin &&
                        controller.boutiques.isNotEmpty) ...[
                      Flexible(
                        child: _BoutiqueFilterChip(
                          value: controller.filterBoutiqueId.value,
                          boutiques: controller.boutiques,
                          onChanged: (v) =>
                              controller.filterBoutiqueId.value = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilterChip(
                      label: const Text('Inactives',
                          style: TextStyle(fontSize: 12)),
                      avatar: Icon(
                        Icons.visibility_off_outlined,
                        size: 14,
                        color: controller.inclureInactives.value
                            ? AppColors.warning
                            : AppColors.greyText(context, 600),
                      ),
                      selected: controller.inclureInactives.value,
                      showCheckmark: false,
                      onSelected: (v) =>
                          controller.inclureInactives.value = v,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Le nom de boutique est résolu dans `itemBuilder`, hors du
                // scope de cet Obx : on s'abonne explicitement ici.
                controller.boutiques.length;
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _Empty(hasSearch: controller.search.value.isNotEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _NatureTile(nature: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.adminNatureDepenseForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle nature'),
      ),
    );
  }
}

class _NatureTile extends StatelessWidget {
  final NatureDepenseModel nature;
  const _NatureTile({required this.nature});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<NaturesDepenseController>();
    final actif = nature.active;
    final color = actif ? AppColors.primary(context) : AppColors.warning;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.toNamed(
          AppRoutes.adminNatureDepenseForm,
          arguments: nature,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nature.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: actif
                            ? null
                            : AppColors.greyText(context, 600),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (c.isSuperAdmin)
                          _MiniChip(
                            icon: Icons.store_rounded,
                            label: c.boutiqueNom(nature.boutiqueId),
                            color: AppColors.primary(context),
                          ),
                        if (!actif)
                          const _MiniChip(
                            icon: Icons.visibility_off_outlined,
                            label: 'Inactive',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    if (nature.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        nature.description!,
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
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.greyText(context, 600),
                ),
                tooltip: 'Actions',
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      Get.toNamed(
                        AppRoutes.adminNatureDepenseForm,
                        arguments: nature,
                      );
                      break;
                    case 'toggle':
                      c.toggleActive(nature);
                      break;
                    case 'delete':
                      c.confirmDelete(nature);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(actif
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      title: Text(actif ? 'Désactiver' : 'Réactiver'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
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
                  : Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucune nature ne correspond.'
                  : 'Aucune nature de dépense pour l\'instant.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Exemples : Loyer, Électricité, Transport, Salaires...',
                style: TextStyle(
                  color: AppColors.greyText(context, 500),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip de filtre boutique pour super-admin.
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
                  fontWeight: value == null ? FontWeight.w700 : FontWeight.w500,
                  color: value == null ? AppColors.primary(ctx) : null,
                ),
              ),
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
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.primary(ctx) : null,
                  ),
                ),
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
