import 'package:cloud_firestore/cloud_firestore.dart';

class FournisseurModel {
  final String id;
  final String nom;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String boutiqueId;

  /// Solde du fournisseur :
  /// - **positif** = on lui doit (dette à payer)
  /// - **négatif** = on a versé une avance à utiliser sur un prochain appro
  /// - **0** = à jour
  /// Maintenu atomiquement par [ApprovisionnementRepository.create] /
  /// `.cancel` et [ReglementFournisseurRepository.create] / `.deleteAndRestore`.
  final double solde;

  /// Drapeau dénormalisé : `true` dès le premier approvisionnement ou
  /// règlement fournisseur. Utilisé par les rules Firestore pour bloquer
  /// la suppression côté serveur d'un fournisseur avec historique.
  final bool hasOperations;

  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FournisseurModel({
    required this.id,
    required this.nom,
    required this.boutiqueId,
    this.telephone,
    this.email,
    this.adresse,
    this.solde = 0,
    this.hasOperations = false,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory FournisseurModel.fromMap(Map<String, dynamic> map, String id) {
    return FournisseurModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      adresse: map['adresse'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      solde: (map['solde'] as num?)?.toDouble() ?? 0,
      hasOperations: (map['hasOperations'] ?? false) as bool,
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory FournisseurModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      FournisseurModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'telephone': telephone,
        'email': email,
        'adresse': adresse,
        'boutiqueId': boutiqueId,
        'solde': solde,
        'hasOperations': hasOperations,
        'note': note,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  bool get aDette => solde > 0;
  bool get aAvance => solde < 0;

  FournisseurModel copyWith({
    String? nom,
    String? telephone,
    String? email,
    String? adresse,
    double? solde,
    String? note,
  }) {
    return FournisseurModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      boutiqueId: boutiqueId,
      solde: solde ?? this.solde,
      hasOperations: hasOperations,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
