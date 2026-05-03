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

  /// Compteurs par boutique pour la génération des numéros de vente
  /// séquentiels. Document = boutiqueId, champ = "ventesYYYY".
  static const counters = 'counters';
}
