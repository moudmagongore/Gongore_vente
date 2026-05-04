import 'package:cloud_firestore/cloud_firestore.dart';

class ProduitModel {
  final String id;
  final String nom;
  final String? description;

  /// Coût d'achat unitaire. Mis à jour automatiquement à chaque
  /// approvisionnement via la formule du **Coût Moyen Unitaire Pondéré**
  /// (CMUP) :
  ///
  /// ```
  /// nouveau_PA = (qte_actuelle × PA_actuel + qte_appro × PA_appro)
  ///            / (qte_actuelle + qte_appro)
  /// ```
  ///
  /// Ne pas l'éditer à la main si vous voulez que la valorisation reste
  /// cohérente : la modification manuelle écrase le CMUP calculé.
  final double prixAchat;
  final double prixVente;
  final String? categorieId;
  final String? unite;
  final String boutiqueId;

  /// Quantité actuellement en stock dans la boutique. Maintenue
  /// atomiquement par les transactions :
  /// - VenteRepository.create / cancel
  /// - ApprovisionnementRepository.create / cancel
  /// - MouvementStockRepository.create
  /// Ne PAS modifier directement (risque de désynchronisation avec
  /// l'historique des opérations).
  final int quantiteStock;

  /// Seuil en-dessous duquel le produit est considéré comme « stock bas »
  /// (alerte visuelle dans la liste stock). Default 5.
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
    this.prixAchat = 0,
    this.categorieId,
    this.unite,
    this.quantiteStock = 0,
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
      prixAchat: (map['prixAchat'] as num?)?.toDouble() ?? 0,
      prixVente: (map['prixVente'] as num?)?.toDouble() ?? 0,
      categorieId: map['categorieId'] as String?,
      unite: map['unite'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      quantiteStock: (map['quantiteStock'] as num?)?.toInt() ?? 0,
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
        'prixAchat': prixAchat,
        'prixVente': prixVente,
        'categorieId': categorieId,
        'unite': unite,
        'boutiqueId': boutiqueId,
        'quantiteStock': quantiteStock,
        'seuilAlerte': seuilAlerte,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  double get marge => prixVente - prixAchat;

  /// Valeur du stock courant au prix d'achat (CMUP).
  double get valeurStock => quantiteStock * prixAchat;

  ProduitModel copyWith({
    String? nom,
    String? description,
    double? prixAchat,
    double? prixVente,
    String? categorieId,
    String? unite,
    String? boutiqueId,
    int? quantiteStock,
    int? seuilAlerte,
    bool? active,
  }) {
    return ProduitModel(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      categorieId: categorieId ?? this.categorieId,
      unite: unite ?? this.unite,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      quantiteStock: quantiteStock ?? this.quantiteStock,
      seuilAlerte: seuilAlerte ?? this.seuilAlerte,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
