/// Noms des collections Firestore (référence unique).
/// Ne jamais utiliser de chaîne en dur ailleurs dans le code.
abstract class FirestoreKeys {
  FirestoreKeys._();

  static const users = 'users';
  static const boutiques = 'boutiques';
  static const produits = 'produits';
  static const categories = 'categories';
  static const ventes = 'ventes';
  static const clients = 'clients';
  static const reglements = 'reglements';

  static const fournisseurs = 'fournisseurs';
  static const approvisionnements = 'approvisionnements';
  static const reglementsFournisseurs = 'reglementsFournisseurs';
  static const mouvementsStock = 'mouvementsStock';

  /// Compteurs par boutique pour la génération des numéros séquentiels.
  /// Document = boutiqueId, champs = "ventesYYYY", "approsYYYY".
  static const counters = 'counters';

  /// Paiements d'abonnements (un doc par paiement enregistré).
  static const abonnements = 'abonnements';

  /// Paramètres globaux (singleton). Utilisé entre autres pour le doc
  /// `parametres/abonnement` (tarifs + période de grâce).
  static const parametres = 'parametres';

  /// Doc-id du singleton de paramètres d'abonnement dans la collection
  /// [parametres].
  static const parametresAbonnementDoc = 'abonnement';

  /// Index téléphone → email pour le login hybride (l'utilisateur peut se
  /// connecter avec son numéro à la place de son email). Doc-id =
  /// téléphone normalisé (E.164 sans espaces, ex: `+224621785645`),
  /// contenu = `{ email, uid }`.
  ///
  /// Lecture publique nécessaire (au login l'utilisateur n'est pas encore
  /// authentifié), mais le contenu exposé est minimal. Écriture réservée
  /// aux admins de boutique et super-admin (qui créent les users).
  static const phoneIndex = 'phone_index';

  /// Doc-id du singleton de configuration de mise à jour forcée
  /// (`parametres/app_update`).
  static const parametresAppUpdateDoc = 'app_update';
}
