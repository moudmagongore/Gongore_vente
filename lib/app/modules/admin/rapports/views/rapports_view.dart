import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/report_pdf_service.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/rapports_controller.dart';

class RapportsView extends GetView<RapportsController> {
  const RapportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          IconButton(
            tooltip: 'Exporter en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exporterPdf(),
          ),
        ],
      ),
      drawer: controller.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminRapports)
          : const VendeurDrawer(currentRoute: AppRoutes.adminRapports),
      body: SafeArea(
        top: false,
        child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _PeriodeBar(c: controller),
            const SizedBox(height: 12),
            _DateRangeRow(c: controller),
            const SizedBox(height: 16),
            _FiltresRow(c: controller),
            const SizedBox(height: 24),

            // ====== Section Ventes ======
            const _SectionTitle(label: 'Ventes', icon: Icons.receipt_long_rounded),
            const SizedBox(height: 10),
            _VentesSection(c: controller),
            const SizedBox(height: 20),

            // ====== Section Financier ======
            const _SectionTitle(
                label: 'Financier', icon: Icons.attach_money_rounded),
            const SizedBox(height: 10),
            _FinancierSection(c: controller),
            const SizedBox(height: 20),

            // ====== Section Modes paiement ======
            const _SectionTitle(
                label: 'Modes de paiement',
                icon: Icons.payments_outlined),
            const SizedBox(height: 10),
            _PaiementsSection(c: controller),
            const SizedBox(height: 20),

            // ====== Section Top produits ======
            const _SectionTitle(
                label: 'Top produits',
                icon: Icons.inventory_2_outlined),
            const SizedBox(height: 10),
            _TopProduitsSection(c: controller),
            const SizedBox(height: 20),

            // ====== Section Achats ======
            const _SectionTitle(
                label: 'Achats',
                icon: Icons.move_to_inbox_rounded),
            const SizedBox(height: 10),
            _AchatsSection(c: controller),
            const SizedBox(height: 20),

            // ====== Section Top fournisseurs ======
            const _SectionTitle(
                label: 'Top fournisseurs',
                icon: Icons.local_shipping_outlined),
            const SizedBox(height: 10),
            _TopFournisseursSection(c: controller),
          ],
        );
      }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exporterPdf,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Exporter PDF'),
      ),
    );
  }

  Future<void> _exporterPdf() async {
    try {
      final c = controller;
      String? boutiqueNom;
      if (c.boutiqueId.value != null) {
        boutiqueNom = c.boutiqueNom(c.boutiqueId.value!);
      }
      String? vendeurNom;
      if (c.vendeurId.value != null) {
        vendeurNom = c.userNom(c.vendeurId.value!);
      }

      final devise = c.boutiqueId.value != null
          ? (c.boutiques
                  .firstWhereOrNull((b) => b.id == c.boutiqueId.value)
                  ?.devise ??
              'GNF')
          : 'GNF';

      await ReportPdfService.sharePrint(
        ReportData(
          debut: c.dateDebut.value,
          fin: c.dateFin.value,
          boutiqueNom: boutiqueNom,
          vendeurNom: vendeurNom,
          nbVentes: c.nbVentes,
          nbAnnulees: c.nbAnnulees,
          caTotal: c.caTotal,
          caMoyenne: c.caMoyenne,
          benefice: c.beneficeTotal,
          nbArticles: c.nbArticlesVendus,
          caParPaiement: c.caParModePaiement,
          topProduits: c.topProduits
              .map((t) => (nom: t.nom, qte: t.qte, ca: t.ca))
              .toList(),
          nbAppros: c.nbAppros,
          totalAchats: c.totalAchats,
          margePeriode: c.margePeriode,
          detteFournisseurPeriode: c.detteFournisseurPeriode,
          detteFournisseurGlobale: c.detteFournisseurGlobale,
          topFournisseurs: c.topFournisseurs
              .map((t) =>
                  (nom: t.nom, nbAppros: t.nbAppros, total: t.total))
              .toList(),
          devise: devise,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Export PDF impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

// ===========================================================================
// Sections
// ===========================================================================

class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionTitle({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  final RapportsController c;
  const _PeriodeBar({required this.c});

  static const _items = [
    (PeriodePreset.jour, 'Jour'),
    (PeriodePreset.semaine, 'Semaine'),
    (PeriodePreset.mois, 'Mois'),
    (PeriodePreset.trimestre, 'Trimestre'),
    (PeriodePreset.personnalise, 'Perso'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() {
          final current = c.preset.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _PillTab(
                  label: _items[i].$2,
                  selected: current == _items[i].$1,
                  onTap: () => c.selectPreset(_items[i].$1),
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

class _DateRangeRow extends StatelessWidget {
  final RapportsController c;
  const _DateRangeRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _DateBtn(
              label: 'Du',
              date: c.dateDebut.value,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: c.dateDebut.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) c.setDateDebut(d);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DateBtn(
              label: 'Au',
              date: c.dateFin.value,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: c.dateFin.value,
                  firstDate: c.dateDebut.value,
                  lastDate: DateTime.now(),
                );
                if (d != null) c.setDateFin(d);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateBtn({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  Fmt.dateShort(date),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltresRow extends StatelessWidget {
  final RapportsController c;
  const _FiltresRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        // Le vendeur est verrouillé sur ses propres ventes : aucun filtre
        // pertinent à afficher (boutique = la sienne, vendeur = lui-même).
        if (c.isVendeur) return const SizedBox.shrink();
        return Row(
          children: [
            if (c.isSuperAdmin) ...[
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: c.boutiqueId.value,
                  decoration: const InputDecoration(
                    labelText: 'Boutique',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes'),
                    ),
                    ...c.boutiques.map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.nom)),
                    ),
                  ],
                  onChanged: (v) => c.boutiqueId.value = v,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: c.vendeurId.value,
                decoration: const InputDecoration(
                  labelText: 'Gestionnaire',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tous'),
                  ),
                  ...c.users
                      .where((u) =>
                          c.isSuperAdmin ||
                          u.boutiqueId == c.boutiqueId.value)
                      .map(
                        (u) => DropdownMenuItem(value: u.id, child: Text(u.nom)),
                      ),
                ],
                onChanged: (v) => c.vendeurId.value = v,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VentesSection extends StatelessWidget {
  final RapportsController c;
  const _VentesSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Row('Ventes validées', '${c.nbVentes}'),
                _Row('Ventes annulées', '${c.nbAnnulees}',
                    color: c.nbAnnulees > 0 ? Colors.red : null),
                _Row('Articles vendus', '${c.nbArticlesVendus}'),
              ],
            ),
          ),
        ));
  }
}

class _FinancierSection extends StatelessWidget {
  final RapportsController c;
  const _FinancierSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Row('Chiffre d\'affaires',
                    Fmt.money(c.caTotal, currency: 'GNF'),
                    color: AppColors.primary, big: true),
                const Divider(),
                _Row('Bénéfice estimé',
                    Fmt.money(c.beneficeTotal, currency: 'GNF'),
                    color: AppColors.success),
                _Row('Panier moyen',
                    Fmt.money(c.caMoyenne, currency: 'GNF')),
                _Row('Chiffre d\'affaires annulé',
                    Fmt.money(c.caAnnule, currency: 'GNF'),
                    color: c.caAnnule > 0 ? Colors.red : null),
              ],
            ),
          ),
        ));
  }
}

