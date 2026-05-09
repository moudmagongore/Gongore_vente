import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/subscription_badge_card.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/abonnements_controller.dart';

class AbonnementsListView extends GetView<AbonnementsController> {
  const AbonnementsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnements'),
        actions: [
          IconButton(
            tooltip: 'Paramètres tarifs',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Get.toNamed(AppRoutes.adminAbonnementParams),
          ),
        ],
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
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminAbonnements),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _StatsBar(controller: controller),
            _FilterBar(controller: controller),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = controller.filtered;
                if (list.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _BoutiqueAbonnementTile(boutique: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.adminAbonnementForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Enregistrer paiement'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatsBar extends StatelessWidget {
  final AbonnementsController controller;
  const _StatsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Actives',
                value: '${controller.totalActives}',
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Expirées',
                value: '${controller.totalExpirees}',
                color: AppColors.danger,
                icon: Icons.error_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Sans abo.',
                value: '${controller.totalSansAbonnement}',
                color: AppColors.warning,
                icon: Icons.help_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.greyText(context, 700),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final AbonnementsController controller;
  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Obx(() {
        final f = controller.filter.value;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'Toutes',
                selected: f == AbonnementFilter.toutes,
                onTap: () => controller.filter.value = AbonnementFilter.toutes,
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Actives',
                selected: f == AbonnementFilter.actives,
                onTap: () => controller.filter.value = AbonnementFilter.actives,
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Expirées',
                selected: f == AbonnementFilter.expirees,
                onTap: () =>
                    controller.filter.value = AbonnementFilter.expirees,
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Sans abonnement',
                selected: f == AbonnementFilter.sansAbonnement,
                onTap: () => controller.filter.value =
                    AbonnementFilter.sansAbonnement,
              ),
            ],
          ),
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
    final primary = AppColors.primary(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : AppColors.borderOf(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.greyText(context, 700),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BoutiqueAbonnementTile extends StatelessWidget {
  final BoutiqueModel boutique;
  const _BoutiqueAbonnementTile({required this.boutique});

  @override
  Widget build(BuildContext context) {
    final status = SubscriptionStatus.from(boutique.subscriptionEndsAt);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminAbonnementForm,
          arguments: boutique,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(status.icon, color: status.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boutique.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// Statut d'abonnement extrait dans `core/widgets/subscription_badge_card.dart`
// (classe publique `SubscriptionStatus`) pour être partagé entre la liste
// super-admin et le badge sur le dashboard admin.

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppColors.greyText(context, 500)),
          const SizedBox(height: 12),
          Text(
            'Aucune boutique à afficher',
            style: TextStyle(color: AppColors.greyText(context, 600)),
          ),
        ],
      ),
    );
  }
}
