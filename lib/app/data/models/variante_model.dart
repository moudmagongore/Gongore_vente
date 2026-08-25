import 'package:cloud_firestore/cloud_firestore.dart';

/// Variante d'un produit (par ex. pointure 40, taille L, couleur rouge).
///
/// Stockée en sous-collection `produits/{produitId}/variantes/{varianteId}`.
/// - `libelle` : étiquette libre saisie par l'admin (ex. "40", "L", "Rouge").
/// - `stock` : quantité spécifique à cette variante. La somme des stocks
///   de toutes les variantes d'un produit est mirrorée dans
///   `produit.quantiteStock` par les transactions.
///
/// Le prix de vente, le prix d'achat (CMUP), la catégorie, etc. restent
/// portés par le produit parent — toutes les variantes les partagent.
class VarianteModel {
  final String id;
  final String libelle;

  /// Couleur facultative associée à la variante (ex. "Bleu", "Rouge").
  /// `null` ou vide = pas de précision couleur.
  final String? couleur;

  final int stock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VarianteModel({
    required this.id,
    required this.libelle,
    this.couleur,
    this.stock = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Libellé affichable : "40 (Bleu)" si couleur, sinon "40".
  String get libelleAffichage =>
      (couleur == null || couleur!.isEmpty) ? libelle : '$libelle ($couleur)';

  factory VarianteModel.fromMap(Map<String, dynamic> map, String id) {
    return VarianteModel(
      id: id,
      libelle: (map['libelle'] ?? '') as String,
      couleur: map['couleur'] as String?,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory VarianteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VarianteModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'libelle': libelle,
        if (couleur != null && couleur!.isNotEmpty) 'couleur': couleur,
        'stock': stock,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  VarianteModel copyWith({
    String? libelle,
    String? couleur,
    int? stock,
  }) {
    return VarianteModel(
      id: id,
      libelle: libelle ?? this.libelle,
      couleur: couleur ?? this.couleur,
      stock: stock ?? this.stock,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
