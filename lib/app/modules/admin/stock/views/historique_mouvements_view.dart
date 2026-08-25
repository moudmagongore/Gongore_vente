import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/mouvement_stock_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/historique_mouvements_controller.dart';

class HistoriqueMouvementsView
    extends GetView<HistoriqueMouvementsController> {
  const HistoriqueMouvementsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des mouvements'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (produit, motif, user)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _PeriodeBar(c: controller),
            const SizedBox(height: 12),
            _StatsRow(c: controller),
            const SizedBox(height: 6),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = controller.filtered;
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun mouvement sur cette période.',
                            style: TextStyle(color: AppColors.greyText(context, 600)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _MouvementTile(m: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    Get.bottomSheet(
      wrapBottomSheet(
        context,
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                // Filtre boutique : visible uniquement pour le super-admin.
                // Obligatoire (les mouvements sont scopés par boutique).
                if (controller.isSuperAdmin) ...[
                  const Text('Boutique', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Obx(
                    () => DropdownButtonFormField<String?>(
                      initialValue: controller.filterBoutiqueId.value,
                      decoration: const InputDecoration(isDense: true),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Sélectionner —')),
                        ...controller.boutiques.map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          controller.filterBoutiqueId.value = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Produit', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: controller.filterProduitId.value,
                    decoration: const InputDecoration(isDense: true),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Tous')),
                      ...controller.produits.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        controller.filterProduitId.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                if (controller.isAnyAdmin) ...[
                  const Text('Utilisateur',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Obx(
                    () => DropdownButtonFormField<String?>(
                      initialValue: controller.filterUserId.value,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Tous')),
                        ...controller.users.map(
                          (u) => DropdownMenuItem(
                              value: u.id, child: Text(u.nom)),
                        ),
                      ],
                      onChanged: (v) =>
                          controller.filterUserId.value = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Type', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: controller.filterType.value == null,
                        onSelected: (_) =>
                            controller.filterType.value = null,
                      ),
                      ...MouvementStockType.values.map(
                        (t) => ChoiceChip(
                          label: Text(t.label),
                          selected: controller.filterType.value == t,
                          onSelected: (_) =>
                              controller.filterType.value = t,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  final HistoriqueMouvementsController c;
  const _PeriodeBar({required this.c});

  static const _items = [
    (PeriodeMouvement.aujourdhui, 'Aujourd\'hui'),
    (PeriodeMouvement.semaine, 'Semaine'),
    (PeriodeMouvement.mois, 'Mois'),
    (PeriodeMouvement.tout, 'Tout'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Obx(() {
          final current = c.periode.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Pill(
                  label: _items[i].$2,
                  selected: current == _items[i].$1,
                  onTap: () => c.periode.value = _items[i].$1,
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary(context) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.primary(context)
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : AppColors.lightText),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final HistoriqueMouvementsController c;
  const _StatsRow({required this.c});

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
                  icon: Icons.history_rounded,
                  value: '${c.nbMouvements}',
                  label: 'Mouvements',
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.add_circle_outline,
                  value: '${c.nbEntrees}',
                  label: 'Entrées',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.remove_circle_outline,
                  value: '${c.nbSorties}',
                  label: 'Sorties',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.tune_rounded,
                  value: '${c.nbAjustements}',
                  label: 'Ajustés',
                  color: Colors.purple,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
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
    );
  }
}

class _MouvementTile extends StatelessWidget {
  final MouvementStockModel m;
  const _MouvementTile({required this.m});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HistoriqueMouvementsController>();
    final color = _typeColor(m.type);
    final icon = _typeIcon(m.type);
    final delta = m.delta;
    final deltaLabel = delta == 0
        ? '±0'
        : (delta > 0 ? '+$delta' : '$delta');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
              children: [
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
                        m.type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: color,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      Fmt.dateTime(m.date),
                      style:
                          TextStyle(fontSize: 11, color: AppColors.greyText(context, 600)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  m.nomComplet,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${c.userNom(m.userId)} · ${m.qteAvant} → ${m.qteApres}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.greyText(context, 700)),
                ),
                if (m.motif?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    m.motif!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.greyText(context, 700),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deltaLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: delta == 0
                  ? AppColors.greyText(context, 600)
                  : (delta > 0 ? Colors.green : Colors.red),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(MouvementStockType t) {
    switch (t) {
      case MouvementStockType.entree:
        return Colors.green;
      case MouvementStockType.sortie:
        return Colors.orange;
      case MouvementStockType.perte:
      case MouvementStockType.casse:
        return Colors.red;
      case MouvementStockType.ajustement:
        return Colors.purple;
    }
  }

  IconData _typeIcon(MouvementStockType t) {
    switch (t) {
      case MouvementStockType.entree:
        return Icons.arrow_downward_rounded;
      case MouvementStockType.sortie:
        return Icons.arrow_upward_rounded;
      case MouvementStockType.perte:
        return Icons.warning_amber_rounded;
      case MouvementStockType.casse:
        return Icons.broken_image_rounded;
      case MouvementStockType.ajustement:
        return Icons.tune_rounded;
    }
  }
}
