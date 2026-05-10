import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  /// Super-administrateur : accès global, gère les boutiques et leurs admins.
  /// Créé UNIQUEMENT manuellement dans Firestore (jamais via l'app).
  superAdmin,

  /// Administrateur d'une boutique : gère ses produits, catégories, vendeurs.
  /// Lié à une boutique précise via `boutiqueId`.
  admin,

  /// Gestionnaire (anciennement « vendeur ») : utilise la caisse, voit ses
  /// propres ventes/règlements. Lié à une boutique via `boutiqueId`.
  /// Note : la valeur enum/DB reste `vendeur` pour compatibilité avec les
  /// comptes existants — on accepte aussi `'gestionnaire'` à la lecture.
  vendeur;

  static UserRole fromString(String? value) {
    // Compat : nouveau libellé `'gestionnaire'` mappé sur l'enum vendeur.
    if (value == 'gestionnaire') return UserRole.vendeur;
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.vendeur,
    );
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.vendeur:
        return 'Gestionnaire';
    }
  }
}

class UserModel {
  final String id;
  final String nom;
  final String email;
  final String? telephone;
  final UserRole role;
  final String? boutiqueId;
  final bool active;

  /// Drapeau cumulatif : `true` ⇒ cet admin a AUSSI les droits gestionnaire
  /// de sa boutique (encaisser, verser règlement, créer vente, etc.) en
  /// plus de ses droits admin habituels. Ignoré pour role != admin.
  /// Permet à un admin de gérer en plus la caisse au quotidien.
  final bool alsoGestionnaire;

  /// Boutiques supplémentaires auxquelles l'admin a accès (en plus de
  /// `boutiqueId` qui reste sa boutique principale). Permet à un admin
  /// d'être affecté à plusieurs boutiques. Toujours vide pour un vendeur
  /// (un gestionnaire n'a qu'une seule boutique).
  final List<String> additionalBoutiqueIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    this.boutiqueId,
    this.active = true,
    this.alsoGestionnaire = false,
    this.additionalBoutiqueIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      telephone: map['telephone'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      boutiqueId: map['boutiqueId'] as String?,
      active: (map['active'] ?? true) as bool,
      alsoGestionnaire: (map['alsoGestionnaire'] ?? false) as bool,
      additionalBoutiqueIds: (map['additionalBoutiqueIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'role': role.name,
        'boutiqueId': boutiqueId,
        'active': active,
        'alsoGestionnaire': alsoGestionnaire,
        'additionalBoutiqueIds': additionalBoutiqueIds,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Liste de toutes les boutiques accessibles par cet utilisateur.
  /// Pour super-admin : vide (il accède à tout, mais via un autre chemin).
  /// Pour admin : `boutiqueId` + `additionalBoutiqueIds` (dédupliqué, sans null).
  /// Pour vendeur : `[boutiqueId]` uniquement.
  List<String> get accessibleBoutiqueIds {
    if (isSuperAdmin) return const [];
    final main = boutiqueId;
    if (main == null || main.isEmpty) return const [];
    if (role != UserRole.admin) return [main];
    final all = <String>{main, ...additionalBoutiqueIds.where((b) => b.isNotEmpty)};
    return all.toList();
  }

  /// Vrai si cet utilisateur (admin) a accès à plusieurs boutiques.
  bool get hasMultipleBoutiques => accessibleBoutiqueIds.length > 1;

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;

  /// Vrai si l'utilisateur peut faire les opérations gestionnaire :
  ///   • role == vendeur (gestionnaire de base)
  ///   • OU role == admin AVEC `alsoGestionnaire: true` (cumul admin+caisse)
  bool get isVendeur =>
      role == UserRole.vendeur || (role == UserRole.admin && alsoGestionnaire);

  /// Renvoie true si l'utilisateur a un accès admin (super-admin OU admin
  /// de boutique). Utile pour cacher les écrans réservés aux vendeurs.
  bool get isAnyAdmin => isSuperAdmin || isAdmin;

  UserModel copyWith({
    String? nom,
    String? email,
    String? telephone,
    UserRole? role,
    String? boutiqueId,
    bool? active,
    bool? alsoGestionnaire,
    List<String>? additionalBoutiqueIds,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      active: active ?? this.active,
      alsoGestionnaire: alsoGestionnaire ?? this.alsoGestionnaire,
      additionalBoutiqueIds:
          additionalBoutiqueIds ?? this.additionalBoutiqueIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
