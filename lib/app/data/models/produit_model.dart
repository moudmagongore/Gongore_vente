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
  /// (alerte visuelle dans la liste stock). Default 0 (pas d'alerte).
  ///
  /// Quand [hasVariantes] est true, ce seuil s'applique **par variante**
  /// (alerte si une variante < seuil), et non sur le total.
  final int seuilAlerte;

  /// Indique si le produit gère des variantes (pointures, tailles, ...).
  /// Quand true :
  /// - Les variantes sont en sous-collection `produits/{id}/variantes`
  /// - `quantiteStock` est un miroir maintenu par transactions = somme
  ///   des stocks des variantes.
  /// - Les ventes / appros / mouvements doivent référencer une variante.
  final bool hasVariantes;

  final bool active;

  /// Vrai dès qu'au moins UN approvisionnement a été enregistré sur ce
  /// produit. Posé par la transaction `ApprovisionnementRepository.create`
  /// et jamais remis à false (audit). Permet de verrouiller la saisie
  /// manuelle de `prixAchat` côté UI : une fois un appro passé, le CMUP
  /// est calculé automatiquement et toute modification manuelle
  /// corromprait la valorisation du stock.
  final bool hasAppros;

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
    this.quantiteStock = 0,
    this.seuilAlerte = 0,
    this.hasVariantes = false,
    this.active = true,
    this.hasAppros = false,
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
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      quantiteStock: (map['quantiteStock'] as num?)?.toInt() ?? 0,
      seuilAlerte: (map['seuilAlerte'] as num?)?.toInt() ?? 0,
      hasVariantes: (map['hasVariantes'] ?? false) as bool,
      active: (map['active'] ?? true) as bool,
      hasAppros: (map['hasAppros'] ?? false) as bool,
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
        'boutiqueId': boutiqueId,
        'quantiteStock': quantiteStock,
        'seuilAlerte': seuilAlerte,
        'hasVariantes': hasVariantes,
        'active': active,
        'hasAppros': hasAppros,
        // Le champ legacy `unite` n'est plus géré par l'app. Les anciens
        // documents Firestore qui en ont un seront ignorés à la lecture.
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
    String? boutiqueId,
    int? quantiteStock,
    int? seuilAlerte,
    bool? hasVariantes,
    bool? active,
    bool? hasAppros,
  }) {
    return ProduitModel(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      categorieId: categorieId ?? this.categorieId,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      quantiteStock: quantiteStock ?? this.quantiteStock,
      seuilAlerte: seuilAlerte ?? this.seuilAlerte,
      hasVariantes: hasVariantes ?? this.hasVariantes,
      active: active ?? this.active,
      hasAppros: hasAppros ?? this.hasAppros,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
