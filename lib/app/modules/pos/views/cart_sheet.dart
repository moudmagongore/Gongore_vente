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
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Text(
                      'Panier',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Obx(() => controller.cart.isNotEmpty
                        ? TextButton.icon(
                            onPressed: () =>
                                _confirmClear(context, controller),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            label: const Text(
                              'Vider',
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        : const SizedBox.shrink()),
                    IconButton(
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('Panier vide',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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

class _LineTile extends StatelessWidget {
  final int index;
  const _LineTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PosController>();
    return Obx(() {
      if (index >= c.cart.length) return const SizedBox.shrink();
      final line = c.cart[index];
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.produit.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Fmt.money(line.prixUnitaire, currency: c.devise)} x ${line.quantite}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => c.removeLine(index),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // -
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    onTap: () => c.decrementLine(index),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${line.quantite}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    onTap: () => c.incrementLine(index),
                  ),
                  const Spacer(),
                  // Remise
                  TextButton.icon(
                    onPressed: () => _showRemiseSheet(context, c, index, line),
                    icon: Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: line.remise > 0
                          ? AppColors.success
                          : Colors.grey.shade600,
                    ),
                    label: Text(
                      line.remise > 0
                          ? '-${Fmt.money(line.remise, currency: c.devise)}'
                          : 'Remise',
                      style: TextStyle(
                        fontSize: 11,
                        color: line.remise > 0
                            ? AppColors.success
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                children: [
                  Text(
                    'Sous-total',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.money(line.sousTotal, currency: c.devise),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary,
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

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode paiement
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                children: ModePaiement.values
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m.label),
                          selected: controller.modePaiement.value == m,
                          onSelected: (_) => controller.modePaiement.value = m,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Remise globale
          _RemiseGlobaleField(controller: controller),
          const SizedBox(height: 14),
          // Totaux
          Obx(() => Column(
                children: [
                  _LineTotal(
                    label: 'Sous-total',
                    value: Fmt.money(controller.sousTotal,
                        currency: controller.devise),
                  ),
                  if (controller.remiseGlobale.value > 0)
                    _LineTotal(
                      label: 'Remise globale',
                      value: '-${Fmt.money(controller.remiseGlobale.value, currency: controller.devise)}',
                      color: AppColors.success,
                    ),
                  const Divider(),
                  _LineTotal(
                    label: 'TOTAL',
                    value: Fmt.money(controller.total,
                        currency: controller.devise),
                    big: true,
                  ),
                ],
              )),
          const SizedBox(height: 16),
          Obx(
            () => ElevatedButton.icon(
              onPressed: controller.isSaving.value || controller.cart.isEmpty
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
