import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/widgets/coming_soon_view.dart';
import '../modules/admin/boutiques/bindings/boutique_form_binding.dart';
import '../modules/admin/boutiques/bindings/boutiques_binding.dart';
import '../modules/admin/boutiques/views/boutique_form_view.dart';
import '../modules/admin/boutiques/views/boutiques_list_view.dart';
import '../modules/admin/categories/bindings/categorie_form_binding.dart';
import '../modules/admin/categories/bindings/categories_binding.dart';
import '../modules/admin/categories/views/categorie_form_view.dart';
import '../modules/admin/categories/views/categories_list_view.dart';
import '../modules/admin/home/views/admin_home_view.dart';
import '../modules/admin/produits/bindings/produit_form_binding.dart';
import '../modules/admin/produits/bindings/produits_binding.dart';
import '../modules/admin/produits/views/produit_form_view.dart';
import '../modules/admin/produits/views/produits_list_view.dart';
import '../modules/admin/rapports/bindings/rapports_binding.dart';
import '../modules/admin/rapports/views/rapports_view.dart';
import '../modules/admin/stock/bindings/historique_mouvements_binding.dart';
import '../modules/admin/stock/bindings/mouvement_binding.dart';
import '../modules/admin/stock/bindings/stock_binding.dart';
import '../modules/admin/stock/views/historique_mouvements_view.dart';
import '../modules/admin/stock/views/mouvement_form_view.dart';
import '../modules/admin/stock/views/stock_list_view.dart';
import '../modules/admin/ventes/bindings/vente_detail_binding.dart';
import '../modules/admin/ventes/bindings/ventes_binding.dart';
import '../modules/admin/ventes/views/vente_detail_view.dart';
import '../modules/admin/ventes/views/ventes_list_view.dart';
import '../modules/pos/bindings/pos_binding.dart';
import '../modules/pos/views/pos_view.dart';
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
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminCategorieForm,
      page: () => const CategorieFormView(),
      binding: CategorieFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminProduits,
      page: () => const ProduitsListView(),
      binding: ProduitsBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminProduitForm,
      page: () => const ProduitFormView(),
      binding: ProduitFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminStock,
      page: () => const StockListView(),
      binding: StockBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminMouvementForm,
      page: () => const MouvementFormView(),
      binding: MouvementBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminMouvementsHistorique,
      page: () => const HistoriqueMouvementsView(),
      binding: HistoriqueMouvementsBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminVentes,
      page: () => const VentesListView(),
      binding: VentesBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.adminPos,
      page: () => const PosView(),
      binding: PosBinding(),
      middlewares: [AdminGuard()],
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
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.parametres,
      page: () => const ComingSoonView(
        title: 'Paramètres',
        currentRoute: AppRoutes.parametres,
        icon: Icons.settings_rounded,
      ),
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
      name: AppRoutes.vendeurPos,
      page: () => const PosView(),
      binding: PosBinding(),
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
