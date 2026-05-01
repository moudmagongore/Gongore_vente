import 'package:cloud_firestore/cloud_firestore.dart';

/// Stock d'un produit dans une boutique.
/// Document ID Firestore = "{boutiqueId}_{produitId}"
class StockModel {
  final String id;
  final String boutiqueId;
  final String produitId;
  final int quantite;
  final DateTime? derniereModif;

  const StockModel({
    required this.id,
    required this.boutiqueId,
    required this.produitId,
    required this.quantite,
    this.derniereModif,
  });

  static String buildId(String boutiqueId, String produitId) =>
      '${boutiqueId}_$produitId';

  factory StockModel.fromMap(Map<String, dynamic> map, String id) {
    return StockModel(
      id: id,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      produitId: (map['produitId'] ?? '') as String,
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      derniereModif: (map['derniereModif'] as Timestamp?)?.toDate(),
    );
  }

  factory StockModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return StockModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'boutiqueId': boutiqueId,
        'produitId': produitId,
        'quantite': quantite,
        'derniereModif': FieldValue.serverTimestamp(),
      };

  StockModel copyWith({int? quantite}) {
    return StockModel(
      id: id,
      boutiqueId: boutiqueId,
      produitId: produitId,
      quantite: quantite ?? this.quantite,
      derniereModif: DateTime.now(),
    );
  }
}
