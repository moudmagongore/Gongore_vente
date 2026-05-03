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

  /// Compteurs par boutique pour la génération des numéros séquentiels.
  /// Document = boutiqueId, champs = "ventesYYYY", "approsYYYY".
  static const counters = 'counters';
}
