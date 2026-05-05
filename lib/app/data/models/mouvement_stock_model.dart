import 'package:cloud_firestore/cloud_firestore.dart';

/// Type d'un mouvement de stock manuel.
enum MouvementStockType {
  /// Sortie (consommation interne, démonstration, échantillon).
  /// Décrémente le stock de [quantite].
  sortie,

  /// Entrée manuelle (don, retour client, correction positive).
  /// Incrémente le stock de [quantite]. À utiliser pour les entrées
  /// hors-appro (sinon préférer un appro pour conserver le CMUP).
  entree,

  /// Ajustement absolu : on FIXE la quantité finale (utile après
  /// inventaire physique). [quantite] représente la valeur cible.
  ajustement,

  /// Perte (vol, expiration, dégâts d'eau...). Décrémente.
  perte,

  /// Casse (produit endommagé, invendable). Décrémente.
  casse;

  static MouvementStockType fromString(String? value) {
    return MouvementStockType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MouvementStockType.sortie,
    );
  }

  String get label {
    switch (this) {
      case MouvementStockType.sortie:
        return 'Sortie';
      case MouvementStockType.entree:
        return 'Entrée';
      case MouvementStockType.ajustement:
        return 'Ajustement';
      case MouvementStockType.perte:
        return 'Perte';
      case MouvementStockType.casse:
        return 'Casse';
    }
  }

  /// Direction conceptuelle :
  /// `+1` ajoute au stock, `-1` retire, `0` (ajustement) = remplace
  /// la quantité par la valeur saisie.
  int get signe {
    switch (this) {
      case MouvementStockType.entree:
        return 1;
      case MouvementStockType.sortie:
      case MouvementStockType.perte:
      case MouvementStockType.casse:
        return -1;
      case MouvementStockType.ajustement:
        return 0;
    }
  }
}

/// Trace d'un mouvement de stock manuel (audit).
/// Les mouvements automatiques (vente / appro) ne passent PAS par cette
/// collection — ils sont reconstituables depuis `ventes` / `approvisionnements`.
class MouvementStockModel {
  final String id;
  final String produitId;
  /// Snapshot du nom au moment du mouvement.
  final String produitNom;

  /// Variante touchée (uniquement pour les produits à variantes).
  final String? varianteId;
  final String? varianteLibelle;

  final String boutiqueId;
  final String userId;

  final MouvementStockType type;

  /// Pour `sortie`/`entree`/`perte`/`casse` : nombre d'unités.
  /// Pour `ajustement` : nouvelle quantité cible (valeur absolue).
  final int quantite;

  /// Quantité avant le mouvement (snapshot pour audit). Quand le mouvement
  /// porte sur une variante, c'est le stock de la variante avant.
  final int qteAvant;
  /// Quantité après le mouvement (snapshot pour audit).
  final int qteApres;

  /// Motif libre saisi par l'utilisateur (recommandé pour perte/casse).
  final String? motif;

  final DateTime date;

  const MouvementStockModel({
    required this.id,
    required this.produitId,
    required this.produitNom,
    required this.boutiqueId,
    required this.userId,
    required this.type,
    required this.quantite,
    required this.qteAvant,
    required this.qteApres,
    required this.date,
    this.varianteId,
    this.varianteLibelle,
    this.motif,
  });

  /// Libellé combiné "Veste — 40" si variante, sinon "Veste".
  String get nomComplet =>
      varianteLibelle != null && varianteLibelle!.isNotEmpty
          ? '$produitNom — $varianteLibelle'
          : produitNom;

  factory MouvementStockModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return MouvementStockModel(
      id: id,
      produitId: (map['produitId'] ?? '') as String,
      produitNom: (map['produitNom'] ?? '') as String,
      varianteId: map['varianteId'] as String?,
      varianteLibelle: map['varianteLibelle'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      type: MouvementStockType.fromString(map['type'] as String?),
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      qteAvant: (map['qteAvant'] as num?)?.toInt() ?? 0,
      qteApres: (map['qteApres'] as num?)?.toInt() ?? 0,
      motif: map['motif'] as String?,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MouvementStockModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      MouvementStockModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'produitId': produitId,
        'produitNom': produitNom,
        if (varianteId != null) 'varianteId': varianteId,
        if (varianteLibelle != null) 'varianteLibelle': varianteLibelle,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'type': type.name,
        'quantite': quantite,
        'qteAvant': qteAvant,
        'qteApres': qteApres,
        'motif': motif,
        'date': Timestamp.fromDate(date),
      };

  /// Variation nette appliquée au stock (signée).
  int get delta => qteApres - qteAvant;
}
