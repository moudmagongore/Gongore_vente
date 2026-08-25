import 'package:cloud_firestore/cloud_firestore.dart';

import 'vente_model.dart' show ModePaiement;

enum ApproStatut {
  validee,
  annulee;

  static ApproStatut fromString(String? value) {
    return ApproStatut.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ApproStatut.validee,
    );
  }

  String get label {
    switch (this) {
      case ApproStatut.validee:
        return 'Validée';
      case ApproStatut.annulee:
        return 'Annulée';
    }
  }
}

/// Une ligne d'approvisionnement : un produit reçu en quantité donnée
/// au prix d'achat unitaire facturé par le fournisseur.
class ApproArticle {
  final String produitId;
  /// Snapshot du nom au moment de l'appro (préserve l'historique même
  /// si le produit est renommé ou supprimé).
  final String nom;

  /// Variante reçue (uniquement si le produit a `hasVariantes`).
  final String? varianteId;
  final String? varianteLibelle;

  final int quantite;
  final double prixAchatUnitaire;

  const ApproArticle({
    required this.produitId,
    required this.nom,
    required this.quantite,
    required this.prixAchatUnitaire,
    this.varianteId,
    this.varianteLibelle,
  });

  double get sousTotal => prixAchatUnitaire * quantite;

  /// Libellé combiné "Veste — 40" si variante, sinon "Veste".
  String get nomComplet => varianteLibelle != null && varianteLibelle!.isNotEmpty
      ? '$nom — $varianteLibelle'
      : nom;

  factory ApproArticle.fromMap(Map<String, dynamic> map) {
    return ApproArticle(
      produitId: (map['produitId'] ?? '') as String,
      nom: (map['nom'] ?? '') as String,
      varianteId: map['varianteId'] as String?,
      varianteLibelle: map['varianteLibelle'] as String?,
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      prixAchatUnitaire:
          (map['prixAchatUnitaire'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'produitId': produitId,
        'nom': nom,
        if (varianteId != null) 'varianteId': varianteId,
        if (varianteLibelle != null) 'varianteLibelle': varianteLibelle,
        'quantite': quantite,
        'prixAchatUnitaire': prixAchatUnitaire,
      };
}

/// Bon d'approvisionnement (réception de marchandises chez un fournisseur).
/// La création est atomique : met à jour le stock + recalcule le CMUP des
/// produits + crée la dette fournisseur.
class ApprovisionnementModel {
  final String id;

  /// Numéro lisible séquentiel par boutique, format `A-AAAA-NNNNN`,
  /// généré atomiquement à la création.
  final String? numero;

  final String boutiqueId;
  final String userId;
  final String fournisseurId;

  final List<ApproArticle> articles;

  /// Tableau dénormalisé des produitId présents dans `articles`,
  /// pour permettre une query Firestore efficace
  /// `where('articleProduitIds', arrayContains: pid)` (suppression produit).
  final List<String> articleProduitIds;

  /// Total brut = somme des sousTotal lignes.
  final double sousTotal;
  /// Remise globale accordée par le fournisseur (si négociation).
  final double remise;
  /// Total à payer = sousTotal - remise.
  final double total;

  /// Montant payé au comptant à la réception (cash).
  final double montantPaye;
  /// Avance fournisseur consommée pour cette appro (puise sur solde négatif).
  final double avanceUtilisee;

  final ModePaiement modePaiement;
  final ApproStatut statut;
  final DateTime date;
  final String? note;
  final String? motifAnnulation;

  const ApprovisionnementModel({
    required this.id,
    required this.boutiqueId,
    required this.userId,
    required this.fournisseurId,
    required this.articles,
    required this.sousTotal,
    required this.total,
    required this.montantPaye,
    required this.modePaiement,
    required this.date,
    this.numero,
    this.articleProduitIds = const [],
    this.remise = 0,
    this.avanceUtilisee = 0,
    this.statut = ApproStatut.validee,
    this.note,
    this.motifAnnulation,
  });

  factory ApprovisionnementModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final raw = (map['articles'] as List?) ?? const [];
    final total = (map['total'] as num?)?.toDouble() ?? 0;
    return ApprovisionnementModel(
      id: id,
      numero: map['numero'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      fournisseurId: (map['fournisseurId'] ?? '') as String,
      articles: raw
          .map((e) => ApproArticle.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      articleProduitIds: ((map['articleProduitIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      sousTotal: (map['sousTotal'] as num?)?.toDouble() ?? 0,
      remise: (map['remise'] as num?)?.toDouble() ?? 0,
      total: total,
      montantPaye: (map['montantPaye'] as num?)?.toDouble() ?? 0,
      avanceUtilisee: (map['avanceUtilisee'] as num?)?.toDouble() ?? 0,
      modePaiement: ModePaiement.fromString(map['modePaiement'] as String?),
      statut: ApproStatut.fromString(map['statut'] as String?),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      motifAnnulation: map['motifAnnulation'] as String?,
    );
  }

  factory ApprovisionnementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ApprovisionnementModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'fournisseurId': fournisseurId,
        'articles': articles.map((a) => a.toMap()).toList(),
        'articleProduitIds':
            articles.map((a) => a.produitId).toSet().toList(),
        'sousTotal': sousTotal,
        'remise': remise,
        'total': total,
        'montantPaye': montantPaye,
        'avanceUtilisee': avanceUtilisee,
        'modePaiement': modePaiement.name,
        'statut': statut.name,
        'date': Timestamp.fromDate(date),
        'note': note,
        'motifAnnulation': motifAnnulation,
      };

  /// Numéro affichable : utilise `numero` si présent, sinon les 8 premiers
  /// caractères de l'ID Firestore.
  String get numeroAffichage {
    if (numero != null && numero!.isNotEmpty) return numero!;
    if (id.isEmpty) return '—';
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
  }

  /// Reste dû au fournisseur après cette appro
  /// (positif = dette, négatif = trop-versé / avance créée).
  double get resteAPayer => total - montantPaye - avanceUtilisee;

  int get nbArticles => articles.fold(0, (acc, a) => acc + a.quantite);
}
