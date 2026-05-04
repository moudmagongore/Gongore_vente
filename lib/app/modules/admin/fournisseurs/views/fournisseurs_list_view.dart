import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/fournisseurs_controller.dart';
import '../widgets/reglement_fournisseur_sheet.dart';

class FournisseursListView extends GetView<FournisseursController> {
  const FournisseursListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (nom, téléphone, email)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: UserController.to.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminFournisseurs)
          : const VendeurDrawer(currentRoute: AppRoutes.adminFournisseurs),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _StatsRow(controller: controller),
            const SizedBox(height: 10),
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
                      _FournisseurTile(fournisseur: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
      // FAB réservé au vendeur (création = opération métier).
      // Obx → réagit au cumul admin+gestionnaire en direct.
      floatingActionButton: Obx(
        () => UserController.to.isVendeur
            ? FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.adminFournisseurForm),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Nouveau fournisseur'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final FournisseursController controller;
  const _StatsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_shipping_rounded,
                  value: controller.total.toString(),
                  label: 'Fournisseurs',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  value: Fmt.number(controller.detteTotale),
                  label: 'Dette en cours',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
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

class _Filters extends StatelessWidget {
  final FournisseursController controller;
  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              avatar: Icon(
                controller.onlyAvecDette.value
                    ? Icons.warning_amber_rounded
                    : Icons.warning_amber_outlined,
                size: 16,
                color: controller.onlyAvecDette.value
                    ? AppColors.warning
                    : Colors.grey.shade600,
              ),
              label: const Text('Avec dette',
                  style: TextStyle(fontSize: 12)),
              selected: controller.onlyAvecDette.value,
              onSelected: (v) => controller.onlyAvecDette.value = v,
            ),
          ],
        ),
      ),
    );
  }
}

class _FournisseurTile extends StatelessWidget {
  final FournisseurModel fournisseur;
  const _FournisseurTile({required this.fournisseur});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FournisseursController>();
    final hasDette = fournisseur.solde > 0;
    final hasAvance = fournisseur.solde < 0;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminFournisseurDetail,
          arguments: fournisseur,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                radius: 22,
                child: Text(
                  fournisseur.nom.isEmpty
                      ? '?'
                      : fournisseur.nom[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fournisseur.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fournisseur.telephone?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            fournisseur.telephone!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (controller.isSuperAdmin) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          controller.boutiqueNom(fournisseur.boutiqueId),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.number(fournisseur.solde.abs()),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: hasDette
                          ? AppColors.warning
                          : (hasAvance
                              ? AppColors.success
                              : Colors.grey.shade500),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    hasDette
                        ? 'à payer'
                        : (hasAvance ? 'avance' : 'à jour'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              // Menu d'actions (verser / éditer / supprimer) réservé au
              // vendeur. admin/super-admin sont en lecture seule.
              // Obx → réagit au cumul admin+gestionnaire en direct.
              Obx(
                () => UserController.to.isVendeur
                    ? PopupMenuButton<String>(
                        tooltip: 'Plus',
                        icon: Icon(Icons.more_vert_rounded,
                            color: Colors.grey.shade600, size: 20),
                        onSelected: (v) {
                          switch (v) {
                            case 'verser':
                              ReglementFournisseurSheet.open(
                                  context, fournisseur);
                              break;
                            case 'edit':
                              Get.toNamed(AppRoutes.adminFournisseurForm,
                                  arguments: fournisseur);
                              break;
                            case 'delete':
                              controller.confirmDelete(fournisseur);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'verser',
                            child: ListTile(
                              leading: Icon(Icons.payments_rounded,
                                  color: AppColors.primary),
                              title: Text('Verser règlement'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Modifier'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline,
                                  color: Colors.red),
                              title: Text('Supprimer',
                                  style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
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
                  : Icons.local_shipping_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun fournisseur ne correspond.'
                  : 'Aucun fournisseur pour l\'instant.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 6),
              Text(
                'Ajoutez vos fournisseurs pour suivre vos achats et vos '
                'dettes à payer.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
