'use strict';

/**
 * Calcul des marges et reconstitution du CMUP historique.
 *
 * ⚠️  PORTAGE DE `lib/app/core/utils/marge_calculator.dart`.
 *     La transaction de vente (Dart) et ce script (SDK Admin, Node) doivent
 *     produire EXACTEMENT les mêmes valeurs, sinon une vente reprise et une
 *     vente récente ne seraient pas comparables. Les deux implémentations
 *     sont couvertes par les mêmes jeux de cas :
 *       - test/marge_calculator_test.dart
 *       - scripts/test/marges.test.js
 *     Toute modification ici doit être reportée là-bas, et inversement.
 */

/**
 * Répartit la remise globale sur les lignes, au prorata du montant net.
 *
 * La dernière part est déduite par différence : la somme des parts est
 * ainsi exactement égale à la remise, malgré les erreurs flottantes.
 */
function repartirRemiseGlobale(articles, remiseGlobale) {
  const n = articles.length;
  if (n === 0) return [];
  if (!(remiseGlobale > 0)) return new Array(n).fill(0);

  const net = (a) => a.prixUnitaire * a.quantite - (a.remise || 0);
  const base = articles.reduce((acc, a) => acc + net(a), 0);
  const parts = new Array(n).fill(0);

  // Base nulle : prorata impossible, on verse tout sur la dernière ligne
  // plutôt que de perdre la remise.
  if (!(base > 0)) {
    parts[n - 1] = remiseGlobale;
    return parts;
  }

  let cumul = 0;
  for (let i = 0; i < n - 1; i++) {
    const part = remiseGlobale * (net(articles[i]) / base);
    parts[i] = part;
    cumul += part;
  }
  parts[n - 1] = remiseGlobale - cumul;
  return parts;
}

/**
 * Calcule les marges d'une vente.
 *
 * `prixAchatParProduit` : CMUP en vigueur au moment de la vente, par
 * `produitId`. Un produit absent est traité comme un coût nul — la ligne
 * compte alors en totalité, volontairement visible plutôt qu'écartée.
 */
function calculerMarges(articles, remiseGlobale, prixAchatParProduit) {
  if (!articles || articles.length === 0) {
    return { articles: [], coutAchatTotal: 0, margeTotale: 0 };
  }
  const parts = repartirRemiseGlobale(articles, remiseGlobale);
  const net = (a) => a.prixUnitaire * a.quantite - (a.remise || 0);

  let coutAchatTotal = 0;
  let margeTotale = 0;
  const enrichies = articles.map((a, i) => {
    const pa = prixAchatParProduit[a.produitId] || 0;
    const cout = pa * a.quantite;
    const marge = net(a) - parts[i] - cout;
    coutAchatTotal += cout;
    margeTotale += marge;
    return {
      ...a,
      prixAchatUnitaire: pa,
      remiseGlobaleAllouee: parts[i],
      marge,
    };
  });

  return { articles: enrichies, coutAchatTotal, margeTotale };
}

/**
 * Rejoue l'historique d'un produit pour retrouver le CMUP en vigueur à la
 * date de chaque vente.
 *
 * `evenements` : liste triée par date, chaque élément valant
 *   { date, type: 'appro'|'vente'|'mouvement', ... }
 *
 * Deux points que la lecture naïve du code manquerait, et qui changent le
 * résultat :
 *
 *   1. L'annulation d'un appro NE recalcule PAS le CMUP
 *      (`ApprovisionnementRepository.cancel` : « sans toucher au PA car le
 *      CMUP historique est perdu »). Un appro annulé a donc durablement
 *      modifié le prix d'achat : on rejoue TOUS les appros, y compris
 *      annulés, et leur annulation ne retire que le stock.
 *
 *   2. Le CMUP dépend du stock au moment de l'appro. Les mouvements de
 *      stock manuels (sortie, perte, casse, ajustement) le modifient aussi :
 *      les ignorer fausserait le dénominateur de tous les appros suivants.
 *
 * Renvoie { cmupParVente: Map<venteId, number>, repli: string|null }.
 * `repli` non nul signale une incohérence : l'appelant doit alors utiliser
 * le prix d'achat actuel et inscrire le produit au rapport (RG-12).
 */
function rejouerCmup(evenements) {
  let stock = 0;
  let cmup = 0;
  let vuUnAppro = false;
  let repli = null;
  const cmupParVente = new Map();

  for (const e of evenements) {
    switch (e.type) {
      case 'appro': {
        // Même garde-fou que la transaction Dart : un stock négatif ou nul
        // ne pondère pas l'ancien CMUP.
        const qteEffective = stock < 0 ? 0 : stock;
        const qteTotale = qteEffective + e.quantite;
        if (!(e.prixAchatUnitaire >= 0)) {
          repli = repli || 'appro sans prix d achat exploitable';
        }
        if (qteTotale === 0) {
          // Garde-fou du code applicatif : on conserve le CMUP courant.
        } else {
          cmup =
            (qteEffective * cmup + e.prixAchatUnitaire * e.quantite) /
            qteTotale;
        }
        stock += e.quantite;
        vuUnAppro = true;
        break;
      }
      case 'approAnnule':
        // L'annulation ne touche pas le PA, seulement le stock.
        stock -= e.quantite;
        break;
      case 'vente':
        if (!vuUnAppro) {
          repli = repli || 'vente anterieure a tout approvisionnement';
        }
        cmupParVente.set(e.venteId, cmup);
        // Une vente annulée a bien retiré puis rendu le stock : son effet
        // net est nul, l'appelant ne la fait donc pas bouger le stock.
        if (!e.annulee) stock -= e.quantite;
        if (stock < 0) {
          repli = repli || 'stock reconstitue negatif';
        }
        break;
      case 'mouvement':
        // `delta` déjà signé : positif = entrée, négatif = sortie.
        stock += e.delta;
        if (stock < 0) {
          repli = repli || 'stock reconstitue negatif';
        }
        break;
      default:
        repli = repli || `type d evenement inconnu : ${e.type}`;
    }
  }

  return { cmupParVente, repli };
}

module.exports = { repartirRemiseGlobale, calculerMarges, rejouerCmup };
