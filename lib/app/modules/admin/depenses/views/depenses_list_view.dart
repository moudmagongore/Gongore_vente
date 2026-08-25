import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/depense_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/depenses_controller.dart';
import '../widgets/depense_sheet.dart';

class DepensesListView extends GetView<DepensesController> {
  const DepensesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (nature, commentaire, auteur)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
        actions: [
          if (controller.isAnyAdmin)
            IconButton(
              tooltip: 'Natures de dépense',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Get.toNamed(AppRoutes.adminNaturesDepense),
            ),
          IconButton(
            tooltip: 'Filtres',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      drawer: controller.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminDepenses)
          : const VendeurDrawer(currentRoute: AppRoutes.adminDepenses),
      floatingActionButton: Obx(
        () => UserController.to.canDeclareDepense
            ? FloatingActionButton.extended(
                onPressed: () => DepenseSheet.open(context, controller),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Déclarer'),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (controller.isSuperAdmin) _BoutiquePicker(c: controller),
            const SizedBox(height: 10),
            _PeriodeBar(c: controller),
            const SizedBox(height: 14),
            _StatsRow(c: controller),
            const SizedBox(height: 12),
            _RepartitionCard(c: controller),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Les tuiles résolvent le nom de l'auteur et de la boutique
                // dans `itemBuilder`, hors du scope de cet Obx. On lit donc
                // les deux listes ici pour que l'arrivée des users/boutiques
                // rafraîchisse bien les libellés.
                controller.users.length;
                controller.boutiques.length;
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _EmptyState(
                    filtre: controller.search.value.isNotEmpty ||
                        controller.filterNatureId.value != null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _DepenseTile(depense: list[i], c: controller),
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
      isScrollControlled: true,
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
                const Text('Filtres',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                const Text('Nature de dépense',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(() {
                  final natures = controller.naturesFiltrables;
                  final safe = natures.any(
                          (n) => n.id == controller.filterNatureId.value)
                      ? controller.filterNatureId.value
                      : null;
                  return DropdownButtonFormField<String?>(
                    initialValue: safe,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes'),
                      ),
                      ...natures.map(
                        (n) => DropdownMenuItem(
                          value: n.id,
                          child: Text(n.nom, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => controller.filterNatureId.value = v,
                  );
                }),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.filterNatureId.value = null;
                          Get.back();
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================

class _BoutiquePicker extends StatelessWidget {
  final DepensesController c;
  const _BoutiquePicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Obx(() {
        if (c.boutiques.isEmpty) return const SizedBox.shrink();
        final safe = c.boutiques.any((b) => b.id == c.filterBoutiqueId.value)
            ? c.filterBoutiqueId.value
            : null;
        return DropdownButtonFormField<String?>(
          initialValue: safe,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Boutique',
            prefixIcon: Icon(Icons.store_outlined),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Toutes les boutiques'),
            ),
            ...c.boutiques.map(
              (b) => DropdownMenuItem(value: b.id, child: Text(b.nom)),
            ),
          ],
          onChanged: (v) => c.filterBoutiqueId.value = v,
        );
      }),
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  final DepensesController c;
  const _PeriodeBar({required this.c});

  static const _items = [
    (PeriodeDepense.aujourdhui, 'Aujourd\'hui'),
    (PeriodeDepense.semaine, 'Semaine'),
    (PeriodeDepense.mois, 'Mois'),
    (PeriodeDepense.tout, 'Tout'),
  ];

  @override
  Widget build(BuildContext context) {
    // Pas de ListView ici : ses enfants sont construits paresseusement,
    // donc la lecture de `periode.value` tomberait HORS du scope de l'Obx
    // (« improper use of a GetX »). Row construit tout de suite.
    return SizedBox(
      height: 34,
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
                _PillTab(
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

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.danger
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.danger : AppColors.borderOf(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.greyText(context, 700),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DepensesController c;
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
                  icon: Icons.trending_down_rounded,
                  value: Fmt.number(c.totalDepenses),
                  label: 'Total dépensé',
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_rounded,
                  value: '${c.nbDepenses}',
                  label: 'Dépenses',
                  color: AppColors.primary(context),
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
        border: Border.all(color: AppColors.borderOf(context)),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Répartition des dépenses par nature sur la période : les 3 postes les
/// plus lourds, avec leur part relative. Masquée si aucune dépense.
class _RepartitionCard extends StatelessWidget {
  final DepensesController c;
  const _RepartitionCard({required this.c});

  static const _palette = [
    AppColors.danger,
    AppColors.warning,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = c.parNature;
      if (data.isEmpty) return const SizedBox.shrink();
      final total = c.totalDepenses;
      final top = data.take(3).toList();
      final autres = data.length > 3
          ? data.skip(3).fold<double>(0, (acc, e) => acc + e.total)
          : 0.0;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.donut_small_rounded,
                      size: 15, color: AppColors.greyText(context, 700)),
                  const SizedBox(width: 6),
                  Text(
                    'RÉPARTITION PAR NATURE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.greyText(context, 700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barre empilée : une teinte par poste, « autres » en gris.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      ...top.asMap().entries.map((e) => Expanded(
                            flex: (e.value.total * 1000 ~/
                                    (total == 0 ? 1 : total))
                                .clamp(1, 1000),
                            child: ColoredBox(
                              color: _palette[e.key % _palette.length],
                            ),
                          )),
                      if (autres > 0)
                        Expanded(
                          flex:
                              (autres * 1000 ~/ (total == 0 ? 1 : total))
                                  .clamp(1, 1000),
                          child: ColoredBox(color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...top.asMap().entries.map((e) {
                final pct = total == 0 ? 0.0 : (e.value.total / total) * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _palette[e.key % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)} %',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Fmt.number(e.value.total),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }),
              if (autres > 0)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Autres (${data.length - 3})',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                    ),
                    Text(
                      Fmt.number(autres),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText(context, 700),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _DepenseTile extends StatelessWidget {
  final DepenseModel depense;
  final DepensesController c;
  const _DepenseTile({required this.depense, required this.c});

  @override
  Widget build(BuildContext context) {
    final peutEditer = c.canEdit(depense);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: peutEditer
            ? () => DepenseSheet.open(context, c, editing: depense)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.danger, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      depense.natureNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 11,
                            color: AppColors.greyText(context, 500)),
                        const SizedBox(width: 3),
                        Text(
                          Fmt.dateTime(depense.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.person_outline_rounded,
                            size: 11,
                            color: AppColors.greyText(context, 500)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            c.userNom(depense.userId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.greyText(context, 600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (c.isSuperAdmin) ...[
                      const SizedBox(height: 3),
                      Text(
                        c.boutiqueNom(depense.boutiqueId),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary(context),
                        ),
                      ),
                    ],
                    if (depense.commentaire?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        depense.commentaire!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.greyText(context, 600),
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
                    '- ${Fmt.number(depense.montant)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'GNF',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.greyText(context, 600),
                    ),
                  ),
                ],
              ),
              if (peutEditer)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.greyText(context, 600)),
                  tooltip: 'Actions',
                  onSelected: (v) {
                    if (v == 'edit') {
                      DepenseSheet.open(context, c, editing: depense);
                    } else if (v == 'delete') {
                      c.confirmDelete(depense);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Corriger'),
                      ),
                    ),
                    PopupMenuItem(
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
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtre;
  const _EmptyState({required this.filtre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtre ? Icons.search_off_rounded : Icons.savings_outlined,
              size: 76,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              filtre
                  ? 'Aucune dépense ne correspond.'
                  : 'Aucune dépense sur cette période.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
            if (!filtre) ...[
              const SizedBox(height: 8),
              Text(
                'Utilisez le bouton « Déclarer » pour enregistrer '
                'une sortie d\'argent.',
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
