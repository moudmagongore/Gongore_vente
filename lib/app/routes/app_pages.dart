import 'package:get/get.dart';

import '../modules/admin/boutiques/bindings/boutique_form_binding.dart';
import '../modules/admin/boutiques/bindings/boutiques_binding.dart';
import '../modules/admin/boutiques/views/boutique_form_view.dart';
import '../modules/admin/boutiques/views/boutiques_list_view.dart';
import '../modules/admin/categories/bindings/categorie_form_binding.dart';
import '../modules/admin/categories/bindings/categories_binding.dart';
import '../modules/admin/categories/views/categorie_form_view.dart';
import '../modules/admin/categories/views/categories_list_view.dart';
import '../modules/admin/clients/bindings/client_detail_binding.dart';
import '../modules/admin/clients/bindings/client_form_binding.dart';
import '../modules/admin/clients/bindings/clients_binding.dart';
import '../modules/admin/clients/views/client_detail_view.dart';
import '../modules/admin/clients/views/client_form_view.dart';
import '../modules/admin/clients/views/clients_list_view.dart';
import '../modules/admin/fournisseurs/bindings/fournisseur_detail_binding.dart';
import '../modules/admin/fournisseurs/bindings/fournisseur_form_binding.dart';
import '../modules/admin/fournisseurs/bindings/fournisseurs_binding.dart';
import '../modules/admin/fournisseurs/views/fournisseur_detail_view.dart';
import '../modules/admin/fournisseurs/views/fournisseur_form_view.dart';
import '../modules/admin/fournisseurs/views/fournisseurs_list_view.dart';
import '../modules/admin/appros/bindings/appro_detail_binding.dart';
import '../modules/admin/appros/bindings/appro_form_binding.dart';
import '../modules/admin/appros/bindings/appros_binding.dart';
import '../modules/admin/appros/views/appro_detail_view.dart';
import '../modules/admin/appros/views/appro_form_view.dart';
import '../modules/admin/appros/views/appros_list_view.dart';
import '../modules/admin/stock/bindings/historique_mouvements_binding.dart';
import '../modules/admin/stock/bindings/stock_binding.dart';
import '../modules/admin/stock/views/historique_mouvements_view.dart';
import '../modules/admin/stock/views/stock_list_view.dart';
import '../modules/admin/home/views/admin_home_view.dart';
import '../modules/admin/produits/bindings/produit_form_binding.dart';
import '../modules/admin/reglements/bindings/reglements_binding.dart';
import '../modules/admin/reglements/views/reglements_list_view.dart';
import '../modules/admin/reglements_fournisseurs/bindings/reglements_fournisseurs_binding.dart';
import '../modules/admin/reglements_fournisseurs/views/reglements_fournisseurs_list_view.dart';
import '../modules/admin/produits/bindings/produits_binding.dart';
import '../modules/admin/produits/views/produit_form_view.dart';
import '../modules/admin/produits/views/produits_list_view.dart';
import '../modules/admin/rapports/bindings/rapports_binding.dart';
import '../modules/admin/rapports/views/rapports_view.dart';
import '../modules/admin/ventes/bindings/vente_detail_binding.dart';
import '../modules/admin/ventes/bindings/vente_form_binding.dart';
import '../modules/admin/ventes/bindings/ventes_binding.dart';
import '../modules/admin/ventes/views/vente_detail_view.dart';
import '../modules/admin/ventes/views/vente_form_view.dart';
import '../modules/admin/ventes/views/ventes_list_view.dart';
import '../modules/admin/users/bindings/user_form_binding.dart';
import '../modules/admin/users/bindings/users_binding.dart';
import '../modules/admin/users/views/user_form_view.dart';
import '../modules/admin/users/views/users_list_view.dart';
import '../modules/auth/bindings/login_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/vendeur/home/bindings/vendeur_home_binding.dart';
import '../modules/vendeur/home/views/vendeur_home_view.dart';
import 'app_routes.dart';
import 'route_guards.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = <GetPage>[
    // ========== Auth & Splash ==========
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),

    // ========== Admin (réservé admin / super-admin) ==========
    GetPage(
      name: AppRoutes.adminHome,
      page: () => const AdminHomeView(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminBoutiques,
      page: () => const BoutiquesListView(),
      binding: BoutiquesBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminBoutiqueForm,
      page: () => const BoutiqueFormView(),
      binding: BoutiqueFormBinding(),
      middlewares: [AdminGuard()],
    ),

    GetPage(
      name: AppRoutes.adminUsers,
      page: () => const UsersListView(),
      binding: UsersBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminUserForm,
      page: () => const UserFormView(),
      binding: UserFormBinding(),
      middlewares: [AdminGuard()],
    ),

    GetPage(
      name: AppRoutes.adminCategories,
      page: () => const CategoriesListView(),
      binding: CategoriesBinding(),
      // AuthGuard : vendeur peut voir la liste en lecture seule.
      // Les actions d'édition/suppression sont gardées côté UI.
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminCategorieForm,
      page: () => const CategorieFormView(),
      binding: CategorieFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminClients,
      page: () => const ClientsListView(),
      binding: ClientsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminClientForm,
      page: () => const ClientFormView(),
      binding: ClientFormBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminClientDetail,
      page: () => const ClientDetailView(),
      binding: ClientDetailBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminFournisseurs,
      page: () => const FournisseursListView(),
      binding: FournisseursBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminFournisseurForm,
      page: () => const FournisseurFormView(),
      binding: FournisseurFormBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminFournisseurDetail,
      page: () => const FournisseurDetailView(),
      binding: FournisseurDetailBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminAppros,
      page: () => const ApprosListView(),
      binding: ApprosBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.approForm,
      page: () => const ApproFormView(),
      binding: ApproFormBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.approDetail,
      page: () => const ApproDetailView(),
      binding: ApproDetailBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminStock,
      page: () => const StockListView(),
      binding: StockBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminStockHistorique,
      page: () => const HistoriqueMouvementsView(),
      binding: HistoriqueMouvementsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminReglements,
      page: () => const ReglementsListView(),
      binding: ReglementsBinding(),
      // admin/super-admin en lecture seule, vendeur en CRUD.
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminReglementsFournisseurs,
      page: () => const ReglementsFournisseursListView(),
      binding: ReglementsFournisseursBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminProduits,
      page: () => const ProduitsListView(),
      binding: ProduitsBinding(),
      // AuthGuard : vendeur peut voir la liste en lecture seule.
      // Les actions d'édition/suppression sont gardées côté UI.
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminProduitForm,
      page: () => const ProduitFormView(),
      binding: ProduitFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminVentes,
      page: () => const VentesListView(),
      binding: VentesBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.venteForm,
      page: () => const VenteFormView(),
      binding: VenteFormBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.venteDetail,
      page: () => const VenteDetailView(),
      binding: VenteDetailBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.adminRapports,
      page: () => const RapportsView(),
      binding: RapportsBinding(),
      // Vendeur peut accéder : il voit le rapport scopé à ses propres ventes
      // (le controller verrouille `vendeurId` sur lui-même).
      middlewares: [AuthGuard()],
    ),
    // ========== Vendeur (tout user connecté) ==========
    GetPage(
      name: AppRoutes.vendeurHome,
      page: () => const VendeurHomeView(),
      binding: VendeurHomeBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.vendeurVentes,
      page: () => const VentesListView(),
      binding: VentesBinding(),
      middlewares: [AuthGuard()],
    ),
  ];
}
