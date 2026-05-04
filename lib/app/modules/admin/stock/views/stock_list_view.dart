import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/stock_controller.dart';
import '../widgets/mouvement_sheet.dart';

class StockListView extends GetView<StockController> {
  const StockListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            tooltip: 'Historique des mouvements',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Get.toNamed(AppRoutes.adminStockHistorique),
          ),
        ],
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
      ),
      drawer: UserController.to.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminStock)
          : const VendeurDrawer(currentRoute: AppRoutes.adminStock),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _StatsRow(c: controller),
            const SizedBox(height: 12),
            _FilterChips(c: controller),
            const SizedBox(height: 4),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _Empty(
                      hasSearch: controller.search.value.isNotEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ProduitStockTile(produit: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Stats : valeur stock + ruptures + stock bas
// ============================================================================

class _StatsRow extends StatelessWidget {
  final StockController c;
  const _StatsRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => Column(
          children: [
            // Hero : valeur du stock
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warehouse_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Valeur du stock (PA)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                Fmt.number(c.valeurStock),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'GNF',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Marge potentielle : ${Fmt.number(c.margePotentielle)} GNF',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.margePotentielle >= 0
                                ? AppColors.success
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.warning_amber_rounded,
                      value: '${c.nbRuptures}',
                      label: 'Ruptures',
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.trending_down_rounded,
                      value: '${c.nbStockBas}',
                      label: 'Stock bas',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.inventory_2_rounded,
                      value: '${c.nbProduits}',
                      label: 'Produits',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
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

// ============================================================================
// Filtres rapides (chips état)
// ============================================================================

class _FilterChips extends StatelessWidget {
  final StockController c;
  const _FilterChips({required this.c});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final etat in StockFiltreEtat.values) ...[
                ChoiceChip(
                  label: Text(c.etatLabel(etat),
                      style: const TextStyle(fontSize: 12)),
                  selected: c.filterEtat.value == etat,
                  onSelected: (_) => c.filterEtat.value = etat,
                ),
                const SizedBox(width: 8),
              ],
              if (c.categories.isNotEmpty) ...[
                const SizedBox(width: 4),
                _CategorieDropdown(c: c),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorieDropdown extends StatelessWidget {
  final StockController c;
  const _CategorieDropdown({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Obx(() => DropdownButton<String?>(
            value: c.filterCategorieId.value,
            underline: const SizedBox.shrink(),
            isDense: true,
            hint: const Text('Catégorie',
                style: TextStyle(fontSize: 12)),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes catégories',
                    style: TextStyle(fontSize: 12)),
              ),
              ...c.categories.map(
                (cat) => DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.nom,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            onChanged: (v) => c.filterCategorieId.value = v,
          )),
    );
  }
}

// ============================================================================
// Tile : un produit dans la liste stock
// ============================================================================

class _ProduitStockTile extends StatelessWidget {
  final ProduitModel produit;
  const _ProduitStockTile({required this.produit});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<StockController>();
    final etat = c.etatProduit(produit);
    final color = c.etatColor(etat);
    final devise = c.deviseDe(produit.boutiqueId);
    final cat = c.categorieNom(produit.categorieId);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => MouvementSheet.open(context, produit),
        onTap: () => MouvementSheet.open(context, produit),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
        children: [
          // Indicateur d'état (barre verticale colorée)
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        produit.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!produit.active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'INACTIF',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (cat != null) ...[
                      Icon(Icons.category_outlined,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'PA ${Fmt.money(produit.prixAchat, currency: devise)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.etatLabel(etat),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Seuil ${produit.seuilAlerte}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${produit.quantiteStock}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                produit.unite ?? 'unité(s)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Fmt.money(produit.valeurStock, currency: devise),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
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

// ============================================================================
// Empty state
// ============================================================================

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
                  : Icons.warehouse_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun produit ne correspond.'
                  : 'Aucun produit.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
