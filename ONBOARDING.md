# Gongore App — Guide de reprise

Document destiné à un développeur qui reprend le projet. Il couvre le métier,
l'architecture, les règles non devinables à la lecture du code, et les pièges
déjà rencontrés.

**État au 18/10/2026** — version `1.6.6+16`, ~48 000 lignes de Dart réparties
sur 207 fichiers. Branche de travail : `dev`. Branche principale : `main`.

---

## 1. Ce que fait l'application

Gongore App est une solution de **gestion de boutique multi-tenant** destinée
au commerce de détail en Guinée (devise GNF, locale `fr_FR`). Une installation
unique sert plusieurs boutiques indépendantes, chacune cloisonnée des autres.

Le périmètre fonctionnel couvre :

- **Ventes** — panier, remises, modes de paiement, vente à crédit, annulation
  avec motif, reçu PDF 80 mm (imprimante thermique)
- **Catalogue** — produits avec variantes (pointures, tailles), catégories, stock
- **Achats** — fournisseurs, approvisionnements, règlements fournisseurs
- **Clients** — fiches, soldes, encaissements, règlements
- **Dépenses** — charges de la boutique rattachées à des natures paramétrables
- **Rapports** — tableau de bord, rapports par période, export PDF
- **Abonnements** — chaque boutique paie un abonnement ; l'accès est bloqué à
  l'expiration (géré par le super-admin)

---

## 2. Démarrage

### Prérequis

| | |
|---|---|
| Flutter | 3.38.7 (stable) |
| Dart SDK | ^3.10.7 |
| Firebase | projet `gongorevente` |
| Node | pour les scripts d'administration (`scripts/`) |

### Lancer

```bash
flutter pub get
flutter run
```

Les fichiers de configuration Firebase (`google-services.json`,
`GoogleService-Info.plist`, `lib/firebase_options.dart`) sont déjà versionnés.

### ⚠️ `dependency_overrides` à ne pas retirer

`pubspec.yaml` épingle `path_provider_foundation: 2.4.1`. Les versions ≥ 2.6
tirent `objective_c`, distribué en **native assets** — une dylib qui n'est pas
embarquée de façon fiable dans `Runner.app` par les builds Xcode/IDE. Le
symptôme est un crash au lancement sur iOS :

```
Couldn't resolve native function 'DOBJC_initializeApi'
Failed to load dynamic library 'objective_c.framework/objective_c'
```

Avant de lever l'override, vérifier que `flutter pub deps | grep objective_c`
ne remonte rien.

### ⚠️ iOS — deux réglages à ne pas défaire

| Fichier | Réglage | Pourquoi |
|---|---|---|
| `ios/Podfile` | `platform :ios, '15.0'`, puis `IPHONEOS_DEPLOYMENT_TARGET = '15.0'` forcé sur **chaque** configuration dans `post_install` | `flutter_additional_ios_build_settings` laisse certains pods sur la cible de leur podspec (jusqu'à 10.0) ; Xcode 27 remonte alors un avertissement « Target Integrity » par pod. iOS 15 couvre tout depuis l'iPhone 6s. |
| `ios/Runner/Info.plist` | `UIApplicationSceneManifest` → `UISceneDelegateClassName` = `FlutterSceneDelegate` | Le SDK iOS 26 exige l'adoption d'UIScene. Sans ce manifeste, l'app se lance **et se ferme aussitôt** ; le rapport de crash porte `NoSceneLifecycleAdoption`. |

Après toute modification du `Podfile` : `cd ios && pod install`.

**`flutter build ios --simulator` échoue** avec Flutter 3.38.7 sous Xcode 27.1 :
Flutter appelle `lipo -verify_arch arm64 x86_64`, que ce `lipo` refuse
(« requires exactly one input file »). Ce n'est pas une régression du projet,
et c'est sans effet sur le travail quotidien : `flutter run` ne compile que
l'architecture active et fonctionne, comme `flutter build ios` (appareil,
architecture unique). Le correctif réel est un `flutter upgrade`.

---

