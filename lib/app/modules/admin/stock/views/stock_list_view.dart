import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/stock_controller.dart';

class StockListView extends GetView<StockController> {
  const StockListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Historique',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Get.toNamed(
              AppRoutes.adminMouvementsHistorique,
              arguments: controller.currentBoutiqueId.value,
            ),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminStock),
      body: Column(
        children: [
          _BoutiqueSelector(controller: controller),
          _AlertsBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.boutiques.isEmpty) {
                return const _NoBoutique();
              }
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.lines;
              if (list.isEmpty) {
                return _Empty(hasSearch: controller.search.value.isNotEmpty);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _StockTile(line: list[i]),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(controller: controller),
    );
  }
}

class _BoutiqueSelector extends StatelessWidget {
  final StockController controller;
  const _BoutiqueSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Obx(() {
        if (controller.boutiques.isEmpty) {
          return const SizedBox.shrink();
        }
        // Admin de boutique : juste afficher le nom de sa boutique
        if (!controller.isSuperAdmin) {
          final b = controller.boutiques.firstWhereOrNull(
              (x) => x.id == controller.currentBoutiqueId.value);
          if (b == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.store_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: controller.currentBoutiqueId.value,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  items: controller.boutiques
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(b.nom),
                        ),
                      )
                      .toList(),
                  onChanged: controller.selectBoutique,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _AlertsBar extends StatelessWidget {
  final StockController controller;
  const _AlertsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _AlertCard(
                color: Colors.red,
                icon: Icons.cancel_rounded,
                value: controller.nbOut.toString(),
                label: 'Rupture',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AlertCard(
                color: Colors.orange,
                icon: Icons.warning_amber_rounded,
                value: controller.nbLow.toString(),
                label: 'Stock faible',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.onlyLow.toggle(),
                child: _AlertCard(
                  color: controller.onlyLow.value
                      ? AppColors.primary
                      : Colors.grey.shade400,
                  icon: controller.onlyLow.value
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                  value: controller.onlyLow.value ? 'ON' : 'OFF',
                  label: 'Filtre faible',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;

  const _AlertCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final StockLine line;
  const _StockTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StockController>();
    final p = line.produit;
    final color = line.isOut
        ? Colors.red
        : line.isLow
            ? Colors.orange
            : AppColors.success;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminMouvementForm,
          arguments: {
            'type': MouvementType.entree,
            'boutiqueId': controller.currentBoutiqueId.value,
            'produitId': p.id,
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  line.isOut
                      ? Icons.remove_shopping_cart_rounded
                      : line.isLow
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seuil d\'alerte : ${p.seuilAlerte} ${p.unite ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (line.derniereModif != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Modifié ${Fmt.dateTime(line.derniereModif!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    line.quantite.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (p.unite != null)
                    Text(
                      p.unite!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
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

class SpeedDial extends StatelessWidget {
  final StockController controller;
  const SpeedDial({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showOptions(context),
      icon: const Icon(Icons.swap_vert_rounded),
      label: const Text('Mouvement'),
    );
  }

  void _showOptions(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          color: Theme.of(Get.context!).cardTheme.color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.south_rounded,
                    color: AppColors.success),
                title: const Text('Entrée de stock'),
                subtitle: const Text('Réapprovisionnement'),
                onTap: () {
                  Get.back();
                  Get.toNamed(
                    AppRoutes.adminMouvementForm,
                    arguments: {
                      'type': MouvementType.entree,
                      'boutiqueId': controller.currentBoutiqueId.value,
                    },
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.north_rounded, color: Colors.orange),
                title: const Text('Sortie / Perte / Casse'),
                subtitle: const Text('Sortie hors vente'),
                onTap: () {
                  Get.back();
                  Get.toNamed(
                    AppRoutes.adminMouvementForm,
                    arguments: {
                      'type': MouvementType.sortie,
                      'boutiqueId': controller.currentBoutiqueId.value,
                    },
                  );
                },
              ),
              if (controller.isSuperAdmin)
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded,
                      color: AppColors.primary),
                  title: const Text('Transfert entre boutiques'),
                  subtitle: const Text('Atomique'),
                  onTap: () {
                    Get.back();
                    Get.toNamed(
                      AppRoutes.adminMouvementForm,
                      arguments: {
                        'type': MouvementType.transfert,
                        'boutiqueId': controller.currentBoutiqueId.value,
                      },
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.tune_rounded,
                    color: AppColors.secondary),
                title: const Text('Ajustement d\'inventaire'),
                subtitle: const Text('Forcer une quantité avec motif'),
                onTap: () {
                  Get.back();
                  Get.toNamed(
                    AppRoutes.adminMouvementForm,
                    arguments: {
                      'type': MouvementType.ajustement,
                      'boutiqueId': controller.currentBoutiqueId.value,
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoBoutique extends StatelessWidget {
  const _NoBoutique();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Créez d\'abord une boutique\nactive avant de gérer le stock.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
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
                  : Icons.inventory_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun produit ne correspond.'
                  : 'Aucun produit dans cette boutique.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
