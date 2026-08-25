import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/client_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../reglements/widgets/reglement_sheet.dart';
import '../controllers/clients_controller.dart';

class ClientsListView extends GetView<ClientsController> {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
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
          ? const AdminDrawer(currentRoute: AppRoutes.adminClients)
          : const VendeurDrawer(currentRoute: AppRoutes.adminClients),
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
                itemBuilder: (_, i) => _ClientTile(client: list[i]),
              );
            }),
          ),
        ],
        ),
      ),
      // FAB ouvert au super-admin (sans restriction) ou au gestionnaire.
      // Obx → réactif au cumul admin+gestionnaire toggle en live.
      floatingActionButton: Obx(
        () => UserController.to.canPerformSales
            ? FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.adminClientForm),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nouveau client'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ClientsController controller;
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
                  icon: Icons.people_alt_rounded,
                  value: controller.total.toString(),
                  label: 'Clients',
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  value: Fmt.number(controller.detteTotale),
                  label: 'Crédits en cours',
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
        border: Border.all(color: AppColors.borderOf(context), width: 1),
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

class _Filters extends StatelessWidget {
  final ClientsController controller;
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
            // Filtre boutique : visible uniquement pour le super-admin
            // (admin/vendeur sont déjà scopés sur leur boutique active).
            if (controller.isSuperAdmin && controller.boutiques.isNotEmpty)
              _BoutiqueFilterChip(
                value: controller.filterBoutiqueId.value,
                boutiques: controller.boutiques,
                onChanged: (v) => controller.filterBoutiqueId.value = v,
              ),
            FilterChip(
              avatar: Icon(
                controller.onlyAvecDette.value
                    ? Icons.warning_amber_rounded
                    : Icons.warning_amber_outlined,
                size: 16,
                color: controller.onlyAvecDette.value
                    ? AppColors.warning
                    : AppColors.greyText(context, 600),
              ),
              label: const Text('Avec crédit',
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
                  fontWeight: value == null
                      ? FontWeight.w700
                      : FontWeight.w500,
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
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
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

class _ClientTile extends StatelessWidget {
  final ClientModel client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ClientsController>();
    final hasDette = client.solde > 0;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminClientDetail,
          arguments: client,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary(context).withValues(alpha: 0.12),
                radius: 22,
                child: Text(
                  client.nom.isEmpty ? '?' : client.nom[0].toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary(context),
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
                      client.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (client.telephone?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 12, color: AppColors.greyText(context, 500)),
                          const SizedBox(width: 4),
                          Text(
                            client.telephone!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.greyText(context, 700),
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
                          color: AppColors.primary(context).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          controller.boutiqueNom(client.boutiqueId),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary(context),
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
                    Fmt.number(client.solde),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: hasDette
                          ? AppColors.warning
                          : AppColors.greyText(context, 500),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    hasDette ? 'à recevoir' : 'à jour',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.greyText(context, 600),
                    ),
                  ),
                ],
              ),
              // Menu d'actions (encaisser / éditer / supprimer) réservé au
              // vendeur. admin/super-admin sont en lecture seule.
              // Obx → réagit au cumul admin+gestionnaire en direct.
              Obx(
                () => UserController.to.canPerformSales
                    ? PopupMenuButton<String>(
                        tooltip: 'Plus',
                        icon: Icon(Icons.more_vert_rounded,
                            color: AppColors.greyText(context, 600), size: 20),
                        onSelected: (v) {
                          switch (v) {
                            case 'encaisser':
                              ReglementSheet.open(context, client);
                              break;
                            case 'edit':
                              Get.toNamed(AppRoutes.adminClientForm,
                                  arguments: client);
                              break;
                            case 'delete':
                              controller.confirmDelete(client);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'encaisser',
                            child: ListTile(
                              leading: Icon(Icons.payments_rounded,
                                  color: AppColors.success),
                              title: Text('Encaisser'),
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
                  : Icons.people_outline_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun client ne correspond.'
                  : 'Aucun client pour l\'instant.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 6),
              Text(
                'Ajoutez vos clients pour suivre leurs achats et leurs crédits.',
                style:
                    TextStyle(color: AppColors.greyText(context, 500), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