## 3. Architecture

**GetX** pour l'état, la navigation et l'injection de dépendances. Pas de
BLoC, pas de Riverpod.

```
lib/
├── main.dart                    # init Firebase, GetStorage, services permanents
├── firebase_options.dart
└── app/
    ├── core/
    │   ├── constants/           # app_constants, firestore_keys
    │   ├── services/            # auth, user_controller, firestore, PDF, sons…
    │   ├── utils/               # formats, timeouts réseau, helpers bottom sheet
    │   └── widgets/             # drawers, dialogues et bandeaux partagés
    ├── data/
    │   ├── models/              # 17 modèles (fromMap / toMap / fromFirestore)
    │   └── repositories/        # 18 repositories — SEUL accès à Firestore
    ├── modules/
    │   ├── admin/<feature>/     # bindings / controllers / views / widgets
    │   └── vendeur/home/
    ├── routes/                  # app_routes, app_pages, route_guards
    └── theme/                   # app_colors, app_theme, theme_controller
```

### Règles de structure

**Un module = `bindings/` + `controllers/` + `views/` (+ `widgets/`).** Le
binding fait un `Get.lazyPut` du controller, la route le déclare.

**Les views ne touchent jamais Firestore.** Elles passent par le controller,
qui passe par un repository. Aucune requête `FirebaseFirestore.instance`
directe hors `data/repositories/`.

**Les noms de collections vivent dans `FirestoreKeys`.** Jamais de chaîne en
dur ailleurs.

### Services permanents (`main.dart`)

`ThemeController`, `AuthService`, `BiometricService`, `FirestoreService`,
`UserController` sont `Get.put(..., permanent: true)` et accessibles partout.

`UserController` est le pivot : il maintient l'utilisateur courant, écoute en
temps réel son document Firestore, celui de sa boutique et la liste des admins
de sa boutique — et force une déconnexion si le compte est désactivé, si la
boutique est supprimée/désactivée, ou si l'abonnement expire en cours de session.

---

## 4. Rôles et permissions

Trois rôles, plus un cumul.

| Rôle | Portée | Droits |
|---|---|---|
| `superAdmin` | toutes les boutiques | accès total ; créé **manuellement** dans Firestore, jamais via l'app |
| `admin` | sa (ses) boutique(s) | catalogue, utilisateurs, paramétrage, lecture des opérations |
| `vendeur` (« gestionnaire ») | sa boutique | opérations : ventes, encaissements, appros, règlements |

**Le cumul admin + gestionnaire** est la subtilité principale. Un admin peut
cocher `alsoGestionnaire: true` sur son propre profil pour tenir aussi la
caisse. Conséquence : `UserModel.isVendeur` est vrai pour ce profil, et il
faut souvent distinguer `isVendeur` de `isAnyAdmin`.

Getters utiles (`UserController`) :

```dart
isSuperAdmin / isAdmin / isVendeur / isAnyAdmin
canManageCatalog    // superAdmin || admin         → produits, catégories
canPerformSales     // superAdmin || isVendeur     → ventes, encaissements
canDeclareDepense   // superAdmin || admin || isVendeur
```

### Scope des requêtes — à comprendre absolument

```dart
UserController.to.scopeBoutiqueId
// superAdmin        → null  (pas de filtre, voit tout)
// admin / vendeur   → la boutique ACTIVE
```

Un admin **multi-boutique** possède `boutiqueId` (principale) plus
`additionalBoutiqueIds`. Le drawer propose un sélecteur de boutique active.
Les controllers lient leurs streams au démarrage avec `scopeBoutiqueId` ; un
changement de boutique déclenche donc `Get.offAllNamed(adminHome)` pour que
tout se ré-initialise.

### Garde-fous de route

`AuthGuard` (connecté), `AdminGuard` (admin ou super-admin), `SuperAdminGuard`.
Ils doublent les règles Firestore, ils ne les remplacent pas.

---

## 5. Données Firestore

Collections principales (voir `FirestoreKeys`) :

