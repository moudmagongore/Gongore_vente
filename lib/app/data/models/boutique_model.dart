import 'package:cloud_firestore/cloud_firestore.dart';

class BoutiqueModel {
  final String id;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? logoUrl;
  final String devise;
  final bool active;

  /// Date de fin de l'abonnement courant. `null` = boutique sans abonnement
  /// jamais payé (juste créée). Maintenue par AbonnementRepository en
  /// transaction à chaque enregistrement de paiement.
  ///
  /// Au-delà de cette date + période de grâce (cf. AbonnementParams), la
  /// boutique et ses utilisateurs admin/gestionnaire sont considérés
  /// expirés et le login est refusé.
  final DateTime? subscriptionEndsAt;

  /// Le module de caisse est-il ouvert à cette boutique ?
  ///
  /// **Décidé par le super-admin seul** — c'est un verrou commercial, pas
  /// un réglage de boutique : l'admin ne doit pas pouvoir s'ouvrir le
  /// module lui-même (verrouillé aussi dans `firestore.rules`).
  ///
  /// À `false`, toute l'application se comporte comme avant le module :
  /// les caisses disparaissent des écrans, les opérations retrouvent leur
  /// sélecteur de mode de paiement, et plus rien ne touche aux soldes. Les
  /// caisses et mouvements déjà enregistrés sont **conservés** et
  /// réapparaissent intacts si le module est réactivé.
  final bool caissesActivees;

  /// Vrai si la boutique a au moins une caisse ACTIVE.
  ///
  /// Dénormalisé ici parce qu'un gestionnaire ne peut lire que les caisses
  /// auxquelles il a accès : sans ce drapeau, il ne saurait pas distinguer
  /// « cette boutique n'a pas de caisse » (il opère comme avant, RG-9) de
  /// « elle en a mais aucune pour moi » (ses opérations payées sont
  /// bloquées, RG-19).
  ///
  /// Maintenu par `CaisseRepository` après chaque création, activation,
  /// désactivation ou suppression de caisse. **Absent de [toMap]** : une
  /// mise à jour de la boutique depuis son formulaire ne doit pas pouvoir
  /// l'écraser avec une valeur devenue périmée.
  final bool hasCaissesActives;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BoutiqueModel({
    required this.id,
    required this.nom,
    this.adresse,
    this.telephone,
    this.logoUrl,
    this.devise = 'GNF',
    this.active = true,
    this.subscriptionEndsAt,
    this.caissesActivees = false,
    this.hasCaissesActives = false,
    this.createdAt,
    this.updatedAt,
  });

  factory BoutiqueModel.fromMap(Map<String, dynamic> map, String id) {
    return BoutiqueModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      adresse: map['adresse'] as String?,
      telephone: map['telephone'] as String?,
      logoUrl: map['logoUrl'] as String?,
      devise: (map['devise'] ?? 'GNF') as String,
      active: (map['active'] ?? true) as bool,
      subscriptionEndsAt:
          (map['subscriptionEndsAt'] as Timestamp?)?.toDate(),
      caissesActivees: (map['caissesActivees'] ?? false) as bool,
      hasCaissesActives: (map['hasCaissesActives'] ?? false) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory BoutiqueModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return BoutiqueModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'adresse': adresse,
        'telephone': telephone,
        'logoUrl': logoUrl,
        'devise': devise,
        'active': active,
        // Présent dans toMap, contrairement à `hasCaissesActives` : c'est
        // le formulaire boutique du super-admin qui le renseigne. Les
        // règles Firestore empêchent un admin de le modifier.
        'caissesActivees': caissesActivees,
        if (subscriptionEndsAt != null)
          'subscriptionEndsAt': Timestamp.fromDate(subscriptionEndsAt!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  BoutiqueModel copyWith({
    String? nom,
    String? adresse,
    String? telephone,
    String? logoUrl,
    String? devise,
    bool? active,
    bool? caissesActivees,
    DateTime? subscriptionEndsAt,
  }) {
    return BoutiqueModel(
      id: id,
      caissesActivees: caissesActivees ?? this.caissesActivees,
      hasCaissesActives: hasCaissesActives,
      nom: nom ?? this.nom,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      logoUrl: logoUrl ?? this.logoUrl,
      devise: devise ?? this.devise,
      active: active ?? this.active,
      subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
