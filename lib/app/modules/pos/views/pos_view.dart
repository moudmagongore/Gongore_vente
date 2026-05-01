import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/user_controller.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/admin_drawer.dart';
import '../../../core/widgets/vendeur_drawer.dart';
import '../../../data/models/produit_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/pos_controller.dart';
import 'cart_sheet.dart';

class PosView extends GetView<PosController> {
  const PosView({super.key});

  @override
  Widget build(BuildContext context) {
    final isAnyAdmin = UserController.to.isAnyAdmin;
    return Scaffold(
      drawer: isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminPos)
          : const VendeurDrawer(currentRoute: AppRoutes.vendeurPos),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Caisse'),
        actions: [
          if (controller.canPickBoutique)
            PopupMenuButton<String>(
              icon: const Icon(Icons.store_rounded),
              tooltip: 'Changer de boutique',
              onSelected: (id) => controller.currentBoutiqueId.value = id,
              itemBuilder: (_) => controller.boutiques
                  .map(
                    (b) => PopupMenuItem(
                      value: b.id,
                      child: Row(
                        children: [
                          Icon(
                            b.id == controller.currentBoutiqueId.value
                                ? Icons.check_circle
                                : Icons.store_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(b.nom),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Obx(() {
            // Tracking explicite : .length sur RxList + .value sur Rxn
            controller.boutiques.length;
            final id = controller.currentBoutiqueId.value;
            final name = controller.boutiques
                    .firstWhereOrNull((b) => b.id == id)
                    ?.nom ??
                '';
            if (name.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                name,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            );
          }),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _SearchBar(controller: controller),
              _CategoriesBar(controller: controller),
              Expanded(
                child: Obx(() {
                  if (controller.boutiques.isEmpty) {
                    return const _NoBoutique();
                  }
                  if (controller.isLoadingProduits.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = controller.filtredProduits;
                  if (products.isEmpty) {
                    return _Empty(hasSearch: controller.search.value.isNotEmpty);
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _ProductCard(
                        produit: products[i], controller: controller),
                  );
                }),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCartBar(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final PosController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Rechercher (nom, code-barre)...',
          prefixIcon: Icon(Icons.search_rounded),
          isDense: true,
        ),
        onChanged: (v) => controller.search.value = v,
      ),
    );
  }
}

class _CategoriesBar extends StatelessWidget {
  final PosController controller;
  const _CategoriesBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.categories.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CatChip(
                label: 'Tout',
                selected: controller.filterCategorieId.value == null,
                onTap: () => controller.filterCategorieId.value = null,
              ),
              const SizedBox(width: 8),
              ...controller.categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CatChip(
                      label: c.nom,
                      selected: controller.filterCategorieId.value == c.id,
                      onTap: () => controller.filterCategorieId.value = c.id,
                    ),
                  )),
            ],
          ),
        ),
      );
    });
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedText =
        isDark ? Colors.grey.shade300 : AppColors.lightText;
    final unselectedBorder = Theme.of(context).dividerColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.primary : unselectedBorder,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : unselectedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProduitModel produit;
  final PosController controller;
  const _ProductCard({required this.produit, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stock = controller.stockOf(produit.id);
      final isOut = stock <= 0;
      final isLow = stock <= produit.seuilAlerte && stock > 0;

      return InkWell(
        onTap: isOut ? null : () => controller.addToCart(produit),
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: const _ImagePlaceholder(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produit.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: Fmt.money(produit.prixVente,
                                    currency: controller.devise),
                              ),
                              if ((produit.unite ?? '').isNotEmpty)
                                TextSpan(
                                  text: ' / ${produit.unite}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOut || isLow ? Colors.red : AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOut ? 'RUPTURE' : 'Stock $stock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!isOut)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Sac de courses au centre, légèrement bas
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ),
          // Petit tag de prix en haut à droite, pour l'aspect "produit"
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCartBar extends StatelessWidget {
  final PosController controller;
  const _BottomCartBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.cart.isEmpty) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.bottomSheet(
                const CartSheet(),
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.shopping_cart_rounded,
                              color: Colors.white),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 20, minHeight: 20),
                              child: Text(
                                '${controller.nbArticles}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${controller.cart.length} produit(s)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            Fmt.money(controller.total,
                                currency: controller.devise),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
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
              'Aucune boutique disponible.\nCréez d\'abord une boutique active.',
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
                  : Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun produit ne correspond.'
                  : 'Aucun produit dans cette boutique.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