```
users                     boutiques              produits (+ /variantes)
categories                ventes                 clients
reglements                fournisseurs           approvisionnements
reglementsFournisseurs    mouvementsStock        naturesDepense
depenses                  counters               abonnements
parametres                phone_index
```

**Chaque document métier porte un `boutiqueId`** — c'est la clé du cloisonnement
multi-tenant, utilisée par les règles de sécurité comme par les requêtes.

Deux exceptions :

- `counters` est adressé **par identifiant de document** (= le `boutiqueId`),
  pas par champ. Aucun `where` ne le trouve.
- `variantes` est une **sous-collection** de `produits` et ne porte pas de
  `boutiqueId` : les règles remontent au produit parent.

---

## 6. Règles métier non devinables

Ces comportements sont implicites dans le code ; les ignorer casse la
cohérence comptable.

### CMUP — coût moyen unitaire pondéré

`ProduitModel.prixAchat` n'est **pas** saisi librement : il est recalculé à
chaque approvisionnement.

```
nouveau_PA = (qte_actuelle × PA_actuel + qte_appro × PA_appro)
           / (qte_actuelle + qte_appro)
```

Dès qu'un appro existe (`hasAppros: true`), le champ devient **immuable pour
l'admin** — verrou appliqué côté règles Firestore. Seul le super-admin peut le
forcer. C'est ce prix qui sert au calcul de tous les bénéfices.

### Marge figée à la vente

La marge d'une vente est **calculée une fois pour toutes à sa validation**,
jamais recalculée à l'affichage. Sans cela, chaque approvisionnement changeant
le CMUP ferait bouger après coup les marges des ventes passées : un rapport
sur une période close n'était pas stable.

Champs portés par la vente :

| Emplacement | Champ | Contenu |
|---|---|---|
| ligne (`VenteArticle`) | `prixAchatUnitaire` | CMUP du produit à l'instant de la vente |
| ligne | `remiseGlobaleAllouee` | part de la remise globale imputée à la ligne |
| ligne | `marge` | `sousTotal − part − (prixAchat × quantité)` |
| vente | `coutAchatTotal` | somme des coûts d'achat des lignes |
| vente | `margeTotale` | somme des marges de ligne |

Trois points à connaître :

- Le prix d'achat est lu **dans la transaction de vente**, pas depuis la
  valeur chargée côté client : un appro validé entre l'ouverture du panier et
  la validation changerait le CMUP entre-temps.
- La **remise globale** n'appartient à aucune ligne : elle est répartie au
  prorata du montant net, la dernière part étant déduite par différence pour
  que la somme soit exactement égale à la remise.
- Le calcul vit dans `core/utils/marge_calculator.dart`, **porté à
  l'identique** en JavaScript dans `scripts/lib/marges.js` pour la reprise.
  Les deux doivent rester synchronisés ; les mêmes cas sont rejoués dans
  `test/marge_calculator_test.dart` et `scripts/test/marges.test.js`.

Les champs sont `null` sur les ventes antérieures à la reprise : les lectures
prévoient un repli sur l'ancien calcul (`VenteModel.aMargeFigee`).

**Reprise de l'historique** — écran *Purge des données* (super-admin), carte
« Marges des ventes passées » : elle fige les ventes anciennes **au prix
d'achat actuel**. Choix assumé — la marge obtenue n'est pas exacte pour une
vente ancienne, mais elle cesse définitivement de bouger, ce qui est
l'objectif. Une vente déjà figée n'est jamais recalculée.

`scripts/backfill_marges_ventes.js` fait la même chose en reconstituant le
CMUP historique (plus fidèle, mais nécessite une clé de compte de service).
Il reste disponible et n'a jamais été exécuté.

Visibilité : marges, bénéfices et coûts d'achat sont réservés à l'admin via
`UserController.canSeeMarges` (basé sur `isAnyAdmin`, donc un admin cumulant
le rôle gestionnaire les voit). Ils n'apparaissent **jamais** sur l'écran de
vente, le détail d'une vente ni le reçu.

### Stock

