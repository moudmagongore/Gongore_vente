// Routes nommées de l'application. Toujours référencer les écrans
// via ces constantes et jamais via des chaînes en dur.
abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/';

  // Auth
  static const login = '/login';
  static const forgotPassword = '/forgot-password';

  // Admin
  static const adminHome = '/admin';
  static const adminDashboard = '/admin/dashboard';
  static const adminBoutiques = '/admin/boutiques';
  static const adminBoutiqueForm = '/admin/boutiques/form';
  static const adminUsers = '/admin/users';
  static const adminUserForm = '/admin/users/form';
  static const adminProduits = '/admin/produits';
  static const adminProduitForm = '/admin/produits/form';
  static const adminCategories = '/admin/categories';
  static const adminCategorieForm = '/admin/categories/form';
  static const adminStock = '/admin/stock';
  static const adminMouvementForm = '/admin/stock/mouvement';
  static const adminMouvementsHistorique = '/admin/stock/historique';
  static const adminVentes = '/admin/ventes';
  static const adminPos = '/admin/pos';
  static const venteDetail = '/ventes/detail';
  static const adminRapports = '/admin/rapports';

  // Vendeur
  static const vendeurHome = '/vendeur';
  static const vendeurPos = '/vendeur/pos';
  static const vendeurVentes = '/vendeur/ventes';

  // Commun
  static const profil = '/profil';
  static const parametres = '/parametres';
}
