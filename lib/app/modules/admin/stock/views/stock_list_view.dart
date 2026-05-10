import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/variante_model.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/stock_controller.dart';
import '../widgets/mouvement_sheet.dart';

class StockListView extends GetView<StockController> {
  const StockListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Modification du stock manuel (mouvements) : super-admin (sans
    // restriction) ou admin de boutique. Le gestionnaire est en lecture
    // seule (consultation uniquement, pas d'action).
    final canEdit = UserController.to.canManageCatalog;
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
      body: androidOnlySafeArea(
        Column(
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
                  itemBuilder: (_, i) => _ProduitStockTile(
                    produit: list[i],
                    canEdit: canEdit,
                  ),
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
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warehouse_rounded,
                        color: AppColors.primary(context), size: 20),
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
                            color: AppColors.greyText(context, 700),
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
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary(context),
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'GNF',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary(context)
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
                      color: AppColors.primary(context),
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
        border: Border.all(color: AppColors.borderOf(context)),
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
                    color: AppColors.greyText(context, 700),
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
        border: Border.all(color: AppColors.borderOf(context)),
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

class _ProduitStockTile extends StatefulWidget {
  final ProduitModel produit;
  final bool canEdit;
  const _ProduitStockTile({
    required this.produit,
    required this.canEdit,
  });

  @override
  State<_ProduitStockTile> createState() => _ProduitStockTileState();
}

class _ProduitStockTileState extends State<_ProduitStockTile> {
  bool _showVariantes = false;

  ProduitModel get produit => widget.produit;
  bool get canEdit => widget.canEdit;

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
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress:
                canEdit ? () => MouvementSheet.open(context, produit) : null,
            onTap:
                canEdit ? () => MouvementSheet.open(context, produit) : null,
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
                          size: 11, color: AppColors.greyText(context, 500)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyText(context, 600),
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
                        color: AppColors.greyText(context, 600),
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
                          fontSize: 10, color: AppColors.greyText(context, 500)),
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
                'unité(s)',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.greyText(context, 600),
                ),
              ),
              SizedBox(height: 2),
              Text(
                Fmt.money(produit.valeurStock, currency: devise),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText(context, 700),
                ),
              ),
            ],
          ),
        ],
              ),
            ),
          ),
          // Pied cliquable + panneau variantes (uniquement si le produit
          // a des variantes ; lazy-loadé via stream à l'expansion).
          if (produit.hasVariantes) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () =>
                  setState(() => _showVariantes = !_showVariantes),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.style_rounded,
                      size: 14,
                      color: AppColors.primary(context).withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Voir variantes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary(context),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showVariantes
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary(context),
                    ),
                  ],
                ),
              ),
            ),
            if (_showVariantes) _StockVariantesPanel(produit: produit),
          ],
        ],
      ),
    );
  }
}

/// Panneau qui charge en live les variantes d'un produit et les affiche
/// sous forme de chips compactes (libellé + stock + couleur seuil).
class _StockVariantesPanel extends StatelessWidget {
  final ProduitModel produit;
  const _StockVariantesPanel({required this.produit});

  @override
  Widget build(BuildContext context) {
    final repo = ProduitRepository();
    return StreamBuilder<List<VarianteModel>>(
      stream: repo.watchVariantes(produit.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              height: 16,
              width: 16,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final variantes = snap.data ?? const <VarianteModel>[];
        if (variantes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Aucune variante.',
              style: TextStyle(fontSize: 12, color: AppColors.greyText(context, 600)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: variantes.map((v) {
              final low = v.stock <= produit.seuilAlerte;
              final color = v.stock <= 0
                  ? Colors.red
                  : (low ? AppColors.warning : AppColors.success);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.libelleAffichage,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ': ${v.stock}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
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
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
