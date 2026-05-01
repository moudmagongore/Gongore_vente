import 'package:cloud_firestore/cloud_firestore.dart';

class BoutiqueModel {
  final String id;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? logoUrl;
  final String devise;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BoutiqueModel({
    required this.id,
    required this.nom,
    this.adresse,
    this.telephone,
    this.logoUrl,
    this.devise = 'GNF',
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BoutiqueModel.fromMap(Map<String, dynamic> map, String id) {
    return BoutiqueModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      adresse: map['adresse'] as String?,
      telephone: map['telephone'] as String?,
      logoUrl: map['logoUrl'] as String?,
      devise: (map['devise'] ?? 'GNF') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory BoutiqueModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return BoutiqueModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'adresse': adresse,
        'telephone': telephone,
        'logoUrl': logoUrl,
        'devise': devise,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  BoutiqueModel copyWith({
    String? nom,
    String? adresse,
    String? telephone,
    String? logoUrl,
    String? devise,
    bool? active,
  }) {
    return BoutiqueModel(
      id: id,
      nom: nom ?? this.nom,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      logoUrl: logoUrl ?? this.logoUrl,
      devise: devise ?? this.devise,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
