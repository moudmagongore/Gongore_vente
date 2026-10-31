import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/caisse_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/caisses_controller.dart';

/// Liste des caisses d'une boutique.
///
/// Même écran pour deux usages, parce que le contenu est le même et que
/// deux vues auraient divergé : l'admin paramètre (création, menu
/// d'actions), le gestionnaire consulte les soldes de ses caisses.
class CaissesListView extends GetView<CaissesController> {
  const CaissesListView({super.key});

  @override
  Widget build(BuildContext context) {
    final canManage = controller.canManage;
    return Scaffold(
      appBar: AppBar(
        title: Text(canManage ? 'Caisses' : 'Mes caisses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher une caisse...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: canManage
          ? const AdminDrawer(currentRoute: AppRoutes.adminCaisses)
          : const VendeurDrawer(currentRoute: AppRoutes.adminCaisses),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const _TotalBanner(),
            if (canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
                        label: const Text('Désactivées',
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
                // Les noms de boutique et de gestionnaire sont résolus dans
                // `itemBuilder`, hors du scope de cet Obx : on s'abonne
                // explicitement ici.
                controller.boutiques.length;
                controller.users.length;
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _Empty(
                    hasSearch: controller.search.value.isNotEmpty,
                    canManage: canManage,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CaisseTile(caisse: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.adminCaisseForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle caisse'),
            )
          : null,
    );
  }
}

/// Total des caisses visibles (RG-31, version liste).
class _TotalBanner extends StatelessWidget {
  const _TotalBanner();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CaissesController>();
    return Obx(() {
      if (c.isLoading.value || c.filtered.isEmpty) {
        return const SizedBox(height: 8);
      }
      final total = c.soldeTotal;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_rounded,
                color: AppColors.primary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total en caisse',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.greyText(context, 700),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.money(total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: total < 0
                          ? AppColors.danger
                          : AppColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${c.filtered.length} caisse(s)',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.greyText(context, 700),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _CaisseTile extends StatelessWidget {
  final CaisseModel caisse;
  const _CaisseTile({required this.caisse});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CaissesController>();
    final actif = caisse.active;
    final color = actif ? AppColors.primary(context) : AppColors.warning;
    final noms = c.canManage ? c.gestionnaireNoms(caisse) : const <String>[];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: c.canManage
            ? () => Get.toNamed(AppRoutes.adminCaisseForm, arguments: caisse)
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 14, c.canManage ? 8 : 14, 14),
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
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caisse.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: actif ? null : AppColors.greyText(context, 600),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.money(caisse.solde),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: caisse.solde < 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (c.isSuperAdmin)
                          _MiniChip(
                            icon: Icons.store_rounded,
                            label: c.boutiqueNom(caisse.boutiqueId),
                            color: AppColors.primary(context),
                          ),
                        if (!actif)
                          const _MiniChip(
                            icon: Icons.visibility_off_outlined,
                            label: 'Désactivée',
                            color: AppColors.warning,
                          ),
                        if (caisse.autoriseNegatif)
                          const _MiniChip(
                            icon: Icons.trending_down_rounded,
                            label: 'Négatif autorisé',
                            color: AppColors.warning,
                          ),
                        if (c.canManage)
                          _MiniChip(
                            icon: noms.isEmpty
                                ? Icons.admin_panel_settings_outlined
                                : Icons.people_outline_rounded,
                            label: noms.isEmpty
                                ? 'Admins uniquement'
                                : noms.join(', '),
                            color: noms.isEmpty
                                ? AppColors.greyText(context, 600)
                                : AppColors.primary(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.canManage)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.greyText(context, 600),
                  ),
                  tooltip: 'Actions',
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        Get.toNamed(AppRoutes.adminCaisseForm,
                            arguments: caisse);
                        break;
                      case 'toggle':
                        c.toggleActive(caisse);
                        break;
                      case 'delete':
                        c.confirmDelete(caisse);
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
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasSearch;
  final bool canManage;
  const _Empty({required this.hasSearch, required this.canManage});

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
                  : Icons.account_balance_wallet_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucune caisse ne correspond.'
                  : canManage
                      ? 'Aucune caisse pour l\'instant.'
                      : 'Aucune caisse ne vous est accessible.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                canManage
                    ? 'Créez vos comptes de trésorerie : tiroir espèces, '
                        'Orange Money, banque... Les opérations continuent '
                        'de fonctionner sans caisse en attendant.'
                    : 'Votre administrateur doit vous donner accès à une '
                        'caisse.',
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
