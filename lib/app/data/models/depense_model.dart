import 'package:cloud_firestore/cloud_firestore.dart';

import 'paiement_caisse.dart';

/// Dépense déclarée dans une boutique, rattachée à une nature de dépense
/// paramétrée par l'admin.
///
/// La [date] est posée automatiquement à la déclaration (horodatage de la
/// saisie) : l'utilisateur ne la choisit pas.
class DepenseModel {
  final String id;
  final String natureId;

  /// Snapshot du nom de la nature au moment de la déclaration. Dénormalisé
  /// volontairement : l'historique et les reçus restent lisibles même si
  /// la nature est renommée ou supprimée par la suite.
  final String natureNom;

  final double montant;

  /// Commentaire libre facultatif (référence de facture, précision...).
  final String? commentaire;

  /// Répartition du paiement sur les caisses (RG-10). Vide pour les
  /// dépenses déclarées avant le module de caisse, et pour les boutiques
  /// qui n'en ont pas encore (RG-9).
  ///
  /// Quand elle n'est pas vide, la somme des montants égale exactement
  /// [montant] (RG-15), et le [montant] n'est plus modifiable : l'argent
  /// est sorti des caisses.
  final List<PaiementCaisse> paiements;

  /// Vrai si la dépense a été payée depuis une ou plusieurs caisses.
  bool get estPayeeSurCaisse => paiements.isNotEmpty;

  final String boutiqueId;

  /// Auteur de la déclaration (admin ou gestionnaire).
  final String userId;

  final DateTime date;
  final DateTime? createdAt;

  const DepenseModel({
    required this.id,
    required this.natureId,
    required this.natureNom,
    required this.montant,
    required this.boutiqueId,
    required this.userId,
    required this.date,
    this.paiements = const [],
    this.commentaire,
    this.createdAt,
  });

  factory DepenseModel.fromMap(Map<String, dynamic> map, String id) {
    return DepenseModel(
      id: id,
      natureId: (map['natureId'] ?? '') as String,
      natureNom: (map['natureNom'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      commentaire: map['commentaire'] as String?,
      paiements: PaiementCaisse.listFromMap(map['paiements']),
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory DepenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      DepenseModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'natureId': natureId,
        'natureNom': natureNom,
        'montant': montant,
        'commentaire': commentaire,
        'paiements': paiements.map((p) => p.toMap()).toList(),
        'boutiqueId': boutiqueId,
        'userId': userId,
        'date': Timestamp.fromDate(date),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  DepenseModel copyWith({
    String? natureId,
    String? natureNom,
    double? montant,
    String? commentaire,
    List<PaiementCaisse>? paiements,
  }) {
    return DepenseModel(
      id: id,
      natureId: natureId ?? this.natureId,
      natureNom: natureNom ?? this.natureNom,
      montant: montant ?? this.montant,
      commentaire: commentaire ?? this.commentaire,
      paiements: paiements ?? this.paiements,
      boutiqueId: boutiqueId,
      userId: userId,
      date: date,
      createdAt: createdAt,
    );
  }
}
