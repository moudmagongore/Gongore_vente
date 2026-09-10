import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/repositories/maintenance_repository.dart';
import '../../../../theme/app_colors.dart';

/// Confirmation d'une purge : exige de recopier le nom exact de la boutique.
///
/// C'est un `StatefulWidget` et non un dialogue monté depuis le controller,
/// car son [TextEditingController] doit vivre aussi longtemps que le widget.
/// Le disposer dès que `Get.dialog` rend la main le détruit pendant
/// l'animation de fermeture, alors que le `TextField` se reconstruit encore
/// (« A TextEditingController was used after being disposed »).
class ConfirmPurgeDialog extends StatefulWidget {
  final String boutiqueNom;
  final PurgeCible cible;
  final int nbDocuments;

  const ConfirmPurgeDialog({
    super.key,
    required this.boutiqueNom,
    required this.cible,
    required this.nbDocuments,
  });

  /// Ouvre le dialogue. Renvoie `true` seulement si l'utilisateur a recopié
  /// le nom de la boutique puis confirmé.
  static Future<bool> show({
    required String boutiqueNom,
    required PurgeCible cible,
    required int nbDocuments,
  }) async {
    final ok = await Get.dialog<bool>(
      ConfirmPurgeDialog(
        boutiqueNom: boutiqueNom,
        cible: cible,
        nbDocuments: nbDocuments,
      ),
      barrierDismissible: false,
    );
    return ok == true;
  }

  @override
  State<ConfirmPurgeDialog> createState() => _ConfirmPurgeDialogState();
}

class _ConfirmPurgeDialogState extends State<ConfirmPurgeDialog> {
  final _saisieCtrl = TextEditingController();
  bool _valide = false;

  @override
  void dispose() {
    _saisieCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final valide = v.trim() == widget.boutiqueNom.trim();
    if (valide != _valide) setState(() => _valide = valide);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text('Suppression définitive')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez supprimer ${widget.nbDocuments} document(s) : '
              '${widget.cible.label.toLowerCase()} de la boutique '
              '« ${widget.boutiqueNom} ».',
            ),
            const SizedBox(height: 8),
            Text(
              widget.cible.consequence,
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Firestore n\'a pas de corbeille : cette opération est '
              'irréversible.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pour confirmer, recopiez le nom de la boutique :',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.greyText(context, 700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _saisieCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.boutiqueNom,
                isDense: true,
              ),
              onChanged: _onChanged,
              onSubmitted: (_) {
                if (_valide) Get.back(result: true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Annuler'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _valide ? () => Get.back(result: true) : null,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}
