import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String nom;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String boutiqueId;

  /// Solde du client : positif = il nous doit de l'argent (crédit en cours).
  /// Diminue lorsqu'il rembourse, augmente quand on lui vend à crédit.
  final double solde;

  /// Drapeau dénormalisé : passe à `true` à la première vente ou règlement
  /// du client, et ne revient jamais en arrière. Utilisé par les rules
  /// Firestore pour bloquer la suppression côté serveur (un client avec
  /// historique ne peut pas être effacé). Mis à jour atomiquement par
  /// les transactions de [VenteRepository.create] et
  /// [ReglementRepository.create].
  final bool hasOperations;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientModel({
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

  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    // Rétro-compat : ancien champ s'appelait 'dette'.
    final soldeRaw = map['solde'] ?? map['dette'];
    return ClientModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      adresse: map['adresse'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      solde: (soldeRaw as num?)?.toDouble() ?? 0,
      hasOperations: (map['hasOperations'] ?? false) as bool,
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
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
        'solde': solde,
        'hasOperations': hasOperations,
        'note': note,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  bool get aDette => solde > 0;

  ClientModel copyWith({
    String? nom,
    String? telephone,
    String? email,
    String? adresse,
    double? solde,
    String? note,
  }) {
    return ClientModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      boutiqueId: boutiqueId,
      solde: solde ?? this.solde,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