class _PaiementsSection extends StatelessWidget {
  final RapportsController c;
  const _PaiementsSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = c.caParModePaiement;
      if (data.isEmpty) {
        return const _EmptyCard(message: 'Aucune vente sur cette période');
      }
      return Card(
        child: Column(
          children: ModePaiement.values.map((m) {
            final montant = data[m] ?? 0;
            final pct = c.caTotal == 0 ? 0 : (montant / c.caTotal) * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m.label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(Fmt.money(montant, currency: 'GNF'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Text('${pct.toStringAsFixed(0)} %',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _TopProduitsSection extends StatelessWidget {
  final RapportsController c;
  const _TopProduitsSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = c.topProduits.take(10).toList();
      if (list.isEmpty) {
        return const _EmptyCard(message: 'Aucun produit vendu');
      }
      return Card(
        child: Column(
          children: list.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  title: Text(t.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${t.qte} unité(s)',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    Fmt.money(t.ca, currency: 'GNF'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (i < list.length - 1)
                  Divider(height: 1, color: Colors.grey.shade200),
              ],
            );
          }).toList(),
        ),
      );
    });
  }
}

class _AchatsSection extends StatelessWidget {
  final RapportsController c;
  const _AchatsSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Row(
                  'Total achats',
                  Fmt.money(c.totalAchats, currency: 'GNF'),
                  color: AppColors.primary,
                  big: true,
                ),
                const Divider(),
                _Row('Approvisionnements', '${c.nbAppros}'),
                _Row(
                  'Marge brute (CA - achats)',
                  Fmt.money(c.margePeriode, currency: 'GNF'),
                  color: c.margePeriode >= 0
                      ? AppColors.success
                      : Colors.red,
                ),
                _Row(
                  'Dette sur appros de la période',
                  Fmt.money(c.detteFournisseurPeriode,
                      currency: 'GNF'),
                  color: c.detteFournisseurPeriode > 0
                      ? AppColors.warning
                      : null,
                ),
                _Row(
                  'Dette fournisseur totale',
                  Fmt.money(c.detteFournisseurGlobale,
                      currency: 'GNF'),
                  color: c.detteFournisseurGlobale > 0
                      ? AppColors.warning
                      : null,
                ),
              ],
            ),
          ),
        ));
  }
}

class _TopFournisseursSection extends StatelessWidget {
  final RapportsController c;
  const _TopFournisseursSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = c.topFournisseurs.take(10).toList();
      if (list.isEmpty) {
        return const _EmptyCard(message: 'Aucun appro sur cette période');
      }
      return Card(
        child: Column(
          children: list.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  title: Text(t.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${t.nbAppros} appro(s)',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    Fmt.money(t.total, currency: 'GNF'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (i < list.length - 1)
                  Divider(height: 1, color: Colors.grey.shade200),
              ],
            );
          }).toList(),
        ),
      );
    });
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

// Ligne label/valeur pour les sections financières
class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool big;

  const _Row(this.label, this.value, {this.color, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 14 : 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 18 : 14,
              fontWeight: big ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
