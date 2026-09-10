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
