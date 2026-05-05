import 'package:cloud_firestore/cloud_firestore.dart';

enum ModePaiement {
  especes,
  orangeMoney,
  mobileMoney,
  paycard;

  static ModePaiement fromString(String? value) {
    // Alias rétro-compat pour les ventes déjà en base.
    switch (value) {
      case 'carte':
      case 'credit':
        return ModePaiement.paycard;
    }
    return ModePaiement.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ModePaiement.especes,
    );
  }

  String get label {
    switch (this) {
      case ModePaiement.especes:
        return 'Espèces';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
      case ModePaiement.mobileMoney:
        return 'Mobile Money';
      case ModePaiement.paycard:
        return 'Paycard';
    }
  }
}

enum VenteStatut {
  validee,
  annulee,
  enAttente;

  static VenteStatut fromString(String? value) {
    return VenteStatut.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VenteStatut.validee,
    );
  }

  String get label {
    switch (this) {
      case VenteStatut.validee:
        return 'Validée';
      case VenteStatut.annulee:
        return 'Annulée';
      case VenteStatut.enAttente:
        return 'En attente';
    }
  }
}

class VenteArticle {
  final String produitId;
  final String nom;

  /// Id de la variante (sous-collection `produits/{pid}/variantes/{vid}`)
  /// quand le produit gère des variantes. `null` pour les produits simples.
  final String? varianteId;

  /// Libellé snapshot de la variante au moment de la vente (ex. "40").
  /// Conservé même si la variante est renommée / supprimée plus tard,
  /// pour que l'historique reste lisible.
  final String? varianteLibelle;

  final int quantite;
  final double prixUnitaire;
  final double remise;

  const VenteArticle({
    required this.produitId,
    required this.nom,
    required this.quantite,
    required this.prixUnitaire,
    this.varianteId,
    this.varianteLibelle,
    this.remise = 0,
  });

  double get sousTotal => (prixUnitaire * quantite) - remise;

  /// Libellé pour affichage : "Veste — 40" si variante, sinon "Veste".
  String get nomComplet => varianteLibelle != null && varianteLibelle!.isNotEmpty
      ? '$nom — $varianteLibelle'
      : nom;

  factory VenteArticle.fromMap(Map<String, dynamic> map) {
    return VenteArticle(
      produitId: (map['produitId'] ?? '') as String,
      nom: (map['nom'] ?? '') as String,
      varianteId: map['varianteId'] as String?,
      varianteLibelle: map['varianteLibelle'] as String?,
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      prixUnitaire: (map['prixUnitaire'] as num?)?.toDouble() ?? 0,
      remise: (map['remise'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'produitId': produitId,
        'nom': nom,
        if (varianteId != null) 'varianteId': varianteId,
        if (varianteLibelle != null) 'varianteLibelle': varianteLibelle,
        'quantite': quantite,
        'prixUnitaire': prixUnitaire,
        'remise': remise,
      };
}

class VenteModel {
  final String id;

  /// Numéro lisible séquentiel par boutique, format `V-YYYY-NNNNN`.
  /// Généré atomiquement à la création. `null` pour les ventes anciennes
  /// (rétro-compat) → on retombe sur les 8 premiers caractères de l'id.
  final String? numero;

  final String boutiqueId;
  final String vendeurId;

  /// Si défini : référence à un client de la collection /clients.
  /// `null` = client divers (passage), avec `clientNomLibre` éventuellement
  /// renseigné pour identification.
  final String? clientId;

  /// Nom libre du client lorsqu'il n'est pas dans la base.
  /// Ignoré si [clientId] est renseigné.
  final String? clientNomLibre;

  final List<VenteArticle> articles;
  final double sousTotal;
  final double remise;
  final double total;

  /// Montant effectivement encaissé en cash/MM/etc. lors de la vente.
  /// Pour les ventes existantes en base sans ce champ (rétro-compat), on
  /// retombe sur `total` (vente intégralement payée).
  final double montantPaye;

  /// Avance du client utilisée pour cette vente (puisée sur son solde
  /// négatif existant). Combinée avec `montantPaye`, couvre tout ou partie
  /// du `total`. Le reste constitue un nouveau crédit. Default 0.
  final double avanceUtilisee;

  final ModePaiement modePaiement;
  final VenteStatut statut;
  final DateTime date;
  final String? note;
  final String? motifAnnulation;

  const VenteModel({
    required this.id,
    required this.boutiqueId,
    required this.vendeurId,
    required this.articles,
    required this.sousTotal,
    required this.total,
    required this.montantPaye,
    required this.modePaiement,
    required this.date,
    this.numero,
    this.clientId,
    this.clientNomLibre,
    this.remise = 0,
    this.avanceUtilisee = 0,
    this.statut = VenteStatut.validee,
    this.note,
    this.motifAnnulation,
  });

  factory VenteModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = (map['articles'] as List?) ?? const [];
    final total = (map['total'] as num?)?.toDouble() ?? 0;
    return VenteModel(
      id: id,
      numero: map['numero'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      vendeurId: (map['vendeurId'] ?? '') as String,
      clientId: map['clientId'] as String?,
      clientNomLibre: map['clientNomLibre'] as String?,
      articles: raw
          .map((e) => VenteArticle.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sousTotal: (map['sousTotal'] as num?)?.toDouble() ?? 0,
      remise: (map['remise'] as num?)?.toDouble() ?? 0,
      total: total,
      // Rétro-compat : ancien doc → considéré comme intégralement payé.
      montantPaye: (map['montantPaye'] as num?)?.toDouble() ?? total,
      avanceUtilisee: (map['avanceUtilisee'] as num?)?.toDouble() ?? 0,
      modePaiement: ModePaiement.fromString(map['modePaiement'] as String?),
      statut: VenteStatut.fromString(map['statut'] as String?),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      motifAnnulation: map['motifAnnulation'] as String?,
    );
  }

  factory VenteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VenteModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'boutiqueId': boutiqueId,
        'vendeurId': vendeurId,
        'clientId': clientId,
        'clientNomLibre': clientNomLibre,
        'articles': articles.map((a) => a.toMap()).toList(),
        // Tableau dénormalisé des produitId présents dans `articles`,
        // pour permettre une query Firestore efficace
        // `where('articleProduitIds', arrayContains: pid)` (utilisée
        // notamment pour bloquer la suppression d'un produit déjà vendu).
        'articleProduitIds': articles.map((a) => a.produitId).toSet().toList(),
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
  /// caractères de l'ID Firestore (rétro-compat ventes anciennes).
  String get numeroAffichage {
    if (numero != null && numero!.isNotEmpty) return numero!;
    if (id.isEmpty) return '—';
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
  }

  /// Reste dû par le client après cette vente (positif = crédit en cours).
  /// Négatif si le client a payé plus que le total (avance / remboursement).
  /// Inclut l'avance utilisée : reste = total - cash payé - avance utilisée.
  double get resteAPayer => total - montantPaye - avanceUtilisee;

  bool get estPartiellementPayee => resteAPayer > 0;

  int get nbArticles => articles.fold(0, (acc, a) => acc + a.quantite);

  /// Renvoie un libellé pour identifier le client dans les listes / le reçu.
  /// Si `clientId` est défini, ce libellé sera complété ailleurs avec le nom
  /// récupéré du repo. Sinon utilise `clientNomLibre` ou « Client divers ».
  String get clientLabelOuLibre {
    if (clientNomLibre != null && clientNomLibre!.isNotEmpty) {
      return clientNomLibre!;
    }
    return 'Client divers';
  }
}
