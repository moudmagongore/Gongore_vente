import 'package:cloud_firestore/cloud_firestore.dart';

enum MouvementType {
  entree,
  sortie,
  vente,
  transfert,
  ajustement,
  perte,
  casse;

  static MouvementType fromString(String? value) {
    return MouvementType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MouvementType.entree,
    );
  }

  String get label {
    switch (this) {
      case MouvementType.entree:
        return 'Entrée';
      case MouvementType.sortie:
        return 'Sortie';
      case MouvementType.vente:
        return 'Vente';
      case MouvementType.transfert:
        return 'Transfert';
      case MouvementType.ajustement:
        return 'Ajustement';
      case MouvementType.perte:
        return 'Perte';
      case MouvementType.casse:
        return 'Casse';
    }
  }

  /// Signe de la quantité appliqué au stock (+ = entrée, - = sortie).
  int get signe {
    switch (this) {
      case MouvementType.entree:
        return 1;
      case MouvementType.sortie:
      case MouvementType.vente:
      case MouvementType.perte:
      case MouvementType.casse:
        return -1;
      case MouvementType.transfert:
      case MouvementType.ajustement:
        return 0; // géré au cas par cas
    }
  }
}

class MouvementStockModel {
  final String id;
  final String produitId;
  final String boutiqueId;
  final MouvementType type;
  final int quantite;
  final DateTime date;
  final String userId;
  final String? motif;
  final String? boutiqueDestinationId; // pour les transferts
  final String? venteId; // pour les mouvements liés à une vente

  const MouvementStockModel({
    required this.id,
    required this.produitId,
    required this.boutiqueId,
    required this.type,
    required this.quantite,
    required this.date,
    required this.userId,
    this.motif,
    this.boutiqueDestinationId,
    this.venteId,
  });

  factory MouvementStockModel.fromMap(Map<String, dynamic> map, String id) {
    return MouvementStockModel(
      id: id,
      produitId: (map['produitId'] ?? '') as String,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      type: MouvementType.fromString(map['type'] as String?),
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: (map['userId'] ?? '') as String,
      motif: map['motif'] as String?,
      boutiqueDestinationId: map['boutiqueDestinationId'] as String?,
      venteId: map['venteId'] as String?,
    );
  }

  factory MouvementStockModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MouvementStockModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'produitId': produitId,
        'boutiqueId': boutiqueId,
        'type': type.name,
        'quantite': quantite,
        'date': Timestamp.fromDate(date),
        'userId': userId,
        'motif': motif,
        'boutiqueDestinationId': boutiqueDestinationId,
        'venteId': venteId,
      };
}
