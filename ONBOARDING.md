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

### Accès aux caisses — par utilisateur, pas par rôle

Les caisses sont la seule donnée dont l'accès ne se déduit **pas** du rôle :
l'admin choisit, caisse par caisse, quels gestionnaires y ont accès
(`gestionnaireIds`). Un gestionnaire qui n'y figure pas ne voit pas la caisse,
y compris en lecture directe en base.

Conséquence sur les requêtes : côté gestionnaire, elles **doivent** filtrer
avec `array-contains` sur son uid. Sans ce filtre, Firestore refuse la requête
entière — pas seulement les documents hors de sa portée. Un admin, même
cumulant le rôle gestionnaire, passe par la branche admin et voit toutes les
caisses de sa boutique.

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
parametres                phone_index            caisses
mouvementsCaisse
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

### Caisses et mouvements

**Le module est ouvert boutique par boutique par le super-admin**
(`boutiques/{id}.caissesActivees`, réglé depuis le formulaire boutique). Par
défaut **fermé** : une boutique qui n'a pas le module se comporte exactement
comme avant — caisses masquées, sélecteur de mode de paiement de retour, aucun
solde touché. Les caisses et mouvements déjà enregistrés sont **conservés** et
réapparaissent intacts si on rouvre le module.

Le verrou a **un seul point de vérité**, `UserController.caissesModuleActif`,
et **un seul point de passage** pour les données :
`CaisseContexte.watchCaisses(scope)`. Les quatorze écrans qui chargent des
caisses passent par là plutôt que par le repository, ce qui ferme le module
partout d'un coup : liste vide ⇒ chaque écran retombe de lui-même sur le
comportement RG-9, déjà recetté. Un nouvel écran qui appellerait
`CaisseRepository` en direct contournerait le verrou — ne pas le faire.
S'ajoutent le masquage des entrées de drawer et `CaisseGuard` sur les trois
routes de caisse.

Une **caisse** est un compte de trésorerie de la boutique : tiroir espèces,
Orange Money, compte bancaire. L'admin les crée, le gestionnaire n'y a accès
que si son uid figure dans `gestionnaireIds` de la caisse.

Quatre invariants, dans cet ordre d'importance :

1. **Le solde n'est jamais écrit directement.** Il ne bouge que par des
   mouvements, et uniquement via `CaisseRepository.appliquerPaiements`, à
   l'intérieur de la transaction de l'opération qui provoque le mouvement.
   C'est pourquoi `CaisseModel.toMapParametres()` **ne contient pas**
   `solde` : un enregistrement du formulaire ne doit pas pouvoir écraser le
   solde avec la valeur chargée à l'ouverture de l'écran.
2. **Un mouvement n'est jamais modifié ni supprimé.** Une erreur se corrige
   par un mouvement inverse (annulation) ou une correction de l'admin. Seul
   le super-admin supprime.
3. **Une caisse qui a servi (`hasMouvements`) ne se supprime plus**, elle se
   désactive. Une caisse désactivée disparaît des opérations mais reste
   créditable : sinon une vente payée dessus deviendrait impossible à
   annuler. D'où le paramètre `exigerActive` de `planifierPaiements`, mis à
   `false` par les annulations.
4. **Tant qu'une boutique n'a aucune caisse active, les opérations
   fonctionnent comme avant** : aucune caisse n'est créée automatiquement,
   et une liste de paiements vide n'écrit rien.

5. **`boutiques/{id}.hasCaissesActives`** dit si la boutique a au moins une
   caisse active. Ce drapeau existe parce qu'un gestionnaire ne peut pas lire
   les caisses auxquelles il n'a pas accès : sans lui, il ne pourrait pas
   distinguer « cette boutique n'a pas de caisse » (il opère comme avant) de
   « elle en a, mais aucune pour moi » (ses opérations payées sont bloquées,
   RG-19). Maintenu par `CaisseRepository` après chaque paramétrage, et
   **absent de `BoutiqueModel.toMap()`** pour qu'un enregistrement du
   formulaire boutique ne l'écrase pas.

