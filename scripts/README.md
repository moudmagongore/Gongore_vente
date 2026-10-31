# Scripts d'administration Firestore

Hors application Flutter. À lancer depuis un poste de confiance.

## Installation

```bash
cd scripts
npm install
```

## Authentification

Le SDK Admin **contourne les règles Firestore** : il a tous les droits.
Deux options :

```bash
# 1. Clé de compte de service (Console Firebase > Paramètres > Comptes de service)
export GOOGLE_APPLICATION_CREDENTIALS=/chemin/serviceAccountKey.json

# 2. Ou identifiants gcloud
gcloud auth application-default login
gcloud config set project gongorevente
```

Ne commitez jamais la clé de service dans le dépôt.

## purge_boutique.js

Vide les données d'**une seule** boutique. Les autres ne sont pas touchées.

```bash
# 1. Toujours commencer par l'essai à blanc : compte, ne supprime rien
node purge_boutique.js --boutique=<ID>

# 2. Suppression réelle
node purge_boutique.js --boutique=<ID> --confirm

# Cibler une ou plusieurs collections
node purge_boutique.js --boutique=<ID> --only=produits
node purge_boutique.js --boutique=<ID> --only=ventes,reglements --confirm
```

### Périmètre

| Groupe | Collections | Inclus par défaut |
|---|---|---|
| Métier | ventes, reglements, approvisionnements, reglementsFournisseurs, mouvementsStock, depenses | oui |
| Catalogue | produits (+ variantes), categories, clients, fournisseurs, naturesDepense | oui |
| Compteurs | counters/&lt;boutiqueId&gt; | oui (sauf avec `--only`) |
| Utilisateurs | users | non — `--include-users` |
| Abonnements | abonnements | non — `--include-abonnements` |
| Fiche boutique | boutiques/&lt;boutiqueId&gt; | non — `--delete-boutique` |

### Points d'attention

- **Suppression définitive.** Firestore n'a pas de corbeille. Faites un export
  avant : `gcloud firestore export gs://<bucket>/backup-$(date +%F)`
- **`--include-users` ne supprime que les documents Firestore**, pas les
  comptes Firebase Auth : les utilisateurs pourraient encore s'authentifier
  sans profil. Supprimez-les aussi dans Authentication, et pensez à
  `phone_index` (indexé par numéro, pas par boutique).
- **Purge partielle = références orphelines.** Vider seulement `produits`
  laisse les ventes pointer vers des produits inexistants : les rapports et
  le calcul de bénéfice s'appuient sur `prixAchat` du produit. Pour repartir
  proprement, videz métier + catalogue ensemble.
- **Les sous-collections ne suivent pas leur parent.** Supprimer un produit
  laisse ses `variantes` orphelines et invisibles dans la console. Le script
  les purge explicitement, avant les produits.

---

## `backfill_marges_ventes.js` — reprise des marges (Lot 1)

Reconstitue le prix d'achat (CMUP) réellement en vigueur à la date de chaque
vente passée, puis écrit les marges figées (`prixAchatUnitaire`,
`remiseGlobaleAllouee`, `marge` sur les lignes ; `coutAchatTotal` et
`margeTotale` sur la vente).

```bash
node backfill_marges_ventes.js --boutique=<ID>           # essai à blanc
node backfill_marges_ventes.js --all                     # essai, toutes
node backfill_marges_ventes.js --all --csv=rapport.csv   # + export CSV
node backfill_marges_ventes.js --boutique=<ID> --apply   # écriture réelle
```

**Le mode par défaut est un essai à blanc** : il n'écrit rien et produit le
rapport (marge avant / après / écart, produits en repli). `--apply` n'est à
lancer qu'après validation de ce rapport par le chef de projet, et **après
une sauvegarde Firestore** (voir `ONBOARDING.md` §10).

Une vente qui porte déjà ses valeurs de marge n'est jamais réécrite : le
script est donc rejouable sans risque.

### Comment le CMUP est reconstitué

Le rejeu ne se contente pas des appros non annulés, pour deux raisons
vérifiées dans le code applicatif :

1. **L'annulation d'un appro ne recalcule pas le prix d'achat**
   (`ApprovisionnementRepository.cancel` : « sans toucher au PA car le CMUP
   historique est perdu »). Son effet sur le PA persiste donc : on rejoue
   **tous** les appros, l'annulation ne reprenant que le stock.
2. **Le CMUP dépend du stock au moment de l'appro.** Les mouvements de stock
   manuels (sortie, perte, casse, ajustement) le modifient aussi : les
   ignorer fausserait le dénominateur de tous les appros suivants.

Les cas où la reconstitution n'est pas fiable (stock reconstitué négatif,
vente antérieure à tout appro, appro sans prix exploitable) basculent sur le
**prix d'achat actuel**, et le produit est listé dans le rapport.

### Tests

La logique de calcul et de rejeu est dans `lib/marges.js`, testée sans
dépendance :

```bash
node --test test/marges.test.js
```

⚠️ `lib/marges.js` est un **portage** de
`lib/app/core/utils/marge_calculator.dart`. Les deux implémentations doivent
rester synchronisées : les mêmes cas sont rejoués dans
`test/marge_calculator_test.dart`.
