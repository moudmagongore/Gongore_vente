import '../../data/models/user_model.dart';
import '../../data/repositories/abonnement_params_repository.dart';
import '../../data/repositories/boutique_repository.dart';

/// Vérifie qu'un utilisateur (admin ou gestionnaire) peut se connecter
/// par rapport à l'abonnement de sa boutique.
///
/// Utilisé après le signIn (LoginController) et au démarrage de l'app
/// (SplashController) pour les sessions déjà ouvertes.
///
/// Politique :
/// - super-admin : toujours autorisé (gère les abonnements lui-même)
/// - user sans boutiqueId : toujours autorisé (cas anormal mais tolérant)
/// - boutique sans `subscriptionEndsAt` : **bloqué** (comme une boutique
///   expirée — un super-admin doit enregistrer un premier paiement)
/// - sinon : autorisé tant que `now <= subscriptionEndsAt + graceDays`
class SubscriptionGuard {
  SubscriptionGuard._();

  /// Renvoie `null` si l'utilisateur peut accéder à l'app, sinon un
  /// message d'erreur prêt à afficher.
  ///
  /// Multi-boutique : autorise dès qu'**au moins une** des boutiques
  /// accessibles a un abonnement valide. Bloque uniquement si toutes
  /// sont expirées / sans abonnement.
  static Future<String?> checkAccess(UserModel user) async {
    if (user.isSuperAdmin) return null;
    final ids = user.accessibleBoutiqueIds;
    if (ids.isEmpty) return null; // tolérant
    String? lastBlockMsg;
    for (final bid in ids) {
      final msg = await checkBoutiqueAccess(bid);
      if (msg == null) return null; // au moins une boutique valide
      lastBlockMsg = msg;
    }
    return lastBlockMsg ??
        'Aucune boutique active pour votre compte. Contactez le support.';
  }

  /// Renvoie l'ID de la première boutique accessible avec un abonnement
  /// valide (priorité à la principale), ou `null` si aucune n'est valide.
  /// Utilisé au login pour rediriger l'admin vers sa boutique fonctionnelle.
  static Future<String?> firstActiveBoutiqueId(UserModel user) async {
    if (user.isSuperAdmin) return null;
    final primary = user.boutiqueId;
    if (primary != null && primary.isNotEmpty) {
      final msg = await checkBoutiqueAccess(primary);
      if (msg == null) return primary;
    }
    for (final bid in user.accessibleBoutiqueIds) {
      if (bid == primary) continue;
      final msg = await checkBoutiqueAccess(bid);
      if (msg == null) return bid;
    }
    return null;
  }

  /// Vérifie l'accessibilité d'une boutique précise. Renvoie un message
  /// de blocage si elle est inaccessible :
  ///   • Supprimée
  ///   • Désactivée (`active: false`)
  ///   • Sans abonnement actif (`subscriptionEndsAt == null`)
  ///   • Abonnement expiré au-delà de la grâce
  /// Sinon renvoie `null` (accessible).
  static Future<String?> checkBoutiqueAccess(String boutiqueId) async {
    final boutique = await BoutiqueRepository().getById(boutiqueId);
    if (boutique == null) {
      return 'Cette boutique a été supprimée.';
    }
    if (!boutique.active) {
      return 'Cette boutique a été désactivée.';
    }
    if (boutique.subscriptionEndsAt == null) {
      return 'Cette boutique n\'a aucun abonnement actif. '
          'Contactez le support pour l\'activer.';
    }

    final params = await AbonnementParamsRepository().get();
    final graceDays = params.graceDays;
    final deadline =
        boutique.subscriptionEndsAt!.add(Duration(days: graceDays));
    final now = DateTime.now();
    if (now.isBefore(deadline) || now.isAtSameMomentAs(deadline)) {
      return null;
    }

    final daysSince =
        now.difference(boutique.subscriptionEndsAt!).inDays;
    return 'L\'abonnement de cette boutique a expiré depuis $daysSince '
        'jours. Contactez le support pour le réactiver.';
  }

  /// Récupère un éventuel **avertissement non-bloquant** à afficher après
  /// un login autorisé. Concerne admin/gestionnaire :
  /// - Si l'abonnement expire dans `params.warningThresholdDays` jours ou
  ///   moins → prévient le nombre exact de jours restants.
  /// - Si l'abonnement est expiré mais en période de grâce → prévient le
  ///   nombre de jours de grâce restants avant blocage.
  ///
  /// Renvoie `null` s'il n'y a pas lieu d'avertir (super-admin, abonnement
  /// avec marge, ou cas déjà bloqué par [checkAccess]).
  static Future<SubscriptionWarning?> getWarning(UserModel user) async {
    if (user.isSuperAdmin) return null;
    final bid = user.boutiqueId;
    if (bid == null || bid.isEmpty) return null;

    final boutique = await BoutiqueRepository().getById(bid);
    if (boutique == null) return null;
    final endsAt = boutique.subscriptionEndsAt;
    if (endsAt == null) return null; // déjà bloqué côté checkAccess

    // On lit toujours les params (utile dans les 2 branches : seuil
    // d'alerte et durée de grâce).
    final params = await AbonnementParamsRepository().get();
    final now = DateTime.now();
    if (endsAt.isAfter(now)) {
      // Encore en période d'abonnement actif : on alerte selon le seuil
      // configuré (warningThresholdDays).
      final daysRemaining = endsAt.difference(now).inDays;
      if (daysRemaining <= params.warningThresholdDays) {
        final j = daysRemaining <= 0
            ? 'moins d\'un jour'
            : (daysRemaining == 1 ? '1 jour' : '$daysRemaining jours');
        return SubscriptionWarning(
          title: 'Abonnement bientôt expiré',
          message:
              'Il vous reste $j avant la fin de votre abonnement. '
              'Pensez à renouveler.',
          isGracePeriod: false,
        );
      }
      return null;
    }

    // Abonnement déjà expiré : check si on est encore dans la grâce.
    final deadline = endsAt.add(Duration(days: params.graceDays));
    if (now.isBefore(deadline) || now.isAtSameMomentAs(deadline)) {
      final graceLeft = deadline.difference(now).inDays;
      final j = graceLeft <= 0
          ? 'moins d\'un jour'
          : (graceLeft == 1 ? '1 jour' : '$graceLeft jours');
      return SubscriptionWarning(
        title: 'Période de grâce',
        message:
            'Votre abonnement a expiré. Il vous reste $j de grâce '
            'avant le blocage de la boutique.',
        isGracePeriod: true,
      );
    }
    return null; // au-delà de la grâce → checkAccess gère
  }
}

/// Avertissement non-bloquant retourné par [SubscriptionGuard.getWarning].
class SubscriptionWarning {
  final String title;
  final String message;

  /// `true` quand l'abonnement est déjà expiré (en période de grâce),
  /// `false` quand il est encore actif mais ≤ 7 jours.
  final bool isGracePeriod;

  const SubscriptionWarning({
    required this.title,
    required this.message,
    required this.isGracePeriod,
  });
}
