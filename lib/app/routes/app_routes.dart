// Routes nommées de l'application. Toujours référencer les écrans
// via ces constantes et jamais via des chaînes en dur.
abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/';

  /// Présentation de première ouverture. Atteinte uniquement depuis le
  /// splash, tant que [OnboardingService.hasSeen] est faux.
  static const onboarding = '/onboarding';

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
  static const adminClients = '/admin/clients';
  static const adminClientForm = '/admin/clients/form';
  static const adminClientDetail = '/admin/clients/detail';
  static const adminFournisseurs = '/admin/fournisseurs';
  static const adminFournisseurForm = '/admin/fournisseurs/form';
  static const adminFournisseurDetail = '/admin/fournisseurs/detail';
  static const adminAppros = '/admin/approvisionnements';
  static const approForm = '/admin/approvisionnements/form';
  static const approDetail = '/admin/approvisionnements/detail';
  static const adminStock = '/admin/stock';
  static const adminStockHistorique = '/admin/stock/historique';
  static const adminReglements = '/admin/reglements';
  static const adminReglementsFournisseurs = '/admin/reglements-fournisseurs';
  static const venteForm = '/admin/ventes/form';
  static const adminVentes = '/admin/ventes';
  static const venteDetail = '/ventes/detail';
  static const adminRapports = '/admin/rapports';

  // Abonnements (super-admin)
  static const adminAbonnements = '/admin/abonnements';
  static const adminAbonnementForm = '/admin/abonnements/form';
  static const adminAbonnementParams = '/admin/abonnements/params';

  // Mon abonnement (admin de boutique, lecture seule de SON abonnement)
  static const monAbonnement = '/admin/mon-abonnement';

  // Vendeur
  static const vendeurHome = '/vendeur';
  static const vendeurVentes = '/vendeur/ventes';

  // Commun
  static const profil = '/profil';
  static const parametres = '/parametres';
  static const apropos = '/apropos';
}
