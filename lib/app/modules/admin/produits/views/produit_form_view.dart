import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/produit_form_controller.dart';

class _AddLigneButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddLigneButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary(context).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppColors.primary(context)),
              SizedBox(width: 4),
              Text(
                'Ligne',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

class _VariantesEditor extends StatelessWidget {
  const _VariantesEditor();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ProduitFormController>();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : titre + sous-titre (total live) + bouton + Ligne
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pointures / variantes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _AddLigneButton(onTap: c.addVarianteLigne),
            ],
          ),
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Text(
                c.isEdit
                    ? 'Stock total : ${c.variantesTotalStock.value}. '
                        'Le stock d\'une variante existante n\'est modifiable '
                        'qu\'via les mouvements de stock, ventes et appros.'
                    : 'Stock initial par variante. '
                        'Total : ${c.variantesTotalStock.value}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText(context, 600),
                ),
              ),
            ),
          ),
          // Liste des lignes
          Obx(
            () {
              if (c.variantes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucune variante. Cliquez sur « + Ligne » pour en ajouter.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.greyText(context, 600)),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < c.variantes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _VarianteRow(index: i),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Champ avec un petit label texte au-dessus (au lieu d'un labelText flottant
/// qui surcharge visuellement les lignes de variantes).
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText(context, 700),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _VarianteRow extends StatelessWidget {
  final int index;
  const _VarianteRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ProduitFormController>();
    final v = c.variantes[index];
    // Variante déjà persistée que l'on édite : on verrouille le stock,
    // qui ne peut plus être modifié que via le module Stock (mouvement
    // tracé). Pour les nouvelles lignes (id vide) ou en création produit,
    // on garde un champ « Stock initial » éditable — exactement comme
    // pour un produit simple.
    final isExistingVariante = c.isEdit && v.id.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: _LabeledField(
              label: 'Libellé',
              child: TextFormField(
                controller: v.libelleCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _LabeledField(
              label: 'Couleur',
              child: TextFormField(
                controller: v.couleurCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            // Élargi à 78 pour que le libellé « Stock initial » tienne sur
            // une seule ligne (taille 11, ~72 px) sans déborder ni wrapper.
            width: isExistingVariante ? 56 : 78,
            child: _LabeledField(
              label: isExistingVariante ? 'Stock' : 'Stock initial',
              child: isExistingVariante
                  ? _ReadOnlyStock(value: v.stock)
                  : TextFormField(
                      controller: v.stockCtrl,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => c.onVarianteStockChanged(),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton(
              onPressed: () => c.removeVarianteLigne(index),
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.red,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              tooltip: 'Retirer',
            ),
          ),
        ],
      ),
    );
  }
}

/// Affichage en lecture seule du stock courant d'une variante existante.
/// Visuellement aligné avec les TextFormField voisins (même hauteur,
/// même bordure que la decoration `filled`).
class _ReadOnlyStock extends StatelessWidget {
  final int value;
  const _ReadOnlyStock({required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.greyText(context, 700),
        ),
      ),
    );
  }
}

class ProduitFormView extends GetView<ProduitFormController> {
  const ProduitFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.title))),
      body: androidOnlySafeArea(
        Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ============ Informations ============
              _SectionCard(
                icon: Icons.info_outline_rounded,
                title: 'Informations',
                children: [
                  _LabeledField(
                    label: 'Nom du produit *',
                    child: TextFormField(
                      controller: controller.nomCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: controller.validateNom,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'Description',
                    child: TextFormField(
                      controller: controller.descCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ============ Boutique & catégorie ============
              _SectionCard(
                icon: Icons.store_outlined,
                title: controller.canPickBoutique
                    ? 'Boutique & catégorie'
                    : 'Catégorie',
                children: [
                  if (controller.canPickBoutique)
                    Obx(() {
                      if (controller.boutiques.isEmpty) {
                        return _Warning(
                          'Aucune boutique active. Créez d\'abord une boutique.',
                        );
                      }
                      final safeBoutiqueId = controller.boutiques
                              .any((b) => b.id == controller.boutiqueId.value)
                          ? controller.boutiqueId.value
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField<String>(
                          initialValue: safeBoutiqueId,
                          decoration: const InputDecoration(
                            labelText: 'Boutique *',
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                          items: controller.boutiques
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.nom),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => controller.boutiqueId.value = v,
                          validator: controller.validateBoutique,
                        ),
                      );
                    }),
                  Obx(() {
                    final safeCategorieId = controller.categories.any(
                            (c) => c.id == controller.categorieId.value)
                        ? controller.categorieId.value
                        : null;
                    return DropdownButtonFormField<String?>(
                      initialValue: safeCategorieId,
                      decoration: const InputDecoration(
                        hintText: 'Catégorie',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Aucune catégorie'),
                        ),
                        ...controller.categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.nom),
                          ),
                        ),
                      ],
                      onChanged: (v) => controller.categorieId.value = v,
                    );
                  }),
                ],
              ),
              const SizedBox(height: 14),

              // ============ Prix ============
              _SectionCard(
                icon: Icons.payments_outlined,
                title: 'Prix',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Prix d\'achat',
                          child: TextFormField(
                            controller: controller.prixAchatCtrl,
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.shopping_cart_outlined),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            validator: controller.validatePrixAchat,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledField(
                          label: 'Prix de vente *',
                          child: TextFormField(
                            controller: controller.prixVenteCtrl,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            validator: controller.validatePrixVente,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ============ Stock & alerte ============
              _SectionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Stock & seuil d\'alerte',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final showStockInitial = !controller.isEdit &&
                            !controller.hasVariantes.value;
                        if (!showStockInitial) {
                          return const SizedBox.shrink();
                        }
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _LabeledField(
                              label: 'Stock initial',
                              child: TextFormField(
                                controller: controller.stockInitialCtrl,
                                decoration: const InputDecoration(
                                  prefixIcon:
                                      Icon(Icons.inventory_2_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      Expanded(
                        child: _LabeledField(
                          label: 'Seuil d\'alerte',
                          child: TextFormField(
                            controller: controller.seuilCtrl,
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.warning_amber_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: controller.validateSeuil,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ============ Variantes ============
              _ToggleCard(
                icon: Icons.style_rounded,
                title: 'Avec variantes',
                subtitle:
                    'Pointures, tailles, couleurs... avec leur propre stock.',
                valueGetter: () => controller.hasVariantes.value,
                onChanged: controller.toggleHasVariantes,
              ),
              Obx(
                () => controller.hasVariantes.value
                    ? const _VariantesEditor()
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),

              // ============ Statut ============
              _ToggleCard(
                icon: Icons.toggle_on_outlined,
                title: 'Produit actif',
                subtitle: 'Les produits inactifs ne sont pas vendables.',
                valueGetter: () => controller.active.value,
                onChanged: (v) => controller.active.value = v,
              ),
              const SizedBox(height: 28),

              // ============ Save ============
              Obx(
                () => SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        controller.isSaving.value ? null : controller.save,
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
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      controller.isEdit
                          ? 'Enregistrer les modifications'
                          : 'Créer le produit',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary(context),
                  side: BorderSide(
                      color: AppColors.primary(context), width: 1.4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte qui regroupe les champs d'une section avec un en-tête (icône +
/// titre). Contour discret, padding cohérent.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary(context)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Carte avec toggle (switch) à droite, icône + titre + sous-titre à gauche.
/// Plus propre que `SwitchListTile` brut.
class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool Function() valueGetter;
  final ValueChanged<bool> onChanged;
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueGetter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = valueGetter();
      return Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value
                    ? AppColors.primary(context).withValues(alpha: 0.45)
                    : AppColors.borderOf(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (value ? AppColors.primary(context) : Colors.grey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: value ? AppColors.primary(context) : AppColors.greyText(context, 600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText(context, 600),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _Warning extends StatelessWidget {
  final String message;
  const _Warning(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
