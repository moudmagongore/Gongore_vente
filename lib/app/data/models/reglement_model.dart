import 'package:cloud_firestore/cloud_firestore.dart';

import 'vente_model.dart';

/// Trace d'une imputation : « ce règlement a couvert X sur la vente Y ».
/// Permet l'inversion atomique en cas de suppression du règlement.
class Imputation {
  final String venteId;
  /// Numéro affichable de la vente (snapshot pour affichage offline).
  final String? numero;
  final double montant;

  const Imputation({
    required this.venteId,
    required this.montant,
    this.numero,
  });

  factory Imputation.fromMap(Map<String, dynamic> map) => Imputation(
        venteId: (map['venteId'] ?? '') as String,
        numero: map['numero'] as String?,
        montant: (map['montant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'venteId': venteId,
        if (numero != null) 'numero': numero,
        'montant': montant,
      };
}

/// Règlement de dette d'un client : entrée d'argent en dehors d'une vente.
/// Diminue le solde du client de [montant] (atomique côté repository).
/// Le montant est imputé en FIFO sur les ventes en crédit du client ;
/// chaque imputation est tracée dans [imputations] pour permettre l'inversion
/// en cas de suppression du règlement.
class ReglementModel {
  final String id;
  final String clientId;
  final String boutiqueId;
  final String userId;

  /// Montant encaissé (toujours positif).
  final double montant;

  /// Mode utilisé pour ce règlement (Espèces / Mobile Money / etc).
  final ModePaiement modePaiement;

  final DateTime date;
  final String? note;

  /// Imputations FIFO sur les ventes en crédit (renseignées à la création
  /// par [ReglementRepository.create]). Le total des imputations peut être
  /// inférieur à [montant] : le surplus va en avance (solde négatif).
  final List<Imputation> imputations;

  const ReglementModel({
    required this.id,
    required this.clientId,
    required this.boutiqueId,
    required this.userId,
    required this.montant,
    required this.modePaiement,
    required this.date,
    this.note,
    this.imputations = const [],
  });

  factory ReglementModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = (map['imputations'] as List?) ?? const [];
    return ReglementModel(
      id: id,
      clientId: (map['clientId'] ?? '') as String,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      modePaiement: ModePaiement.fromString(map['modePaiement'] as String?),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      imputations: raw
          .map((e) => Imputation.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory ReglementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ReglementModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'montant': montant,
        'modePaiement': modePaiement.name,
        'date': Timestamp.fromDate(date),
        'note': note,
        'imputations': imputations.map((i) => i.toMap()).toList(),
      };

  /// Total réellement imputé sur des ventes (peut être < montant si surplus).
  double get totalImpute =>
      imputations.fold(0.0, (acc, i) => acc + i.montant);

  /// Surplus (avance) déposé sur le solde après imputation FIFO.
  double get surplus => montant - totalImpute;
}
