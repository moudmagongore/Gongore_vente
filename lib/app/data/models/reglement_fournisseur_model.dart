import 'package:cloud_firestore/cloud_firestore.dart';

import 'vente_model.dart' show ModePaiement;

/// Trace d'une imputation d'un règlement fournisseur sur une appro
/// précédemment en crédit. Permet l'inversion atomique en cas de
/// suppression du règlement.
class ImputationFournisseur {
  final String approId;
  /// Snapshot du numéro lisible de l'appro (préserve l'affichage offline).
  final String? numero;
  final double montant;

  const ImputationFournisseur({
    required this.approId,
    required this.montant,
    this.numero,
  });

  factory ImputationFournisseur.fromMap(Map<String, dynamic> map) =>
      ImputationFournisseur(
        approId: (map['approId'] ?? '') as String,
        numero: map['numero'] as String?,
        montant: (map['montant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'approId': approId,
        if (numero != null) 'numero': numero,
        'montant': montant,
      };
}

/// Règlement versé à un fournisseur en dehors d'un appro.
/// Diminue le solde du fournisseur de [montant] (atomique).
/// Le montant est imputé en FIFO sur les approvisionnements en crédit ;
/// chaque imputation est tracée dans [imputations] pour permettre
/// l'inversion en cas de suppression.
class ReglementFournisseurModel {
  final String id;
  final String fournisseurId;
  final String boutiqueId;
  final String userId;

  /// Montant versé (toujours positif).
  final double montant;
  final ModePaiement modePaiement;

  final DateTime date;
  final String? note;

  /// Imputations FIFO sur les appros en crédit (renseignées à la création
  /// par [ReglementFournisseurRepository.create]). Le total des imputations
  /// peut être inférieur à [montant] : le surplus va en avance fournisseur
  /// (solde négatif).
  final List<ImputationFournisseur> imputations;

  const ReglementFournisseurModel({
    required this.id,
    required this.fournisseurId,
    required this.boutiqueId,
    required this.userId,
    required this.montant,
    required this.modePaiement,
    required this.date,
    this.note,
    this.imputations = const [],
  });

  factory ReglementFournisseurModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final raw = (map['imputations'] as List?) ?? const [];
    return ReglementFournisseurModel(
      id: id,
      fournisseurId: (map['fournisseurId'] ?? '') as String,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      modePaiement: ModePaiement.fromString(map['modePaiement'] as String?),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      imputations: raw
          .map((e) => ImputationFournisseur.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  factory ReglementFournisseurModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ReglementFournisseurModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'fournisseurId': fournisseurId,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'montant': montant,
        'modePaiement': modePaiement.name,
        'date': Timestamp.fromDate(date),
        'note': note,
        'imputations': imputations.map((i) => i.toMap()).toList(),
      };

  /// Total réellement imputé sur des appros (peut être < montant si surplus).
  double get totalImpute =>
      imputations.fold(0.0, (acc, i) => acc + i.montant);

  /// Surplus (avance versée au fournisseur) après imputation FIFO.
  double get surplus => montant - totalImpute;
}
