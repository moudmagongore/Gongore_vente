import 'package:cloud_firestore/cloud_firestore.dart';

class ProduitModel {
  final String id;
  final String nom;
  final String? description;
  final String? codeBarre;
  final double prixAchat;
  final double prixVente;
  final String? categorieId;
  final String? unite;
  final String boutiqueId;
  final int seuilAlerte;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProduitModel({
    required this.id,
    required this.nom,
    required this.prixVente,
    required this.boutiqueId,
    this.description,
    this.codeBarre,
    this.prixAchat = 0,
    this.categorieId,
    this.unite,
    this.seuilAlerte = 5,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ProduitModel.fromMap(Map<String, dynamic> map, String id) {
    return ProduitModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      description: map['description'] as String?,
      codeBarre: map['codeBarre'] as String?,
      prixAchat: (map['prixAchat'] as num?)?.toDouble() ?? 0,
      prixVente: (map['prixVente'] as num?)?.toDouble() ?? 0,
      categorieId: map['categorieId'] as String?,
      unite: map['unite'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      seuilAlerte: (map['seuilAlerte'] as num?)?.toInt() ?? 5,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ProduitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProduitModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'description': description,
        'codeBarre': codeBarre,
        'prixAchat': prixAchat,
        'prixVente': prixVente,
        'categorieId': categorieId,
        'unite': unite,
        'boutiqueId': boutiqueId,
        'seuilAlerte': seuilAlerte,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  double get marge => prixVente - prixAchat;

  ProduitModel copyWith({
    String? nom,
    String? description,
    String? codeBarre,
    double? prixAchat,
    double? prixVente,
    String? categorieId,
    String? unite,
    String? boutiqueId,
    int? seuilAlerte,
    bool? active,
  }) {
    return ProduitModel(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      codeBarre: codeBarre ?? this.codeBarre,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      categorieId: categorieId ?? this.categorieId,
      unite: unite ?? this.unite,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      seuilAlerte: seuilAlerte ?? this.seuilAlerte,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
