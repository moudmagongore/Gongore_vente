import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/vente_model.dart' show ModePaiement;
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/appros_controller.dart';

class ApprosListView extends GetView<ApprosController> {
  const ApprosListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvisionnements'),
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
                hintText: 'Rechercher (n° appro, fournisseur)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: controller.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminAppros)
          : const VendeurDrawer(currentRoute: AppRoutes.adminAppros),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _PeriodeBar(c: controller),
            const SizedBox(height: 14),
            _StatsBar(c: controller),
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
                          Icon(Icons.local_shipping_outlined,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun appro sur cette période.',
                            style: TextStyle(color: AppColors.greyText(context, 600)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ApproTile(appro: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
      // FAB ouvert au super-admin (sans restriction) ou au gestionnaire.
      // Obx → réagit au cumul admin+gestionnaire en direct.
      floatingActionButton: Obx(
        () => UserController.to.canPerformSales
            ? FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.approForm),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouvel appro'),
              )
            : const SizedBox.shrink(),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (controller.isSuperAdmin) ...[
                  const Text('Boutique', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Obx(
                    () => DropdownButtonFormField<String?>(
                      initialValue: controller.filterBoutiqueId.value,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Toutes')),
                        ...controller.boutiques.map(
                          (b) => DropdownMenuItem(
                              value: b.id, child: Text(b.nom)),
                        ),
                      ],
                      onChanged: (v) => controller.filterBoutiqueId.value = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.isAnyAdmin) ...[
                  const Text('Réceptionné par',
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
                      onChanged: (v) => controller.filterUserId.value = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Fournisseur', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: controller.filterFournisseurId.value,
                    decoration: const InputDecoration(isDense: true),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Tous')),
                      ...controller.fournisseurs.map(
                        (f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(f.nom,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => controller.filterFournisseurId.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mode de paiement',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: controller.filterModePaiement.value == null,
                        onSelected: (_) =>
                            controller.filterModePaiement.value = null,
                      ),
                      ...ModePaiement.values.map(
                        (m) => ChoiceChip(
                          label: Text(m.label),
                          selected: controller.filterModePaiement.value == m,
                          onSelected: (_) =>
                              controller.filterModePaiement.value = m,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => CheckboxListTile(
                    value: controller.onlyAvecCredit.value,
                    onChanged: (v) =>
                        controller.onlyAvecCredit.value = v ?? false,
                    title: const Text('Avec dette en cours'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Obx(
                  () => CheckboxListTile(
                    value: controller.inclureAnnulees.value,
                    onChanged: (v) =>
                        controller.inclureAnnulees.value = v ?? false,
                    title: const Text('Inclure les appros annulés'),
                    contentPadding: EdgeInsets.zero,
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
  final ApprosController c;
  const _PeriodeBar({required this.c});

  static const _items = [
    (PeriodeAppro.aujourdhui, 'Aujourd\'hui'),
    (PeriodeAppro.semaine, 'Semaine'),
    (PeriodeAppro.mois, 'Mois'),
    (PeriodeAppro.tout, 'Tout'),
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
              const SizedBox(width: 8),
              _Pill(
                label: current == PeriodeAppro.personnalise
                    ? _customLabel(c)
                    : 'Personnalisé',
                selected: current == PeriodeAppro.personnalise,
                onTap: () => _pickCustomRange(context, c),
              ),
            ],
          );
        }),
      ),
    );
  }

  static String _customLabel(ApprosController c) {
    final d = c.customDebut.value;
    final f = c.customFin.value;
    if (d == null || f == null) return 'Personnalisé';
    return '${Fmt.dateShort(d)} → ${Fmt.dateShort(f)}';
  }

  Future<void> _pickCustomRange(
      BuildContext context, ApprosController c) async {
    final now = DateTime.now();
    final initial = (c.customDebut.value != null && c.customFin.value != null)
        ? DateTimeRange(start: c.customDebut.value!, end: c.customFin.value!)
        : DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    c.customDebut.value = picked.start;
    c.customFin.value = picked.end;
    c.periode.value = PeriodeAppro.personnalise;
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

class _StatsBar extends StatelessWidget {
  final ApprosController c;
  const _StatsBar({required this.c});

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
                  icon: Icons.shopping_cart_rounded,
                  value: Fmt.number(c.totalAchats),
                  label: 'Total achats',
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.warning_amber_rounded,
                  value: Fmt.number(c.detteEnCours),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproTile extends StatelessWidget {
  final ApprovisionnementModel appro;
  const _ApproTile({required this.appro});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ApprosController>();
    final annulee = appro.statut == ApproStatut.annulee;
    final hasCredit = !annulee && appro.resteAPayer > 0;
    final devise = c.deviseDe(appro.boutiqueId);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(AppRoutes.approDetail, arguments: appro.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (annulee ? Colors.grey : AppColors.primary(context))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  annulee
                      ? Icons.cancel_outlined
                      : Icons.local_shipping_rounded,
                  color: annulee ? Colors.grey : AppColors.primary(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          appro.numeroAffichage,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.primary(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (annulee)
                          const _MiniBadge(label: 'Annulé', color: Colors.red)
                        else if (hasCredit)
                          const _MiniBadge(
                              label: 'À payer', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.fournisseurNom(appro.fournisseurId),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${Fmt.dateTime(appro.date)} · ${appro.modePaiement.label}',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.greyText(context, 600)),
                    ),
                    if (hasCredit) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reste : ${Fmt.money(appro.resteAPayer, currency: devise)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Fmt.money(appro.total, currency: devise),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: annulee ? Colors.grey : AppColors.primary(context),
                  decoration: annulee
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Imprimer le bon',
                icon: Icon(Icons.print_outlined,
                    size: 18, color: AppColors.greyText(context, 700)),
                onPressed: () => c.reimprimerRecu(appro),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
