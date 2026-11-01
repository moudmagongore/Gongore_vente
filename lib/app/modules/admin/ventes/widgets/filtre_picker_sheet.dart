import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../theme/app_colors.dart';

/// Une entrée sélectionnable dans [FiltrePickerSheet].
class FiltreOption {
  final String id;
  final String nom;

  /// Ligne secondaire facultative (ex. la catégorie d'un produit).
  final String? sousTitre;

  const FiltreOption({required this.id, required this.nom, this.sousTitre});
}

/// Choix fait dans le sheet.
///
/// Un simple `String?` ne suffirait pas : `null` doit pouvoir signifier
/// « aucun filtre », ce qui serait indistinguable d'une fermeture sans
/// choisir. Ici, recevoir `null` = sheet fermé, rien ne change.
class FiltreChoix {
  /// `null` = option « tout » (pas de filtre).
  final String? id;
  const FiltreChoix(this.id);
}

/// Sélecteur de filtre avec recherche, présenté en bottom sheet.
///
/// Remplace un `DropdownButtonFormField` dès que la liste peut être longue :
/// une liste déroulante native de plusieurs centaines de produits est
/// impraticable au doigt.
class FiltrePickerSheet extends StatefulWidget {
  final String titre;
  final String hintRecherche;

  /// Libellé de l'option « pas de filtre » (ex. « Tous les produits »).
  final String labelTout;
  final List<FiltreOption> options;
  final String? selection;

  const FiltrePickerSheet({
    super.key,
    required this.titre,
    required this.hintRecherche,
    required this.labelTout,
    required this.options,
    this.selection,
  });

  /// Ouvre le sheet. Renvoie `null` si l'utilisateur l'a fermé sans choisir.
  static Future<FiltreChoix?> open({
    required String titre,
    required String hintRecherche,
    required String labelTout,
    required List<FiltreOption> options,
    String? selection,
  }) {
    return Get.bottomSheet<FiltreChoix>(
      FiltrePickerSheet(
        titre: titre,
        hintRecherche: hintRecherche,
        labelTout: labelTout,
        options: options,
        selection: selection,
      ),
      isScrollControlled: true,
      backgroundColor: Get.theme.cardTheme.color,
    );
  }

  @override
  State<FiltrePickerSheet> createState() => _FiltrePickerSheetState();
}

class _FiltrePickerSheetState extends State<FiltrePickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FiltreOption> get _resultats {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) =>
            o.nom.toLowerCase().contains(q) ||
            (o.sousTitre?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    // Plafond sur la hauteur VISIBLE : le sheet ne déborde pas par le haut
    // quand le clavier de recherche s'ouvre.
    final maxH = (mq.size.height - viewInsets) * kBottomSheetMaxHeightRatio;
    final resultats = _resultats;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: androidOnlySafeArea(
          Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.titre,
                        style: const TextStyle(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: _searchCtrl,
                  // Pas d'autofocus : le clavier masquerait d'emblée la
                  // liste, alors que le choix se fait le plus souvent en
                  // la parcourant. On le laisse s'ouvrir au tap.
                  decoration: InputDecoration(
                    hintText: widget.hintRecherche,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    _OptionTile(
                      nom: widget.labelTout,
                      selectionne: widget.selection == null,
                      onTap: () => Get.back(result: const FiltreChoix(null)),
                    ),
                    const Divider(height: 1),
                    if (resultats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Aucun résultat',
                            style: TextStyle(
                                color: AppColors.greyText(context, 600)),
                          ),
                        ),
                      )
                    else
                      ...resultats.map(
                        (o) => _OptionTile(
                          nom: o.nom,
                          sousTitre: o.sousTitre,
                          selectionne: o.id == widget.selection,
                          onTap: () => Get.back(result: FiltreChoix(o.id)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String nom;
  final String? sousTitre;
  final bool selectionne;
  final VoidCallback onTap;

  const _OptionTile({
    required this.nom,
    required this.selectionne,
    required this.onTap,
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final actif = AppColors.primary(context);
    return ListTile(
      dense: true,
      title: Text(
        nom,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
          color: selectionne ? actif : null,
        ),
      ),
      subtitle: (sousTitre?.isNotEmpty ?? false)
          ? Text(
              sousTitre!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.greyText(context, 600),
              ),
            )
          : null,
      trailing: selectionne ? Icon(Icons.check_rounded, color: actif) : null,
      onTap: onTap,
    );
  }
}
