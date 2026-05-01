import 'package:cloud_firestore/cloud_firestore.dart';

class CategorieModel {
  final String id;
  final String nom;
  final String? description;
  final String? boutiqueId;
  final DateTime? createdAt;

  const CategorieModel({
    required this.id,
    required this.nom,
    this.description,
    this.boutiqueId,
    this.createdAt,
  });

  factory CategorieModel.fromMap(Map<String, dynamic> map, String id) {
    return CategorieModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      description: map['description'] as String?,
      boutiqueId: map['boutiqueId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory CategorieModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CategorieModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'description': description,
        'boutiqueId': boutiqueId,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  CategorieModel copyWith({
    String? nom,
    String? description,
    String? boutiqueId,
  }) {
    return CategorieModel(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      createdAt: createdAt,
    );
  }
}
