import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String nom;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String boutiqueId;
  final double dette;
  final DateTime? createdAt;

  const ClientModel({
    required this.id,
    required this.nom,
    required this.boutiqueId,
    this.telephone,
    this.email,
    this.adresse,
    this.dette = 0,
    this.createdAt,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    return ClientModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      adresse: map['adresse'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      dette: (map['dette'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ClientModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ClientModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'telephone': telephone,
        'email': email,
        'adresse': adresse,
        'boutiqueId': boutiqueId,
        'dette': dette,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  ClientModel copyWith({
    String? nom,
    String? telephone,
    String? email,
    String? adresse,
    double? dette,
  }) {
    return ClientModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      boutiqueId: boutiqueId,
      dette: dette ?? this.dette,
      createdAt: createdAt,
    );
  }
}
