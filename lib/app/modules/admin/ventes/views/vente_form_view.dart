import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/variante_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/vente_form_controller.dart';

class VenteFormView extends GetView<VenteFormController> {
  const VenteFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle vente'),
        actions: [
          Obx(() => controller.lignes.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Vider',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context),
                )),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
        if (controller.boutiques.isEmpty) {
          return _NoBoutique();
        }
        return Column(
          children: [
            _ClientBar(controller: controller),
            const Divider(height: 1),
            Expanded(child: _LignesSection(controller: controller)),
            const Divider(height: 1),
            _SummaryAndAction(controller: controller),
          ],
        );
      }),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Vider la vente ?'),
        content: const Text('Tous les articles seront retirés.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              controller.clearLignes();
              Get.back();
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Section : barre client en haut
// ============================================================================

class _ClientBar extends StatelessWidget {
  final VenteFormController controller;
  const _ClientBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openClientPicker(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => Icon(
                    controller.isClientDivers
                        ? Icons.person_outline_rounded
                        : Icons.person_rounded,
                    color: AppColors.primary(context),
                    size: 22,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Client',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greyText(context, 600),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Obx(() => Text(
                        controller.clientLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  Obx(() {
                    final c = controller.clientSelectionne;
                    if (c == null) return const SizedBox.shrink();
                    if (c.solde == 0) return const SizedBox.shrink();
                    final isDette = c.solde > 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        isDette
                            ? 'Crédit en cours : ${Fmt.number(c.solde)}'
                            : 'Avance disponible : ${Fmt.number(-c.solde)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDette
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right_rounded,
                color: AppColors.greyText(context, 700)),
          ],
        ),
      ),
    );
  }

  void _openClientPicker(BuildContext context) {
    Get.bottomSheet(
      _ClientPickerSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final VenteFormController controller;
  const _ClientPickerSheet({required this.controller});

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _libreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _libreCtrl.text = widget.controller.clientNomLibre.value;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _libreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: androidOnlySafeArea(
            Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choisir un client',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Section client divers
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client de passage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.greyText(context, 600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _libreCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nom libre (ex. M. Camara au comptant)',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: TextButton(
                          onPressed: () {
                            widget.controller
                                .setClientNomLibre(_libreCtrl.text);
                            Get.back();
                          },
                          child: const Text('Valider'),
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (v) {
                        widget.controller.setClientNomLibre(v);
                        Get.back();
                      },
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        widget.controller.resetClient();
                        Get.back();
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text(
                        'Aucun client (Client divers anonyme)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client (nom, téléphone)...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.controller.clients.where((c) {
                    if (q.isEmpty) return true;
                    return c.nom.toLowerCase().contains(q) ||
                        (c.telephone?.toLowerCase().contains(q) ?? false);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun client enregistré.\nUtilisez « Client de passage » au-dessus.'
                              : 'Aucun client ne correspond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.greyText(context, 600)),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final selected = c.id == widget.controller.clientId.value;
                      final hasDette = c.solde > 0;
                      final hasAvance = c.solde < 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary(context).withValues(alpha: 0.12),
                          child: Text(
                            c.nom.isEmpty ? '?' : c.nom[0].toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(c.nom),
                        subtitle: c.telephone == null
                            ? null
                            : Text(c.telephone!,
                                style: const TextStyle(fontSize: 12)),
                        trailing: hasDette
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  Fmt.number(c.solde),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              )
                            : hasAvance
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Avance ${Fmt.number(-c.solde)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  )
                                : selected
                                    ? Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary(context))
                                    : null,
                        onTap: () {
                          widget.controller.selectClient(c.id);
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Section : liste des lignes ajoutées
// ============================================================================

class _LignesSection extends StatelessWidget {
  final VenteFormController controller;
  const _LignesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.lignes.isEmpty) {
        return _EmptyLignes(onAdd: () => _openProduitPicker(context));
      }
      return Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: controller.lignes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _LigneTile(controller: controller, index: i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _openProduitPicker(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un article'),
            ),
          ),
        ],
      );
    });
  }

  void _openProduitPicker(BuildContext context) {
    Get.bottomSheet(
      _ProduitPickerSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }
}

