import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/subscription_badge_card.dart';
import '../../../../core/widgets/subscription_warning_banner.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // On instancie ici si pas déjà fait (pas via binding pour rester simple)
    final c = Get.put(DashboardController(), permanent: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tableau de bord'),
        actions: [
          IconButton(
            tooltip: 'Rapports',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Get.toNamed(AppRoutes.adminRapports),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminHome),
      // FAB « Vendre » : visible uniquement quand l'utilisateur cumule le
      // rôle gestionnaire (admin avec `alsoGestionnaire = true`, ou rôle
      // vendeur direct). Caché pour le super-admin sur le tableau de bord
      // (il a accès à la création depuis la liste des ventes).
      floatingActionButton: Obx(
        () => UserController.to.isVendeur
            ? FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.venteForm),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Vendre'),
                backgroundColor: AppColors.success,
              )
            : const SizedBox.shrink(),
      ),
      body: androidOnlySafeArea(
        Obx(() {
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async => await Future.delayed(
              const Duration(milliseconds: 400)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Bandeau d'alerte abonnement : ne s'affiche que si ≤ 7
              // jours restants ou en période de grâce. Caché sinon.
              const SubscriptionWarningBanner(),
              const SizedBox(height: 12),
              _GreetingCard(name: UserController.to.user?.nom ?? ''),
              const SizedBox(height: 12),
              // Badge abonnement de la boutique courante (caché pour
              // super-admin et users sans boutiqueId).
              const SubscriptionBadgeCard(),
              const SizedBox(height: 16),
              const _SectionTitle('Aujourd\'hui'),
              const SizedBox(height: 10),
              _KpisJour(c: c),
              const SizedBox(height: 20),
              const _SectionTitle('Ce mois-ci'),
              const SizedBox(height: 10),
              _KpisMois(c: c),
              const SizedBox(height: 20),
              const _SectionTitle('Dépenses du mois'),
              const SizedBox(height: 10),
              _DepensesCard(c: c),
              const SizedBox(height: 20),
              const _SectionTitle(
                  'Évolution du chiffre d\'affaires — 7 derniers jours'),
              const SizedBox(height: 10),
              _ChartCard(child: _LineChartCa(c: c)),
              const SizedBox(height: 20),
              const _SectionTitle('Top 5 produits vendus (mois)'),
              const SizedBox(height: 10),
              _ChartCard(child: _BarChartTopProduits(c: c)),
              const SizedBox(height: 20),
              const _SectionTitle('Modes de paiement (mois)'),
              const SizedBox(height: 10),
              _ChartCard(child: _PiePaiements(c: c)),
              const SizedBox(height: 20),
              const _SectionTitle('Performance par boutique'),
              const SizedBox(height: 10),
              _ListBoutiques(c: c),
              const SizedBox(height: 20),
              const _SectionTitle('Top gestionnaires'),
              const SizedBox(height: 10),
              _ListVendeurs(c: c),
              const SizedBox(height: 16),
              const _SectionTitle('Accès rapide'),
              const SizedBox(height: 10),
              _QuickActions(),
            ],
          ),
        );
      }),
      ),
    );
  }
}

// ===========================================================================
// Sections
// ===========================================================================

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.greyText(context, 700),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: child,
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final String name;
  const _GreetingCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary(context), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting,',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateLong(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// KPIs
// ===========================================================================

