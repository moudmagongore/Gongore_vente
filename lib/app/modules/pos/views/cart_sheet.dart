import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../data/models/vente_model.dart';
import '../../../theme/app_colors.dart';
import '../controllers/pos_controller.dart';

class CartSheet extends GetView<PosController> {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Mon panier',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Obx(() => Text(
                                controller.cart.isEmpty
                                    ? 'Aucun article'
                                    : '${controller.cart.length} produit'
                                        '${controller.cart.length > 1 ? 's' : ''}'
                                        ' · ${controller.nbArticles} article'
                                        '${controller.nbArticles > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )),
                        ],
                      ),
                    ),
                    Obx(() => controller.cart.isNotEmpty
                        ? IconButton(
                            tooltip: 'Vider le panier',
                            onPressed: () =>
                                _confirmClear(context, controller),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                          )
                        : const SizedBox.shrink()),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste articles
              Expanded(
                child: Obx(() {
                  if (controller.cart.isEmpty) {
                    return _EmptyCart();
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _LineTile(index: i),
                  );
                }),
              ),
              // Bas: paiement + total + valider
              const Divider(height: 1),
              _CheckoutSection(controller: controller),
            ],
          ),
        );
      },
    );
  }

  void _confirmClear(BuildContext context, PosController c) {
    Get.dialog(
      AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront retirés.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              c.clearCart();
              Get.back();
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Votre panier est vide',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sélectionnez un produit pour commencer une vente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final int index;
  const _LineTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PosController>();
    return Obx(() {
      if (index >= c.cart.length) return const SizedBox.shrink();
      final line = c.cart[index];
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            // Ligne 1 : nom + sous-total + close
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.produit.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.money(line.prixUnitaire, currency: c.devise)} '
                        'l\'unité',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
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
                      Fmt.money(line.sousTotal, currency: c.devise),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (line.remise > 0)
                      Text(
                        '-${Fmt.money(line.remise, currency: c.devise)}',
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
                      size: 18, color: Colors.grey.shade500),
                  onPressed: () => c.removeLine(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Ligne 2 : stepper groupé + remise
            Row(
              children: [
                _QtyStepper(
                  quantite: line.quantite,
                  onMinus: () => c.decrementLine(index),
                  onPlus: () => c.incrementLine(index),
                ),
                const Spacer(),
                _RemiseChip(
                  active: line.remise > 0,
                  onTap: () => _showRemiseSheet(context, c, index, line),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showRemiseSheet(
    BuildContext context,
    PosController c,
    int index,
    CartLine line,
  ) {
    final montantCtrl =
        TextEditingController(text: line.remise == 0 ? '' : line.remise.toStringAsFixed(0));
    final pourcentCtrl = TextEditingController();

    Get.bottomSheet(
      SafeArea(
        bottom: false,
        child: Container(
          color: Theme.of(context).cardTheme.color,
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remise sur « ${line.produit.nom} »',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Sous-total brut : ${Fmt.money(line.sousTotalBrut, currency: c.devise)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montantCtrl,
                decoration: InputDecoration(
                  labelText: 'Montant fixe (${c.devise})',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onSubmitted: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  c.setLineRemise(index, n);
                  Get.back();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pourcentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pourcentage (%)',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onSubmitted: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  c.setLineRemisePourcent(index, n);
                  Get.back();
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        c.setLineRemise(index, 0);
                        Get.back();
                      },
                      child: const Text('Retirer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Priorité au montant si saisi, sinon au pourcent
                        final m = double.tryParse(
                            montantCtrl.text.replaceAll(',', '.'));
                        final p = double.tryParse(
                            pourcentCtrl.text.replaceAll(',', '.'));
                        if (m != null) {
                          c.setLineRemise(index, m);
                        } else if (p != null) {
                          c.setLineRemisePourcent(index, p);
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

/// Stepper compact -|N|+ groupé dans une pilule pour les lignes du panier.
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
        color: AppColors.primary.withValues(alpha: 0.08),
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
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.primary,
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
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Chip pour ajouter/afficher une remise sur une ligne du panier.
class _RemiseChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _RemiseChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : Colors.grey.shade600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.success.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? AppColors.success.withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.local_offer_rounded
                    : Icons.local_offer_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'Remise appliquée' : 'Ajouter remise',
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

class _CheckoutSection extends StatelessWidget {
  final PosController controller;
  const _CheckoutSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode paiement
          Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(() {
                final current = controller.modePaiement.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < ModePaiement.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _PaiementPill(
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
          const SizedBox(height: 16),
          _RemiseGlobaleField(controller: controller),
          const SizedBox(height: 14),
          // Totaux dans une carte bordurée
          Obx(() => Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _LineTotal(
                      label: 'Sous-total',
                      value: Fmt.money(controller.sousTotal,
                          currency: controller.devise),
                    ),
                    if (controller.remiseGlobale.value > 0) ...[
                      const SizedBox(height: 4),
                      _LineTotal(
                        label: 'Remise globale',
                        value:
                            '-${Fmt.money(controller.remiseGlobale.value, currency: controller.devise)}',
                        color: AppColors.success,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    _LineTotal(
                      label: 'TOTAL',
                      value: Fmt.money(controller.total,
                          currency: controller.devise),
                      big: true,
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          Obx(
            () => ElevatedButton.icon(
              onPressed:
                  controller.isSaving.value || controller.cart.isEmpty
                      ? null
                      : controller.validerVente,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(56),
              ),
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                controller.isSaving.value
                    ? 'Validation...'
                    : 'Valider la vente',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaiementPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaiementPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedText =
        isDark ? Colors.grey.shade300 : AppColors.lightText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).dividerColor,
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

class _RemiseGlobaleField extends StatefulWidget {
  final PosController controller;
  const _RemiseGlobaleField({required this.controller});

  @override
  State<_RemiseGlobaleField> createState() => _RemiseGlobaleFieldState();
}

class _RemiseGlobaleFieldState extends State<_RemiseGlobaleField> {
  late final TextEditingController _txt;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.remiseGlobale.value;
    _txt = TextEditingController(
      text: initial == 0 ? '' : initial.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.local_offer_outlined, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        const Text('Remise globale', style: TextStyle(fontSize: 13)),
        const Spacer(),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _txt,
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              suffixText: widget.controller.devise,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.end,
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              widget.controller.remiseGlobale.value =
                  n.clamp(0, widget.controller.sousTotal);
            },
          ),
        ),
      ],
    );
  }
}

class _LineTotal extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? color;

  const _LineTotal({
    required this.label,
    required this.value,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: big ? 16 : 13,
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 22 : 14,
              fontWeight: big ? FontWeight.w800 : FontWeight.w600,
              color: color ?? (big ? AppColors.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