class _EmptyLignes extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLignes({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aucun article dans la vente',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cliquez sur le bouton ci-dessous pour ajouter un produit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText(context, 600),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un article'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneTile extends StatelessWidget {
  final VenteFormController controller;
  final int index;
  const _LigneTile({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (index >= controller.lignes.length) return const SizedBox.shrink();
      final l = controller.lignes[index];
      final devise = controller.devise;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.nomComplet,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Catégorie : même chip discret que dans le picker
                      // et le dialog "Ajouter à la vente".
                      Builder(
                        builder: (_) {
                          final catNom = controller.categories
                              .firstWhereOrNull(
                                  (c) => c.id == l.produit.categorieId)
                              ?.nom;
                          if (catNom == null || catNom.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary(context)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 11,
                                    color: AppColors.primary(context)
                                        .withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      catNom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary(context)
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.money(l.prixUnitaire, currency: devise)} l\'unité',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.greyText(context, 600),
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
                      Fmt.money(l.sousTotal, currency: devise),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (l.remise > 0)
                      Text(
                        '-${Fmt.money(l.remise, currency: devise)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.greyText(context, 500)),
                  onPressed: () => controller.removeLigne(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _QtyStepper(
                  quantite: l.quantite,
                  onMinus: () => controller.decrementLigne(index),
                  onPlus: () => controller.incrementLigne(index),
                ),
                const Spacer(),
                _RemiseChip(
                  active: l.remise > 0,
                  onTap: () => _showRemiseDialog(context, index, l.sousTotalBrut),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showRemiseDialog(BuildContext context, int index, double max) {
    final montantCtrl = TextEditingController();
    final pourcentCtrl = TextEditingController();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    Get.bottomSheet(
      SafeArea(
        top: false,
        bottom: false,
        child: Container(
          color: Theme.of(context).cardTheme.color,
          padding: EdgeInsets.fromLTRB(
              16, 20, 16,
              (viewInsets > 0 ? viewInsets : viewPadding) + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Remise sur la ligne',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Sous-total brut : ${Fmt.number(max)}',
                style: TextStyle(fontSize: 12, color: AppColors.greyText(context, 700)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montantCtrl,
                decoration: InputDecoration(
                  labelText: 'Montant fixe (${controller.devise})',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pourcentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pourcentage (%)',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.setRemiseLigne(index, 0);
                        Get.back();
                      },
                      child: const Text('Retirer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final m = double.tryParse(
                            montantCtrl.text.replaceAll(',', '.'));
                        final p = double.tryParse(
                            pourcentCtrl.text.replaceAll(',', '.'));
                        if (m != null) {
                          controller.setRemiseLigne(index, m);
                        } else if (p != null) {
                          controller.setRemiseLignePourcent(index, p);
                        }
                        Get.back();
                      },
                      child: const Text('Appliquer'),
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

class _QtyStepper extends StatelessWidget {
  final int quantite;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    required this.quantite,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIconBtn(icon: Icons.remove_rounded, onTap: onMinus),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$quantite',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.primary(context),
              ),
            ),
          ),
          _StepIconBtn(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.primary(context)),
        ),
      ),
    );
  }
}

class _RemiseChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _RemiseChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.greyText(context, 600);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.success.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? AppColors.success.withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.local_offer_rounded : Icons.local_offer_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'Remise appliquée' : 'Remise',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section : sélection produit (modal)
// ============================================================================

class _ProduitPickerSheet extends StatefulWidget {
  final VenteFormController controller;
  const _ProduitPickerSheet({required this.controller});

  @override
  State<_ProduitPickerSheet> createState() => _ProduitPickerSheetState();
}

class _ProduitPickerSheetState extends State<_ProduitPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _filterCategorieId = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: androidOnlySafeArea(
            Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choisir un article',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Bouton « Terminer » visible dès qu'au moins un article
                    // a été ajouté — permet de fermer le picker sans avoir à
                    // scroller chercher la croix.
                    // Obx(() {
                    //   if (widget.controller.lignes.isEmpty) {
                    //     return const SizedBox.shrink();
                    //   }
                    //   return TextButton.icon(
                    //     onPressed: () => Get.back(),
                    //     icon: const Icon(Icons.check_rounded, size: 18),
                    //     label: const Text('Terminer'),
                    //     style: TextButton.styleFrom(
                    //       foregroundColor: AppColors.success,
                    //     ),
                    //   );
                    // }),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Panier compact : aperçu horizontal des articles déjà ajoutés.
              // Permet sur petit écran de voir ce qu'on a déjà sélectionné
              // sans fermer le picker.
              _PanierCompact(controller: widget.controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (nom, code-barre)...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 38,
                child: Obx(() {
                  if (widget.controller.categories.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _CatPill(
                          label: 'Tout',
                          selected: _filterCategorieId.isEmpty,
                          onTap: () => setState(() => _filterCategorieId = ''),
                        ),
                        for (final c in widget.controller.categories) ...[
                          const SizedBox(width: 8),
                          _CatPill(
                            label: c.nom,
                            selected: _filterCategorieId == c.id,
                            onTap: () =>
                                setState(() => _filterCategorieId = c.id),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (widget.controller.isLoadingProduits.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = widget.controller.produits.where((p) {
                    if (_filterCategorieId.isNotEmpty &&
                        p.categorieId != _filterCategorieId) {
                      return false;
                    }
                    if (q.isEmpty) return true;
                    return p.nom.toLowerCase().contains(q);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun produit dans cette boutique.'
                              : 'Aucun produit ne correspond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.greyText(context, 600)),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final isOut = p.quantiteStock <= 0;
                      final ligneExistante = widget.controller.lignes
                          .firstWhereOrNull((l) => l.produit.id == p.id);
                      final dejaAjoute = ligneExistante != null;
                      return ListTile(
                        enabled: !isOut,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (dejaAjoute
                                    ? AppColors.success
                                    : AppColors.primary(context))
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            dejaAjoute
                                ? Icons.check_circle_rounded
                                : Icons.inventory_2_rounded,
                            color: dejaAjoute
                                ? AppColors.success
                                : AppColors.primary(context),
                            size: 20,
                          ),
                        ),
                        title: Text(p.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Catégorie : petit chip discret avec icône
                            // (affiché juste sous le nom du produit).
                            Builder(
                              builder: (_) {
                                final catNom = widget.controller.categories
                                    .firstWhereOrNull(
                                        (c) => c.id == p.categorieId)
                                    ?.nom;
                                if (catNom == null || catNom.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary(context)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.category_outlined,
                                          size: 11,
                                          color: AppColors.primary(context)
                                              .withValues(alpha: 0.85),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            catNom,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary(context)
                                                  .withValues(alpha: 0.85),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Fmt.money(p.prixVente,
                                  currency: widget.controller.devise),
                              style: TextStyle(
                                color: AppColors.primary(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (dejaAjoute)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Ajouté ×${ligneExistante.quantite}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      (isOut ? Colors.red : AppColors.success)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOut
                                      ? 'Rupture'
                                      : 'Stock ${p.quantiteStock}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isOut ? Colors.red : AppColors.success,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openAjoutLigneDialog(context, p);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  void _openAjoutLigneDialog(BuildContext rootContext, ProduitModel produit) {
    // Produit avec variantes : on passe d'abord par un picker de variante.
    if (produit.hasVariantes) {
      Get.bottomSheet(
        _VariantePickerSheet(
          controller: widget.controller,
          produit: produit,
        ),
        isScrollControlled: true,
        backgroundColor: Theme.of(rootContext).cardTheme.color,
      );
      return;
    }
    Get.bottomSheet(
      _AjoutLigneSheet(
        controller: widget.controller,
        produit: produit,
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(rootContext).cardTheme.color,
    );
  }
}

// ============================================================================
// Variante picker : liste les variantes d'un produit (libellé + stock).
// Quand on tape une variante, ferme ce sheet et ouvre `_AjoutLigneSheet`
// avec la variante préchoisie.
// ============================================================================

class _VariantePickerSheet extends StatelessWidget {
  final VenteFormController controller;
  final ProduitModel produit;
  const _VariantePickerSheet({
    required this.controller,
    required this.produit,
  });

  @override
  Widget build(BuildContext context) {
    final repo = ProduitRepository();
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: androidOnlySafeArea(
          Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ----- Header avec gradient subtil -----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary(context),
                            AppColors.primary(context).withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Choisir une variante',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            produit.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // ----- Légende stock -----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _LegendDot(
                        color: AppColors.success, label: 'Disponible'),
                    const SizedBox(width: 14),
                    _LegendDot(color: AppColors.warning, label: 'Bas'),
                    const SizedBox(width: 14),
                    _LegendDot(color: Colors.red, label: 'Rupture'),
                  ],
                ),
              ),
              // ----- Grille des variantes -----
              Expanded(
                child: StreamBuilder<List<VarianteModel>>(
                  stream: repo.watchVariantes(produit.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? const <VarianteModel>[];
                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aucune variante disponible',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(8, 4, 8, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.dividerColor.withValues(alpha: 0.35),
                      ),
                      itemBuilder: (_, i) {
                        final v = list[i];
                        final rupture = v.stock <= 0;
                        final low =
                            !rupture && v.stock <= produit.seuilAlerte;
                        final color = rupture
                            ? Colors.red
                            : (low
                                ? AppColors.warning
                                : AppColors.success);
                        return ListTile(
                          enabled: !rupture,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary(context).withValues(alpha: 0.12),
                            child: Text(
                              v.libelle.isEmpty
                                  ? '?'
                                  : v.libelle.substring(
                                      0,
                                      v.libelle.length > 2
                                          ? 2
                                          : v.libelle.length),
                              style: TextStyle(
                                color: AppColors.primary(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            v.libelleAffichage,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            rupture ? 'Rupture' : 'Stock : ${v.stock}',
                            style: TextStyle(fontSize: 12, color: color),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              rupture ? '0' : '${v.stock}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          onTap: rupture
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  Get.bottomSheet(
                                    _AjoutLigneSheet(
                                      controller: controller,
                                      produit: produit,
                                      variante: v,
                                    ),
                                    isScrollControlled: true,
                                    backgroundColor:
                                        Theme.of(context).cardTheme.color,
                                  );
                                },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit point coloré + label utilisé dans la légende du picker variante.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _CatPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatPill({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary(context) : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.primary(context) : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : AppColors.lightText),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section : ajout d'une ligne (qty + remise après sélection produit)
// ============================================================================

class _AjoutLigneSheet extends StatefulWidget {
  final VenteFormController controller;
  final ProduitModel produit;

  /// Variante préchoisie (uniquement quand `produit.hasVariantes`).
  /// `null` pour les produits simples.
  final VarianteModel? variante;

  const _AjoutLigneSheet({
    required this.controller,
    required this.produit,
    this.variante,
  });

  @override
  State<_AjoutLigneSheet> createState() => _AjoutLigneSheetState();
}

class _AjoutLigneSheetState extends State<_AjoutLigneSheet> {
  late final TextEditingController _qteCtrl;
  late final TextEditingController _remiseCtrl;
  int _quantite = 1;
  double _remise = 0;

  @override
  void initState() {
    super.initState();
    _qteCtrl = TextEditingController(text: '1');
    _remiseCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _remiseCtrl.dispose();
    super.dispose();
  }

  void _setQuantite(int n) {
    setState(() {
      _quantite = n.clamp(1, 1 << 30);
      _qteCtrl.text = _quantite.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final v = widget.variante;
    final devise = widget.controller.devise;
    // Stock dispo : sur la variante si présente, sinon stock total live.
    final dispo = v != null
        ? v.stock
        : (widget.controller.stockDispoUi(p.id) ?? p.quantiteStock);
    final sousTotalBrut = p.prixVente * _quantite;
    final sousTotal = sousTotalBrut - _remise;

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final viewPadding = mq.viewPadding.bottom;
    // Plafond basé sur la hauteur VISIBLE (écran - clavier) pour toujours
    // laisser un espace en haut quand le clavier est ouvert.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    return ConstrainedBox(
      // Empêche le sheet de prendre tout l'écran quand le clavier s'ouvre
      // sur le focus du champ remise. L'AppBar reste visible.
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        // Get.bottomSheet décale déjà le sheet au-dessus du clavier ;
        // on ajoute juste viewPadding (home indicator iOS / barre Android).
        padding: EdgeInsets.fromLTRB(20, 20, 20, viewPadding + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header produit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v != null ? '${p.nom} — ${v.libelleAffichage}' : p.nom,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Catégorie : même design discret que dans le picker.
                      Builder(
                        builder: (_) {
                          final catNom = widget.controller.categories
                              .firstWhereOrNull(
                                  (c) => c.id == p.categorieId)
                              ?.nom;
                          if (catNom == null || catNom.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary(context)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 11,
                                    color: AppColors.primary(context)
                                        .withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      catNom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary(context)
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.money(p.prixVente, currency: devise)} l\'unité',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText(context, 700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (dispo <= 0 ? Colors.red : AppColors.success)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dispo <= 0 ? 'Rupture' : 'Dispo $dispo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                dispo <= 0 ? Colors.red : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Quantité
            const Text(
              'Quantité',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _QtyStepper(
              quantite: _quantite,
              onMinus: () => _setQuantite(_quantite - 1),
              onPlus: () {
                if (_quantite >= dispo) return;
                _setQuantite(_quantite + 1);
              },
            ),
            const SizedBox(height: 18),
            // Remise
            const Text(
              'Remise (optionnelle)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remiseCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                suffixText: devise,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() {
                  _remise = n.clamp(0, sousTotalBrut).toDouble();
                });
              },
            ),
            const SizedBox(height: 18),
            // Récap sous-total
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    'Sous-total ligne',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.money(sousTotal, currency: devise),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: dispo <= 0
                  ? null
                  : () {
                      final ok = widget.controller.addLigne(
                        produit: p,
                        quantite: _quantite,
                        remise: _remise,
                        varianteId: v?.id,
                        varianteLibelle: v?.libelleAffichage,
                        varianteStock: v?.stock,
                      );
                      if (ok) Get.back();
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ajouter à la vente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section : récap totaux + mode paiement + valider
// ============================================================================

// ============================================================================
// Barre du bas compacte : TOTAL + accès paiement (sheet) + Valider.
// Le détail (mode paiement, note, encaissement) est déporté dans un
// bottom sheet pour libérer de l'espace vertical à la liste d'articles.
// ============================================================================

class _SummaryAndAction extends StatelessWidget {
  final VenteFormController controller;
  const _SummaryAndAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ligne TOTAL + bouton Paiement (icône) en compact.
            Obx(() => Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary(context).withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.greyText(context, 700),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Fmt.money(controller.total,
                                currency: controller.devise),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary(context),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _PaiementInfoChip(controller: controller),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Paiement & options',
                        onPressed: () =>
                            _PaiementSheet.open(context, controller),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Obx(() => ElevatedButton.icon(
                  onPressed: controller.isSaving.value ||
                          controller.lignes.isEmpty
                      ? null
                      : controller.validerVente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    controller.isSaving.value
                        ? 'Validation...'
                        : 'Valider la vente',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Chip résumé paiement à droite du TOTAL : montre mode paiement courant
/// + signal éventuel "Crédit" / "Trop perçu". Cliquable, ouvre la sheet.
class _PaiementInfoChip extends StatelessWidget {
  final VenteFormController controller;
  const _PaiementInfoChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reste = controller.resteAPayer;
      final hasCredit = reste > 0;
      final hasOver = reste < 0;
      Color color;
      String label;
      if (hasCredit) {
        color = AppColors.warning;
        label = 'Crédit ${Fmt.money(reste, currency: controller.devise)}';
      } else if (hasOver) {
        color = AppColors.success;
        label =
            'Trop perçu ${Fmt.money(reste.abs(), currency: controller.devise)}';
      } else {
        color = AppColors.greyText(context, 700);
        label = controller.modePaiement.value.label;
      }
      return InkWell(
        onTap: () => _PaiementSheet.open(context, controller),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasCredit
                    ? Icons.warning_amber_rounded
                    : (hasOver
                        ? Icons.check_circle_rounded
                        : Icons.payments_rounded),
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Sheet plein écran qui regroupe les options de paiement
/// (note, mode paiement, encaissement avec avance + montant payé + reste).
/// Déclenché depuis la barre TOTAL pour libérer la liste d'articles.
class _PaiementSheet extends StatelessWidget {
  final VenteFormController controller;
  const _PaiementSheet({required this.controller});

  static void open(BuildContext context, VenteFormController controller) {
    Get.bottomSheet(
      _PaiementSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final viewPadding = mq.viewPadding.bottom;
    // Plafond basé sur la hauteur VISIBLE (écran - clavier) pour toujours
    // laisser un espace en haut quand le clavier est ouvert.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, (viewInsets > 0 ? viewInsets : viewPadding) + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Paiement & options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Récap totaux compact
              Obx(() => Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary(context).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      children: [
                        _Row(
                          label: 'Sous-total',
                          value: Fmt.money(controller.sousTotal,
                              currency: controller.devise),
                        ),
                        if (controller.remiseGlobale.value > 0) ...[
                          const SizedBox(height: 2),
                          _Row(
                            label: 'Remise globale',
                            value:
                                '-${Fmt.money(controller.remiseGlobale.value, currency: controller.devise)}',
                            color: AppColors.success,
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Divider(
                            height: 1,
                            color: AppColors.primary(context).withValues(alpha: 0.18),
                          ),
                        ),
                        _Row(
                          label: 'TOTAL',
                          value: Fmt.money(controller.total,
                              currency: controller.devise),
                          big: true,
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              _RemiseGlobaleField(controller: controller),
              const SizedBox(height: 12),
              _NoteField(controller: controller),
              const SizedBox(height: 10),
              Text(
                'Mode de paiement',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AppColors.greyText(context, 600),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(() {
                    final current = controller.modePaiement.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0;
                            i < ModePaiement.values.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _CatPill(
                            label: ModePaiement.values[i].label,
                            selected: current == ModePaiement.values[i],
                            onTap: () => controller.modePaiement.value =
                                ModePaiement.values[i],
                          ),
                        ],
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              _EncaissementSection(controller: controller),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Tuile cliquable qui résume la remise globale et ouvre un bottom
/// sheet permettant de la saisir en montant fixe OU en pourcentage
/// du sous-total. Aligné visuellement sur la remise par ligne mais
/// présenté en pleine largeur dans la sheet de paiement.
class _RemiseGlobaleField extends StatelessWidget {
  final VenteFormController controller;
  const _RemiseGlobaleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remise = controller.remiseGlobale.value;
      final sousTotal = controller.sousTotal;
      final active = remise > 0;
      final pct = (active && sousTotal > 0)
          ? (remise / sousTotal * 100).clamp(0, 100)
          : 0;

      final accent = active ? AppColors.success : AppColors.primary(context);
      final bg = active
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.primary(context).withValues(alpha: 0.04);
      final border = active
          ? AppColors.success.withValues(alpha: 0.35)
          : AppColors.primary(context).withValues(alpha: 0.18);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showRemiseGlobaleSheet(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    active
                        ? Icons.local_offer_rounded
                        : Icons.local_offer_outlined,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Remise globale',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active
                            ? 'Appliquée au sous-total'
                            : 'Aucune remise — appuyez pour en ajouter',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (active) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '-${Fmt.money(remise, currency: controller.devise)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      if (pct > 0)
                        Text(
                          '${pct.toStringAsFixed(pct < 1 ? 1 : 0)} %',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_rounded,
                      size: 16, color: AppColors.greyText(context, 500)),
                ] else
                  Icon(Icons.add_rounded,
                      size: 18, color: AppColors.primary(context).withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showRemiseGlobaleSheet(BuildContext context) {
    final sousTotal = controller.sousTotal;
    final montantCtrl = TextEditingController(
      text: controller.remiseGlobale.value > 0
          ? Fmt.number(controller.remiseGlobale.value)
          : '',
    );
    final pourcentCtrl = TextEditingController();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;

    Get.bottomSheet(
      SafeArea(
        top: false,
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            (viewInsets > 0 ? viewInsets : viewPadding) + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.primary(context),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Remise globale',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  'Sous-total : ${Fmt.money(sousTotal, currency: controller.devise)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText(context, 700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: montantCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Montant fixe (${controller.devise})',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => pourcentCtrl.clear(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'OU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greyText(context, 500),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pourcentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pourcentage du sous-total',
                  prefixIcon: Icon(Icons.percent_rounded),
                  suffixText: '%',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => montantCtrl.clear(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.remiseGlobale.value = 0;
                        Get.back();
                      },
                      child: const Text('Retirer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final m = double.tryParse(
                            montantCtrl.text.replaceAll(',', '.'));
                        final p = double.tryParse(
                            pourcentCtrl.text.replaceAll(',', '.'));
                        double next = controller.remiseGlobale.value;
                        if (p != null) {
                          next = sousTotal * (p / 100);
                        } else if (m != null) {
                          next = m;
                        }
                        controller.remiseGlobale.value =
                            next.clamp(0, sousTotal).toDouble();
                        Get.back();
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _NoteField extends StatefulWidget {
  final VenteFormController controller;
  const _NoteField({required this.controller});

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _txt;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(text: widget.controller.note.value);
    _expanded = _txt.text.isNotEmpty;
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.greyText(context, 700),
          ),
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.notes_rounded, size: 16),
          label: const Text(
            'Ajouter une note',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    return TextField(
      controller: _txt,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Note (optionnel)',
        prefixIcon: const Icon(Icons.notes_rounded, size: 18),
        suffixIcon: IconButton(
          tooltip: 'Masquer',
          icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: () {
            _txt.clear();
            widget.controller.note.value = '';
            setState(() => _expanded = false);
          },
        ),
        isDense: true,
      ),
      onChanged: (v) => widget.controller.note.value = v,
    );
  }
}

class _EncaissementSection extends StatefulWidget {
  final VenteFormController controller;
  const _EncaissementSection({required this.controller});

  @override
  State<_EncaissementSection> createState() => _EncaissementSectionState();
}

class _EncaissementSectionState extends State<_EncaissementSection> {
  late final TextEditingController _txt;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(text: _format(widget.controller.montantPaye.value));
    // Quand le contrôleur ré-aligne montantPaye sur total (auto-sync),
    // on rafraîchit le champ texte sans perdre le curseur s'il est ouvert.
    _worker = ever(widget.controller.montantPaye, (double v) {
      final newText = _format(v);
      if (_txt.text != newText) {
        _txt.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    });
  }

  String _format(double v) => v == 0 ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _worker?.dispose();
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Obx(() {
      final reste = c.resteAPayer;
      final hasCredit = reste > 0;
      final hasOverpay = reste < 0;
      final clientDivers = c.isClientDivers;
      final blockingCredit = hasCredit && clientDivers;

      Color resteColor;
      String resteLabel;
      if (hasCredit) {
        resteColor = AppColors.warning;
        resteLabel = 'Reste à payer';
      } else if (hasOverpay) {
        resteColor = AppColors.success;
        resteLabel = 'Trop-perçu (déduit du solde)';
      } else {
        resteColor = AppColors.greyText(context, 600);
        resteLabel = 'Réglé intégralement';
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: blockingCredit
              ? AppColors.warning.withValues(alpha: 0.06)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: blockingCredit
                ? AppColors.warning.withValues(alpha: 0.45)
                : AppColors.borderOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau Avance disponible (si applicable)
            if (c.avanceDisponible > 0) ...[
              _AvanceBanner(controller: c),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.payments_rounded,
                    size: 18, color: AppColors.primary(context)),
                const SizedBox(width: 6),
                const Text(
                  'Montant payé',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => c.resetMontantPayeAuto(),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text(
                    'Tout payer',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _txt,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: c.devise,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                c.setMontantPaye(n);
              },
            ),
            const SizedBox(height: 10),
            if (c.avanceUtilisee.value > 0) ...[
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  const Text(
                    'Avance utilisée',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '-${Fmt.money(c.avanceUtilisee.value, currency: c.devise)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Text(
                  resteLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: resteColor,
                  ),
                ),
                const Spacer(),
                Text(
                  Fmt.money(reste.abs(), currency: c.devise),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: resteColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            if (blockingCredit) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sélectionnez un client identifié pour enregistrer ce crédit, '
                      'ou complétez le paiement.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (hasCredit && c.clientSelectionne != null) ...[
              const SizedBox(height: 6),
              Text(
                'Sera ajouté au solde de ${c.clientSelectionne!.nom}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.greyText(context, 600),
                ),
              ),
            ] else if (hasOverpay && c.clientSelectionne != null) ...[
              const SizedBox(height: 6),
              Text(
                'Sera déduit du solde de ${c.clientSelectionne!.nom}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.greyText(context, 600),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool big;
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 15 : 12.5,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 20 : 13.5,
            fontWeight: big ? FontWeight.w800 : FontWeight.w700,
            color: color ?? (big ? AppColors.primary(context) : null),
            letterSpacing: big ? -0.3 : null,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// État vide quand aucune boutique
// ============================================================================

/// Bandeau « Avance disponible » affiché dans la section Encaissement
/// quand le client a un solde négatif (avance). Permet de l'appliquer en
/// 1 clic ou de la saisir manuellement via le champ.
class _AvanceBanner extends StatelessWidget {
  final VenteFormController controller;
  const _AvanceBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final dispo = controller.avanceDisponible;
    final utilisee = controller.avanceUtilisee.value;
    final maxApp = controller.avanceMaxApplicable;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              const Text(
                'Avance disponible',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.money(dispo, currency: controller.devise),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (utilisee == 0)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(36),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: maxApp <= 0
                        ? null
                        : () => controller.appliquerAvanceMax(),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      'Utiliser ${Fmt.money(maxApp, currency: controller.devise)}',
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: Text(
                    'Utilisée : ${Fmt.money(utilisee, currency: controller.devise)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppColors.greyText(context, 600),
                  ),
                  onPressed: () => controller.retirerAvance(),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'Retirer',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Panier compact : aperçu horizontal du panier visible dans le picker
// produits (utile sur petit écran : on garde la liste d'articles à l'œil
// pendant qu'on en ajoute de nouveaux).
// ============================================================================

class _PanierCompact extends StatelessWidget {
  final VenteFormController controller;
  const _PanierCompact({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.lignes.isEmpty) return const SizedBox.shrink();
      final devise = controller.devise;
      final nbArticles = controller.nbArticles;
      final total = controller.total;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final fg = isDark ? Colors.white : AppColors.primary(context);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary(context).withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_basket_rounded, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(
                  '$nbArticles article${nbArticles > 1 ? 's' : ''} au panier',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const Spacer(),
                Text(
                  Fmt.money(total, currency: devise),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.lignes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final l = controller.lignes[i];
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final fg = isDark ? Colors.white : AppColors.primary(context);
                  return Material(
                    color: theme.cardTheme.color ??
                        theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => controller.removeLigne(i),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary(context).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${l.quantite}× ${l.nomComplet}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: fg.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _NoBoutique extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucune boutique disponible.\nCréez d\'abord une boutique active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.greyText(context, 600)),
            ),
          ],
        ),
      ),
    );
  }
}