`quantiteStock` est maintenu **atomiquement par transaction** (vente, appro,
mouvement manuel). Ne jamais l'écrire directement.

Pour un produit à variantes, c'est un **miroir** de la somme des stocks des
variantes, et `seuilAlerte` s'applique alors *par variante*, pas sur le total.

### Soldes client et fournisseur

- **Client** : positif = il nous doit (crédit en cours), négatif = avance versée
- **Fournisseur** : positif = on lui doit (dette), négatif = avance versée

Maintenus atomiquement par les transactions de vente/appro/règlement.

### Imputation FIFO des règlements

Un règlement (client ou fournisseur) est imputé **du plus ancien au plus
récent** sur les opérations en crédit. Chaque imputation est tracée dans le
document (`imputations`) pour permettre l'inversion exacte à la suppression.

### Annulation plutôt que suppression

Ventes et appros ne se suppriment pas : ils passent en `statut: 'annulee'`
avec un `motifAnnulation`, et la transaction réinjecte le stock. Seul le
super-admin peut supprimer (bypass de l'audit).

### Numérotation séquentielle

`counters/{boutiqueId}` porte des champs `ventes{ANNEE}` / `appros{ANNEE}`
incrémentés dans la transaction. Les documents stockent aussi un numéro
lisible dénormalisé pour rester corrects hors ligne.

### Dénormalisation volontaire

Certains libellés sont copiés au moment de l'opération — `natureNom` sur une
dépense, `clientNomLibre` sur une vente, `numero` dans une imputation. C'est
délibéré : l'historique et les reçus restent lisibles même si la référence est
renommée ou supprimée.

### Abonnements

Chaque boutique a un `subscriptionEndsAt`. Au-delà, une **période de grâce**
(`parametres/abonnement.graceDays`) laisse l'accès ouvert avec un bandeau
d'alerte ; ensuite la connexion est refusée. Vérifié au login
(`LoginController`), au démarrage (`SplashController`) et en continu par le
stream boutique de `UserController`.

### Login hybride téléphone / email

L'utilisateur peut se connecter avec son numéro. `phone_index/{telephone}`
mappe le numéro vers l'email, résolu **avant** l'appel à Firebase Auth. Cette
collection est en **lecture publique** — l'utilisateur n'est pas encore
authentifié à ce stade.

---

## 7. Sécurité et index

### `firestore.rules`

576 lignes, organisées par collection, avec des helpers (`isSuperAdmin()`,
`ownsBoutique()`, `createBoutiqueIdMatches()`…). Politique générale :

- lecture : tout utilisateur actif de la boutique
- catalogue (produits, catégories, natures de dépense) : **admin**
- opérations (ventes, clients, règlements, appros) : **gestionnaire**
- suppressions en bypass d'audit : **super-admin**

L'en-tête du fichier indique une publication manuelle via la console. Attention
donc : `firebase deploy --only firestore:rules` **écrase** ce qui est en ligne.
Vérifier que la console et le fichier sont alignés avant de déployer.

### `firestore.indexes.json`

26 index composites. **Tout `where` combiné à un `orderBy` sur un autre champ
en exige un.** Sans l'index, la requête échoue en `FAILED_PRECONDITION`.

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Piège rencontré : pour le super-admin, `scopeBoutiqueId` vaut `null`, donc la
requête perd son filtre `boutiqueId` et n'utilise plus le même index. Un
`where('active').orderBy('nom')` sans `boutiqueId` n'a pas d'index — d'où
plusieurs filtres volontairement faits **côté client** (voir
`CategoriesController`, `NatureDepenseRepository`).

---

## 8. Pièges connus

Chacun a déjà coûté un bug en production ou en revue.

### `Obx` ne voit que ce qui est lu dans son builder

Les enfants d'un `ListView` sont construits **paresseusement** : un observable
lu dans `itemBuilder` l'est hors du scope de l'`Obx`.

```dart
// ✗ « improper use of a GetX » : periode.value lu trop tard
Obx(() => ListView.builder(itemBuilder: (_, i) => Tab(c.periode.value)))

// ✓ lecture dans le builder, puis Row construite immédiatement
Obx(() { final p = c.periode.value; return Row(children: [...]); })
```

Même logique pour les libellés résolus en `itemBuilder` (`userNom()`,
`boutiqueNom()`) : lire la liste source dans le builder, sinon l'arrivée du
stream ne redessine rien.

### `Get.back()` après `Get.snackbar()`

`Get.snackbar` empile sa **propre route**. Un `Get.back()` qui suit ferme le
snackbar, pas le sheet. Fermer **d'abord**, notifier ensuite — ou utiliser
`Navigator.of(context).pop()`.

### `TextEditingController` dans un dialogue

Le disposer dès que `Get.dialog` rend la main le détruit pendant l'animation
de fermeture (« used after being disposed »). Il doit vivre dans le `State`
d'un `StatefulWidget` dédié — voir `ConfirmPurgeDialog`.

### Lectures réseau au démarrage

Un `get()` Firestore n'a **aucun timeout**, et `Source.server` interdit le
repli sur cache : sur réseau lent, le Future ne se résout jamais et le splash
se fige. Un `try/catch` n'y peut rien. Toute lecture bloquante doit être bornée
— voir `core/utils/network_timeouts.dart`.

### `DropdownButtonFormField`

Une valeur sélectionnée absente des `items` (entité supprimée entre-temps)
lève une exception. Toujours valider avant d'affecter :

```dart
final safe = liste.any((e) => e.id == valeur) ? valeur : null;
```

### Sous-collections

Firestore n'a **pas** de `ON DELETE CASCADE`. Supprimer un produit laisse ses
variantes orphelines : invisibles, inatteignables, toujours facturées. Les
purger explicitement **avant** le parent (voir `MaintenanceRepository`).

### Ne pas lancer `dart format` sur un fichier existant

Le code n'est pas formaté au standard `dart format` : le lancer produit ~140
lignes de diff cosmétique qui noient le changement réel. Modifier à la main en
suivant le style du fichier.

---

## 9. Conventions

- **Commentaires en français**, et réservés au *pourquoi* — jamais la
  paraphrase du code. Les règles métier et les contournements sont documentés
  à l'endroit où ils s'appliquent.
- **Couleurs** : toujours `AppColors.primary(context)` / `AppColors.greyText(context, n)`,
  jamais de couleur codée en dur — le thème clair/sombre en dépend.
- **Formats** : `Fmt.money`, `Fmt.number`, `Fmt.dateShort`, `Fmt.dateTime`
  (`core/utils/format_helpers.dart`).
- **Routes** : constantes de `AppRoutes`, jamais de chaîne littérale.
- **Bottom sheets** : `wrapBottomSheet` / `androidOnlySafeArea` /
  `kBottomSheetMaxHeightRatio` (`core/utils/bottom_sheet_helpers.dart`).

### Avant de livrer

```bash
flutter analyze        # doit être à zéro problème
flutter test           # suite Dart
node --test scripts/test/marges.test.js   # suite des scripts
flutter build bundle --debug
```

Le projet est maintenu **sans aucun avertissement d'analyse**. Le conserver.

---

## 10. Outillage

### Scripts d'administration — `scripts/`

`purge_boutique.js` utilise le **SDK Admin**, qui contourne les règles
Firestore. À lancer depuis un poste de confiance. Voir `scripts/README.md`.

### Écran de purge intégré

Drawer → **« Purge des données »** (super-admin uniquement). Permet de vider
collection par collection les données d'**une seule** boutique, avec le compte
réel affiché avant action et confirmation par recopie du nom de la boutique.

Le même écran porte la carte **« Marges des ventes passées »** (*Analyser* puis
*Figer*), qui ne supprime rien — voir § 6. Deux détails de fonctionnement :

- Le comptage **n'est pas lancé à l'ouverture** de l'écran. Firestore ne sait
  pas interroger l'*absence* d'un champ : il faut parcourir toutes les ventes
  de la boutique et trier côté client (`MaintenanceRepository._parcourirVentes`,
  pages de 300 triées sur `FieldPath.documentId`). Payer ces lectures à chaque
  visite de l'écran serait inutile.
- L'écriture se fait par lots de 400 **depuis le téléphone**. Si l'opération
  est interrompue, seule une partie des ventes est figée ; l'écran recompte et
  il suffit de relancer, les ventes déjà figées étant ignorées.

**Faire une sauvegarde avant.** Firestore n'a pas de corbeille :

```bash
gcloud firestore export gs://gongorevente.firebasestorage.app/backup-$(date +%F) \
  --project=gongorevente
```

(Nécessite le plan Blaze. Sinon : console Firebase → Firestore → Import/Export.)

---

## 11. État actuel et pistes

### Terminé récemment

- Module **Dépenses** complet : natures paramétrables par l'admin, déclaration
  par admin et gestionnaire, intégration aux rapports et au tableau de bord
- **Filtres** catégorie / produit / client dans la liste des ventes, avec
  recherche, plus une carte « Articles vendus »
- Écran de **purge** des données d'une boutique
- **Timeouts** sur les lectures réseau du démarrage
- **Lot 1 — marge figée** : marges calculées et enregistrées à la validation
  de la vente, masquage des marges pour le gestionnaire, reprise de
  l'historique au prix d'achat actuel depuis l'écran de purge
- **iOS** : adoption d'UIScene et cible iOS 15 pour Xcode 27

### Dette connue

- **Tests encore très partiels** — seuls le calcul des marges et la
  reconstitution du CMUP sont couverts (`test/marge_calculator_test.dart`,
  `scripts/test/marges.test.js`). Les transactions elles-mêmes (stock, FIFO,
  soldes client et fournisseur) n'ont aucun test, alors qu'elles sont le cœur
  critique.
- `vente_form_view.dart` et `appro_form_view.dart` dépassent 2 500 lignes et
  gagneraient à être découpés en widgets.
- `README.md` est resté le template Flutter par défaut.
- **Le lot 1 n'a pas été recetté** sur des données réelles, et la reprise de
  l'historique n'a été appliquée sur **aucune** boutique. Le test qui compte :
  valider une vente, faire un appro qui change le CMUP du produit, et vérifier
  que la marge de cette vente ne bouge plus dans les rapports.
- **Règles et index Firestore du module Dépenses peut-être non déployés** — le
  déploiement a échoué sur une erreur de `firebaserules.googleapis.com`. Les
  fichiers sont à jour (`firestore.rules`, collections `depenses` et
  `naturesDepense` ; `firestore.indexes.json`). À rejouer :
  `firebase deploy --only firestore:rules,firestore:indexes`.
- `flutter build ios --simulator` reste cassé (cf. § 2), en attente d'un
  `flutter upgrade`.

### Chantier en discussion

Rendre le **prix unitaire modifiable** dans le panier (marchandage). `prixUnitaire`
est déjà figé par ligne et copié dans `VenteArticle`, donc l'architecture s'y
prête. Trois points restent à trancher : que devient la remise de ligne (doublon
fonctionnel), faut-il alerter sous le prix d'achat, et qui en a le droit
(gestionnaire ou admin seul).

---

## 12. Par où commencer

1. Lancer l'app et se connecter avec un compte **super-admin** pour voir
   l'ensemble, puis avec un **admin** et un **gestionnaire** — les écrans
   changent beaucoup selon le rôle.
2. Lire `UserController` et `route_guards.dart` : tout le cloisonnement en
   découle.
3. Lire `firestore.rules` en parallèle d'un repository (par exemple
   `vente_repository.dart`) pour voir comment requêtes et règles s'alignent.
4. Suivre un parcours complet de bout en bout — créer un produit, faire un
   appro, vendre, encaisser — en observant les transactions dans la console
   Firestore.
5. Prendre un module simple comme modèle avant d'en écrire un nouveau :
   `modules/admin/depenses/` est le plus récent et le plus représentatif des
   conventions actuelles.
