import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Demande le motif d'une annulation (vente, appro, …) avant de la lancer.
///
/// C'est un `StatefulWidget` et non un `AlertDialog` monté depuis un
/// controller, car son [TextEditingController] doit vivre aussi longtemps
/// que le champ. Créé dans un controller, il n'a plus de propriétaire : ou
/// bien on ne le dispose jamais — il fuit à chaque annulation —, ou bien on
/// le dispose au retour de `Get.dialog` et il est détruit pendant
/// l'animation de fermeture, alors que le `TextField` se reconstruit encore
/// (« A TextEditingController was used after being disposed »).
///
/// Ici le motif sort par la valeur de retour : l'appelant n'a plus de
/// controller à garder en vie.
class MotifAnnulationDialog extends StatefulWidget {
  /// Titre du dialogue : « Annuler la vente ? ».
  final String titre;

  /// Ce que l'annulation va produire, affiché au-dessus du champ.
  final String message;

  /// Libellé du bouton rouge : « Annuler la vente ».
  final String libelleConfirmer;

  const MotifAnnulationDialog({
    super.key,
    required this.titre,
    required this.message,
    required this.libelleConfirmer,
  });

  /// Ouvre le dialogue et renvoie le motif saisi, déjà nettoyé.
  ///
  /// Renvoie `null` si l'utilisateur renonce : le motif rendu n'est jamais
  /// vide, l'appelant n'a pas à le revérifier.
  static Future<String?> demander({
    required String titre,
    required String message,
    required String libelleConfirmer,
  }) {
    return Get.dialog<String>(
      MotifAnnulationDialog(
        titre: titre,
        message: message,
        libelleConfirmer: libelleConfirmer,
      ),
    );
  }

  @override
  State<MotifAnnulationDialog> createState() => _MotifAnnulationDialogState();
}

class _MotifAnnulationDialogState extends State<MotifAnnulationDialog> {
  final _motifCtrl = TextEditingController();

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  void _confirmer() {
    final motif = _motifCtrl.text.trim();
    if (motif.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Le motif est obligatoire',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    Get.back(result: motif);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _motifCtrl,
            decoration: const InputDecoration(
              labelText: 'Motif de l\'annulation *',
            ),
            autofocus: true,
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Garder'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _confirmer,
          child: Text(widget.libelleConfirmer),
        ),
      ],
    );
  }
}
