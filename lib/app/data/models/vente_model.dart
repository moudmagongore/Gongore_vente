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
  final int quantite;
  final double prixUnitaire;
  final double remise;

  const VenteArticle({
    required this.produitId,
    required this.nom,
    required this.quantite,
    required this.prixUnitaire,
    this.remise = 0,
  });

  double get sousTotal => (prixUnitaire * quantite) - remise;

  factory VenteArticle.fromMap(Map<String, dynamic> map) {
    return VenteArticle(
      produitId: (map['produitId'] ?? '') as String,
      nom: (map['nom'] ?? '') as String,
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      prixUnitaire: (map['prixUnitaire'] as num?)?.toDouble() ?? 0,
      remise: (map['remise'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'produitId': produitId,
        'nom': nom,
        'quantite': quantite,
        'prixUnitaire': prixUnitaire,
        'remise': remise,
      };
}

class VenteModel {
  final String id;
  final String boutiqueId;
  final String vendeurId;
  final String? clientId;
  final List<VenteArticle> articles;
  final double sousTotal;
  final double remise;
  final double total;
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
    required this.modePaiement,
    required this.date,
    this.clientId,
    this.remise = 0,
    this.statut = VenteStatut.validee,
    this.note,
    this.motifAnnulation,
  });

  factory VenteModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = (map['articles'] as List?) ?? const [];
    return VenteModel(
      id: id,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      vendeurId: (map['vendeurId'] ?? '') as String,
      clientId: map['clientId'] as String?,
      articles: raw
          .map((e) => VenteArticle.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sousTotal: (map['sousTotal'] as num?)?.toDouble() ?? 0,
      remise: (map['remise'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
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
        'boutiqueId': boutiqueId,
        'vendeurId': vendeurId,
        'clientId': clientId,
        'articles': articles.map((a) => a.toMap()).toList(),
        'sousTotal': sousTotal,
        'remise': remise,
        'total': total,
        'modePaiement': modePaiement.name,
        'statut': statut.name,
        'date': Timestamp.fromDate(date),
        'note': note,
        'motifAnnulation': motifAnnulation,
      };

  int get nbArticles =>
      articles.fold(0, (acc, a) => acc + a.quantite);
}