Le calcul vit dans `core/utils/caisse_calculator.dart` (pur, sans Firestore
ni GetX, testé par `test/caisse_calculator_test.dart`) : regroupement des
lignes par caisse, contrôle du solde négatif, calcul du `soldeApres`. Le
repository lit les caisses dans la transaction, appelle ce calcul, puis écrit.

**Toutes les opérations sont branchées** : dépenses, règlements client et
fournisseur, arrivages, ventes.

**Ce qui transite par les caisses est `montantPaye`, jamais `total`.** C'est le
piège central du module :

- sur une **vente**, la part non payée part en crédit client ; une vente
  entièrement à crédit ne touche aucune caisse ;
- sur un **arrivage**, elle devient une dette fournisseur ;
- `avanceUtilisee` **n'entre dans aucune caisse** : cet argent y est entré plus
  tôt, lors du règlement qui a créé l'avance. Calculer la répartition sur
  `total - resteAPayer` le compterait deux fois.

La saisie de la répartition est le widget partagé
`core/widgets/paiements_caisse_field.dart` (lignes caisse + montant, reste à
répartir ; le montant d'une ligne unique suit automatiquement celui de
l'opération). `PaiementsCaisseBloc`, dans le même fichier, y ajoute les quatre
états d'un formulaire autonome — chargement, boutique sans caisse, aucune
caisse accessible, saisie normale — en s'appuyant sur
`core/utils/caisse_contexte.dart`.

### Mode de paiement : remplacé par la caisse

`ModePaiement` (Espèces / Orange Money / Mobile Money / Paycard) désignait le
même axe que les caisses. Il est donc **retiré des formulaires dès qu'une
caisse existe**, et le champ n'est plus écrit du tout dans ce cas : sur
`ReglementModel` et `ReglementFournisseurModel` il est devenu **nullable**,
`null` signifiant « c'est `paiements` qui dit où est l'argent ».

Deux conséquences à connaître :

- l'affichage passe par le getter **`libellePaiement`** : les noms de caisses
  s'il y en a, sinon l'ancien mode, sinon `—`. Jamais de valeur par défaut
  inventée — six écrans et deux reçus en dépendent, d'où
  `test/libelle_paiement_test.dart` ;
- le filtre des listes de règlements montre **les caisses** quand la boutique
  en a, et retombe sur les modes sinon. Sans ça, un filtre « Espèces » aurait
  silencieusement masqué tous les règlements récents.

Le sélecteur de mode **reste affiché tant que la boutique n'a aucune caisse** :
c'est RG-9 — sans caisse, l'opération se comporte exactement comme avant, et
l'information ne doit pas être perdue.

La **ventilation du CA** des rapports et du tableau de bord
(`caParCanalPaiement`) est désormais indexée par **libellé** et non par l'enum :
une même période contient des ventes encaissées sur des caisses (« Tiroir
espèces ») et des ventes antérieures qui ne portent qu'un mode (« Espèces »).
Une vente encaissée sur plusieurs caisses compte une fois par caisse, au
prorata — sinon un paiement mixte faussserait le total.

### Transferts, apports, retraits, corrections

Quatre mouvements sans opération derrière eux, dans `CaisseRepository` :

- **transfert** (`transferer`) : une sortie et une entrée écrites ensemble,
  liées par un `transfertId`. La règle du solde négatif ne s'applique qu'à la
  source. L'admin transfère entre toutes ses caisses, le gestionnaire
  seulement entre deux caisses qui lui sont accessibles — son stream ne
  contient que celles-là, le filtrage est donc automatique ;
- **apport / retrait / correction** (`mouvementManuel`) : réservés à l'admin,
  **motif obligatoire**. Une correction peut viser une caisse désactivée,
  c'est tout l'intérêt : rattraper un solde faux sur une caisse qu'on
  n'utilise plus.

Ces quatre-là ne sont **ni des ventes ni des dépenses** : ils ne vivent que
dans `mouvementsCaisse`, qu'aucun rapport de vente ne lit. Ils n'entrent donc
pas dans le chiffre d'affaires, les charges ni les marges (RG-28).

`annulerMouvement` écrit l'inverse d'un mouvement, jamais ne le supprime.
Trois garde-fous à connaître :

- un mouvement **issu d'une opération** est refusé : on annule l'opération
  elle-même, sinon stock, soldes client et marges resteraient inchangés ;
- un **transfert** compense ses **deux** mouvements. La paire est retrouvée par
  une requête sur `transfertId` faite **hors** transaction (Firestore n'y
  autorise pas de requête), puis chaque document est relu dedans ;
- l'auteur du mouvement de compensation est **celui qui annule**, pas l'auteur
  d'origine : les règles exigent `userId == request.auth.uid` à la création.

Pour un transfert, le droit du gestionnaire (RG-24 : les **deux** caisses
doivent lui être accessibles) est tranché par les règles Firestore et non par
l'écran — le relevé ne montre qu'une caisse, il ne peut pas savoir si l'autre
moitié lui est ouverte. Le bouton reste donc proposé, et `annulerMouvement`
traduit le `permission-denied` en message métier. Choix assumé : cacher le
bouton demanderait de charger le mouvement jumeau à chaque affichage.

### Relevé de caisse

`modules/admin/caisses/` → `releve_caisse_*`. Le solde de départ se calcule de
deux façons, selon que la période contient des mouvements : s'il y en a, il se
déduit du plus ancien (`soldeApres - montantSigne`, aucune lecture de plus) ;
sinon il faut aller chercher le dernier mouvement antérieur
(`dernierMouvementAvant`), sans quoi on ne distinguerait pas une caisse à zéro
d'une caisse pleine mais inactive sur la période.

Le relevé est **toujours mono-caisse** — voir § 7. L'export PDF est en A4 et
non en 80 mm : c'est un document de contrôle, pas un ticket client.

Côté dépense, deux conséquences du gel des mouvements :

- **le montant devient immuable** dès qu'une caisse a payé la dépense —
  verrouillé par les règles Firestore, pas seulement par l'écran. Pour
  corriger, on supprime et on ressaisit ;
- **la suppression recrédite les caisses** par un mouvement inverse de type
  `annulation` pointant vers le mouvement d'origine. C'est l'idiome déjà
  retenu pour les règlements (`deleteAndRestore`), les ventes et arrivages
  utilisant plutôt `cancel` avec un statut.

Deux pièges de cette mécanique :

- `appliquerPaiements` **lit puis écrit**. Firestore interdit toute lecture
  après une écriture dans une même transaction : l'appeler après le premier
  `tx.set` de l'opération lève une erreur à l'exécution.
- Le contrôle « la boutique a-t-elle une caisse ? » **ne peut pas** se faire
  dans la transaction : Firestore n'y autorise que des `get` par référence,
  pas de requête. Il est donc applicatif (la liste chargée par le
  formulaire), et c'est une limite assumée.

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

### Mouvements de caisse : relevé mono-caisse obligatoire

La règle de lecture de `mouvementsCaisse` contrôle l'accès du gestionnaire par
un `get()` sur la caisse du mouvement. Firestore mutualise les `get()`
identiques d'une même requête : un relevé filtré sur **un** `caisseId` ne coûte
donc qu'une lecture de plus. Une requête portant sur plusieurs caisses
exploserait la limite de 10 accès documentaires par requête. Les relevés
filtrent toujours sur une caisse précise — ce n'est pas un choix d'ergonomie.

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

### Écrire dans un `TextEditingController` pendant le build

Rencontré pour de vrai sur `paiements_caisse_field.dart` :

```
setState() or markNeedsBuild() called during build.
This Form widget cannot be marked as needing to build...
The widget which was currently being built when the offending call was
made was: Obx
```

Affecter `ctrl.text` notifie les auditeurs du contrôleur, dont le `FormField`
qui l'entoure, qui demande au `Form` de se reconstruire. Depuis `initState` ou
depuis un `onTap`, aucun problème. Depuis **`didUpdateWidget`** — déclenché
par un `Obx` parent qui se reconstruit — le `Form` est déjà en cours de
construction, et Flutter refuse.

Le remède est un `addPostFrameCallback` **autour de l'écriture**, pas
seulement autour de la notification au parent, avec les conditions
revérifiées dedans : une frame s'est écoulée, l'état a pu changer.

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

### Une transaction Firestore n'accepte aucune lecture après une écriture

`CaisseRepository.appliquerPaiements` **lit puis écrit**. Appelée après le
premier `tx.set` de l'opération, elle lève une erreur à l'exécution. Dans les
cinq opérations branchées, elle est donc invoquée juste à la frontière entre la
phase de lecture et la phase d'écriture — voir le commentaire `Étape 1b` /
`Étape 1c` dans chaque repository. En ajouter une sixième, c'est respecter cet
ordre.

Corollaire : **aucune requête n'est possible dans une transaction**, seulement
des `get` par référence. C'est pourquoi la paire de mouvements d'un transfert
est retrouvée *avant* d'ouvrir la transaction, et pourquoi le contrôle « cette
boutique a-t-elle une caisse ? » passe par le drapeau dénormalisé
`boutiques/{id}.hasCaissesActives` plutôt que par un comptage.

### L'auteur d'un mouvement de caisse doit être celui qui l'écrit

Les règles imposent `request.resource.data.userId == request.auth.uid` à la
création d'un `mouvementsCaisse`. Un mouvement de compensation doit donc porter
l'uid de **celui qui annule**, jamais celui de l'auteur du mouvement d'origine —
sinon l'écriture est refusée dès qu'une autre personne annule.

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
flutter test           # 51 tests Dart
node --test scripts/test/marges.test.js   # 18 tests, suite des scripts
flutter build bundle --debug
```

Le projet est maintenu **sans aucun avertissement d'analyse**. Le conserver.

Ces suites ne couvrent que les calculs purs : **elles ne disent rien sur les
transactions**. Toute modification touchant au stock, aux soldes ou aux
caisses demande une recette manuelle sur un appareil, avec les trois rôles
(cf. § 11).

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
  l'historique au prix d'achat actuel depuis l'écran de purge. **Recetté et
  reprise appliquée** (octobre 2026)
- **iOS** : adoption d'UIScene et cible iOS 15 pour Xcode 27
- **Lot 2 étape 2.1** : création et paramétrage des caisses, accès par
  gestionnaire, helper de mouvements testé. Recetté
- **Lot 2 complet** : caisses paramétrables, cinq opérations branchées,
  transferts, apports, retraits et corrections, relevé de caisse avec export
  PDF, trésorerie au tableau de bord et synthèse par caisse dans les rapports.
  **Recetté** (novembre 2026)
- **Module de caisse ouvert boutique par boutique** par le super-admin
  (`caissesActivees`), fermé par défaut. Recetté

### Dette connue

- **Les transactions sont vérifiées, mais pas protégées.** Les suites
  automatisées (51 tests Dart, 18 JS) couvrent les **calculs purs** :
  `marge_calculator_test.dart`, `caisse_calculator_test.dart`,
  `libelle_paiement_test.dart`, `scripts/test/marges.test.js`. Les
  transactions elles-mêmes — stock, FIFO, soldes client, fournisseur et
  caisse — ont été validées **par recette manuelle à chaque lot** et
  fonctionnent. Mais rien ne les protège d'une régression : une modification
  qui les casse passera l'analyse, les tests et le build sans alerte, et ne
  se verra qu'en production. C'est le cœur critique de l'application, et le
  chantier de test qui aurait le plus de valeur.
- `vente_form_view.dart` et `appro_form_view.dart` dépassent 2 500 lignes et
  gagneraient à être découpés en widgets.
- `README.md` est resté le template Flutter par défaut.
- **Le repli sur l'ancien calcul de marge est désormais du code mort** pour les
  boutiques reprises (`dashboard_controller.dart`, `rapports_controller.dart` :
  les branches après `if (v.aMargeFigee)`). Il reste utile tant qu'une boutique
  n'a pas été reprise — une boutique créée avant le lot et jamais passée par
  l'écran de purge. À retirer quand c'est vrai partout, pas avant.
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