/// Carte KPI principale, plus aérée (utilisée par paire dans une rangée).
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? hint;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyText(context, 700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: TextStyle(fontSize: 11, color: AppColors.greyText(context, 500)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne de métriques secondaires sous les KPIs : pas de cards, une simple
/// rangée discrète sous forme « valeur · valeur · valeur ».
class _SecondaryStats extends StatelessWidget {
  final List<({IconData icon, String value, String label, Color color})> items;
  const _SecondaryStats({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: items
            .map(
              (it) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(it.icon, size: 14, color: it.color),
                  const SizedBox(width: 4),
                  Text(
                    it.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: it.color,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    it.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText(context, 600),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KpisJour extends StatelessWidget {
  final DashboardController c;
  const _KpisJour({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    value: Fmt.number(c.caJour),
                    label: 'Chiffre d\'affaires',
                    hint: 'GNF',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary(context),
                    value: c.nbVentesJour.toString(),
                    label: 'Ventes',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SecondaryStats(items: [
            (
              icon: Icons.shopping_basket_rounded,
              value: c.nbArticlesJour.toString(),
              label: 'articles',
              color: AppColors.accent,
            ),
            (
              icon: Icons.cancel_outlined,
              value: c.nbAnnulationsJour.toString(),
              label: 'annulées',
              color: Colors.red,
            ),
            (
              icon: Icons.savings_outlined,
              value: Fmt.number(c.depensesJour),
              label: 'dépensés',
              color: AppColors.danger,
            ),
          ]),
        ],
      ),
    );
  }
}

class _KpisMois extends StatelessWidget {
  final DashboardController c;
  const _KpisMois({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    value: Fmt.number(c.caMois),
                    label: 'Chiffre d\'affaires mensuel',
                    hint: 'GNF',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.savings_rounded,
                    color: AppColors.secondary,
                    value: Fmt.number(c.beneficeMois),
                    label: 'Bénéfice',
                    hint: 'GNF \n estimé',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SecondaryStats(items: [
            (
              icon: Icons.receipt_long_rounded,
              value: c.nbVentesMois.toString(),
              label: 'ventes',
              color: AppColors.primary(context),
            ),
            (
              icon: Icons.savings_outlined,
              value: Fmt.number(c.depensesMois),
              label: 'dépensés',
              color: AppColors.danger,
            ),
            (
              icon: Icons.account_balance_wallet_outlined,
              value: Fmt.number(c.resultatNetMois),
              label: 'résultat net',
              color: c.resultatNetMois >= 0
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ]),
        ],
      ),
    );
  }
}

/// Carte « Dépenses du mois » : total dépensé, résultat net après charges,
/// et les 3 postes les plus lourds. Renvoie vers la liste des dépenses.
class _DepensesCard extends StatelessWidget {
  final DashboardController c;
  const _DepensesCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final top = c.topDepensesMois;
      final total = c.depensesMois;
      final net = c.resultatNetMois;
      final netColor = net >= 0 ? AppColors.success : AppColors.danger;

      return InkWell(
        onTap: () => Get.toNamed(AppRoutes.adminDepenses),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.savings_outlined,
                        color: AppColors.danger, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Fmt.number(total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'GNF dépensés · ${c.nbDepensesMois} dépense(s)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.number(net),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: netColor,
                        ),
                      ),
                      Text(
                        'résultat net',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (top.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Aucune dépense déclarée ce mois-ci.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText(context, 600),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                ...top.map((n) {
                  final ratio = total == 0 ? 0.0 : n.total / total;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Fmt.number(n.total),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            backgroundColor:
                                AppColors.danger.withValues(alpha: 0.10),
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ===========================================================================
// Charts
// ===========================================================================

class _LineChartCa extends StatelessWidget {
  final DashboardController c;
  const _LineChartCa({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pts = c.serie7Jours;
      final maxY = c.max7Jours * 1.2;

      if (pts.every((p) => p.total == 0)) {
        return _NoData(message: 'Aucune vente sur les 7 derniers jours');
      }

      final spots = pts
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.total))
        .toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: maxY / 4,
                getTitlesWidget: (value, _) => Text(
                  Fmt.number(value),
                  style: TextStyle(
                      fontSize: 9, color: AppColors.greyText(context, 600)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  final d = pts[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.greyText(context, 600)),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary(context),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary(context),
                  strokeColor: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary(context).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
    });
  }
}

class _BarChartTopProduits extends StatelessWidget {
  final DashboardController c;
  const _BarChartTopProduits({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tops = c.topProduits;
      if (tops.isEmpty) return _NoData(message: 'Aucune vente sur le mois');

      final maxQ = c.topProduitsMaxQuantite.toDouble();
      return Column(
      children: tops.asMap().entries.map((e) {
        final i = e.key;
        final t = e.value;
        final ratio = t.quantite / maxQ;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _rankColor(context, i).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _rankColor(context, i),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${t.quantite}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _rankColor(context, i),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_rankColor(context, i)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
    });
  }

  Color _rankColor(BuildContext context, int i) {
    switch (i) {
      case 0:
        return AppColors.primary(context);
      case 1:
        return AppColors.secondary;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}

class _PiePaiements extends StatelessWidget {
  final DashboardController c;
  const _PiePaiements({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = c.caParModePaiement;
      if (data.isEmpty) return _NoData(message: 'Aucune vente sur le mois');

      final total = data.values.fold<double>(0, (acc, v) => acc + v);
      final colors = {
        ModePaiement.especes: AppColors.success,
        ModePaiement.orangeMoney: AppColors.warning,
        ModePaiement.mobileMoney: AppColors.primary(context),
        ModePaiement.paycard: AppColors.secondary,
      };

      return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.entries.map((e) {
                final pct = (e.value / total) * 100;
                return PieChartSectionData(
                  value: e.value,
                  color: colors[e.key],
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: data.entries
              .map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[e.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.key.label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Fmt.number(e.value),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
    });
  }
}

class _NoData extends StatelessWidget {
  final String message;
  const _NoData({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(message,
                style: TextStyle(color: AppColors.greyText(context, 600), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ListBoutiques extends StatelessWidget {
  final DashboardController c;
  const _ListBoutiques({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = c.caParBoutique;
      if (list.isEmpty) return _NoData(message: 'Aucune donnée');
      return Card(
        child: Column(
          children: list
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary(context).withValues(alpha: 0.12),
                          child: Icon(Icons.store_rounded,
                              color: AppColors.primary(context)),
                        ),
                        title: Text(e.value.boutique.nom),
                        subtitle: Text('${e.value.nb} vente(s)',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          Fmt.money(e.value.ca,
                              currency: e.value.boutique.devise),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ),
                      if (e.key < list.length - 1)
                        Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  ))
              .toList(),
        ),
      );
    });
  }
}

class _ListVendeurs extends StatelessWidget {
  final DashboardController c;
  const _ListVendeurs({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = c.topVendeurs;
      if (list.isEmpty) return _NoData(message: 'Aucune donnée');
      return Card(
        child: Column(
          children: list
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.secondary.withValues(alpha: 0.15),
                          child: Text(
                            e.value.user.nom.isEmpty
                                ? '?'
                                : e.value.user.nom[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(e.value.user.nom),
                        subtitle: Text('${e.value.nb} vente(s)',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          Fmt.number(e.value.ca),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      if (e.key < list.length - 1)
                        Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  ))
              .toList(),
        ),
      );
    });
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        // admin/super-admin n'ont pas le droit de créer une vente.
        // Raccourci pointé vers la liste (lecture seule).
        _Quick(
          icon: Icons.receipt_long_rounded,
          label: 'Ventes',
          color: AppColors.success,
          route: AppRoutes.adminVentes,
        ),
        _Quick(
          icon: Icons.store_rounded,
          label: 'Boutiques',
          color: AppColors.primary(context),
          route: AppRoutes.adminBoutiques,
        ),
        _Quick(
          icon: Icons.inventory_2_rounded,
          label: 'Produits',
          color: AppColors.accent,
          route: AppRoutes.adminProduits,
        ),
        _Quick(
          icon: Icons.bar_chart_rounded,
          label: 'Rapports',
          color: AppColors.secondary,
          route: AppRoutes.adminRapports,
        ),
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _Quick({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context), width: 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
