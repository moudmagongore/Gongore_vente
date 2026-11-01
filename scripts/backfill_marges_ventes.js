#!/usr/bin/env node
/**
 * Reprise des marges sur les ventes déjà enregistrées (Lot 1).
 *
 * Avant ce lot, la marge d'une vente était recalculée à chaque affichage
 * avec le prix d'achat ACTUEL du produit. Ce script reconstitue le prix
 * d'achat réellement en vigueur à la date de chaque vente, en rejouant
 * l'historique, puis écrit les marges figées.
 *
 * ⚠️  Mode ESSAI À BLANC par défaut : aucune écriture. Il faut `--apply`,
 *     et uniquement après validation du rapport par le chef de projet.
 *     Faire une sauvegarde Firestore avant (voir ONBOARDING.md §10).
 *
 * Usage :
 *   node backfill_marges_ventes.js --boutique=<ID>            # essai
 *   node backfill_marges_ventes.js --all                      # essai, tout
 *   node backfill_marges_ventes.js --all --csv=rapport.csv    # + export
 *   node backfill_marges_ventes.js --boutique=<ID> --apply    # écriture
 *
 * Authentification (au choix) :
 *   export GOOGLE_APPLICATION_CREDENTIALS=/chemin/serviceAccountKey.json
 *   ou   gcloud auth application-default login
 */

'use strict';

const fs = require('fs');
const { calculerMarges, rejouerCmup } = require('./lib/marges');

// --------------------------------------------------------------- arguments
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const value = (name) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : null;
};

const boutiqueId = value('boutique');
const all = flag('all');
const apply = flag('apply');
const csvPath = value('csv');

if (!boutiqueId && !all) {
  console.error('Erreur : --boutique=<ID> ou --all est obligatoire.');
  process.exit(1);
}

// Chargé seulement après la validation des arguments : sans cela, une
// erreur de syntaxe d'appel se traduirait par un « module introuvable »
// incompréhensible quand `npm install` n'a pas été fait.
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const money = (n) =>
  new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(n || 0);

// ------------------------------------------------------------------ lecture

async function lireBoutiques() {
  if (boutiqueId) {
    const snap = await db.collection('boutiques').doc(boutiqueId).get();
    if (!snap.exists) {
      console.error(`Boutique ${boutiqueId} introuvable.`);
      process.exit(1);
    }
    return [{ id: snap.id, nom: snap.get('nom') || snap.id }];
  }
  const snap = await db.collection('boutiques').get();
  return snap.docs.map((d) => ({ id: d.id, nom: d.get('nom') || d.id }));
}

const parBoutique = (col, bid) =>
  db.collection(col).where('boutiqueId', '==', bid).get();

/**
 * Construit, par produit, la liste des événements qui ont fait bouger le
 * stock ou le prix d'achat, triés par date.
 *
 * On inclut volontairement :
 *   - les appros ANNULÉS (leur effet sur le PA n'a jamais été défait) ;
 *   - les mouvements de stock manuels (ils changent le dénominateur du
 *     CMUP des appros suivants).
 * Voir `lib/marges.js` → `rejouerCmup` pour le détail.
 */
function construireEvenements({ appros, ventes, mouvements }) {
  const parProduit = new Map();
  const pousser = (pid, e) => {
    if (!parProduit.has(pid)) parProduit.set(pid, []);
    parProduit.get(pid).push(e);
  };

  for (const a of appros) {
    const date = a.date;
    const annule = a.statut === 'annulee';
    for (const art of a.articles || []) {
      pousser(art.produitId, {
        date,
        type: 'appro',
        quantite: art.quantite || 0,
        prixAchatUnitaire: art.prixAchatUnitaire,
      });
      if (annule) {
        // Même date : l'annulation suit immédiatement dans l'ordre de tri.
        pousser(art.produitId, {
          date,
          ordre: 1,
          type: 'approAnnule',
          quantite: art.quantite || 0,
        });
      }
    }
  }

  for (const v of ventes) {
    for (const art of v.articles || []) {
      pousser(art.produitId, {
        date: v.date,
        type: 'vente',
        venteId: v.id,
        quantite: art.quantite || 0,
        annulee: v.statut === 'annulee',
      });
    }
  }

  for (const m of mouvements) {
    // `qteApres - qteAvant` donne le delta signé sans avoir à interpréter
    // le type de mouvement (sortie, perte, casse, ajustement…).
    const delta = (m.qteApres || 0) - (m.qteAvant || 0);
    pousser(m.produitId, { date: m.date, type: 'mouvement', delta });
  }

  for (const liste of parProduit.values()) {
    liste.sort((x, y) => {
      const dx = x.date ? x.date.getTime() : 0;
      const dy = y.date ? y.date.getTime() : 0;
      if (dx !== dy) return dx - dy;
      return (x.ordre || 0) - (y.ordre || 0);
    });
  }
  return parProduit;
}

// ------------------------------------------------------------------ traitement

async function traiterBoutique(boutique) {
  const [approsSnap, ventesSnap, mouvSnap, produitsSnap] = await Promise.all([
    parBoutique('approvisionnements', boutique.id),
    parBoutique('ventes', boutique.id),
    parBoutique('mouvementsStock', boutique.id),
    parBoutique('produits', boutique.id),
  ]);

  const toDate = (t) => (t && t.toDate ? t.toDate() : null);

  const appros = approsSnap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
    date: toDate(d.get('date')),
  }));
  const ventes = ventesSnap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
    date: toDate(d.get('date')),
  }));
  const mouvements = mouvSnap.docs.map((d) => ({
    ...d.data(),
    date: toDate(d.get('date')),
  }));

  const prixAchatActuel = {};
  const nomProduit = {};
  for (const d of produitsSnap.docs) {
    prixAchatActuel[d.id] = d.get('prixAchat') || 0;
    nomProduit[d.id] = d.get('nom') || d.id;
  }

  const evenements = construireEvenements({ appros, ventes, mouvements });

  // Rejeu par produit → CMUP à la date de chaque vente.
  const cmupParProduitEtVente = new Map(); // pid -> Map(venteId -> cmup)
  const replis = []; // { produitId, nom, motif }
  for (const [pid, liste] of evenements) {
    const { cmupParVente, repli } = rejouerCmup(liste);
    cmupParProduitEtVente.set(pid, cmupParVente);
    if (repli) {
      replis.push({ produitId: pid, nom: nomProduit[pid] || pid, motif: repli });
    }
  }
  const produitsEnRepli = new Set(replis.map((r) => r.produitId));

  let margeAvant = 0; // calcul actuel, au prix du jour
  let margeApres = 0; // prix reconstitué
  let nbTraitees = 0;
  let nbDejaFigees = 0;
  const ecritures = [];

  for (const v of ventes) {
    if (v.margeTotale !== undefined && v.margeTotale !== null) {
      nbDejaFigees += 1; // jamais écrasé (RG : ne pas réécrire)
      continue;
    }
    nbTraitees += 1;

    const prixReconstitue = {};
    const prixDuJour = {};
    for (const art of v.articles || []) {
      const pid = art.produitId;
      prixDuJour[pid] = prixAchatActuel[pid] || 0;
      const reconstitue = produitsEnRepli.has(pid)
        ? undefined
        : (cmupParProduitEtVente.get(pid) || new Map()).get(v.id);
      prixReconstitue[pid] =
        reconstitue === undefined ? prixDuJour[pid] : reconstitue;
    }

    const avant = calculerMarges(v.articles || [], v.remise || 0, prixDuJour);
    const apres = calculerMarges(
      v.articles || [],
      v.remise || 0,
      prixReconstitue,
    );

    // Les ventes annulées reçoivent aussi leurs valeurs (homogénéité des
    // données) mais ne comptent pas dans les totaux du rapport.
    if (v.statut !== 'annulee') {
      margeAvant += avant.margeTotale;
      margeApres += apres.margeTotale;
    }

    ecritures.push({ id: v.id, apres });
  }

  return {
    boutique,
    nbVentes: ventes.length,
    nbTraitees,
    nbDejaFigees,
    margeAvant,
    margeApres,
    replis,
    ecritures,
  };
}

async function ecrire(ecritures) {
  // Lots de 400 : marge sous la limite Firestore de 500 écritures.
  const TAILLE = 400;
  let total = 0;
  for (let i = 0; i < ecritures.length; i += TAILLE) {
    const lot = db.batch();
    for (const e of ecritures.slice(i, i + TAILLE)) {
      lot.update(db.collection('ventes').doc(e.id), {
        articles: e.apres.articles,
        coutAchatTotal: e.apres.coutAchatTotal,
        margeTotale: e.apres.margeTotale,
      });
    }
    await lot.commit();
    total += Math.min(TAILLE, ecritures.length - i);
    process.stdout.write(`\r  écrites : ${total}/${ecritures.length}`);
  }
  if (total) process.stdout.write('\n');
  return total;
}

// ---------------------------------------------------------------- rapport

function afficherRapport(resultats) {
  console.log('\n================ RAPPORT DE REPRISE ================\n');
  for (const r of resultats) {
    const ecart = r.margeApres - r.margeAvant;
    console.log(`Boutique : ${r.boutique.nom}  (${r.boutique.id})`);
    console.log(`  ventes totales          : ${r.nbVentes}`);
    console.log(`  à reprendre             : ${r.nbTraitees}`);
    console.log(`  déjà figées (ignorées)  : ${r.nbDejaFigees}`);
    console.log(`  marge AVANT (prix jour) : ${money(r.margeAvant)} GNF`);
    console.log(`  marge APRÈS (reconstit.): ${money(r.margeApres)} GNF`);
    console.log(`  écart                   : ${money(ecart)} GNF`);
    if (r.replis.length) {
      console.log(`  produits en repli       : ${r.replis.length}`);
      for (const p of r.replis) {
        console.log(`    - ${p.nom} : ${p.motif}`);
      }
    } else {
      console.log('  produits en repli       : aucun');
    }
    console.log('');
  }
}

function ecrireCsv(resultats, chemin) {
  const lignes = [
    'boutique;boutique_id;ventes;a_reprendre;deja_figees;marge_avant;marge_apres;ecart;produits_en_repli',
  ];
  for (const r of resultats) {
    lignes.push(
      [
        r.boutique.nom,
        r.boutique.id,
        r.nbVentes,
        r.nbTraitees,
        r.nbDejaFigees,
        Math.round(r.margeAvant),
        Math.round(r.margeApres),
        Math.round(r.margeApres - r.margeAvant),
        r.replis.length,
      ].join(';'),
    );
  }
  lignes.push('');
  lignes.push('boutique;produit;motif_de_repli');
  for (const r of resultats) {
    for (const p of r.replis) {
      lignes.push([r.boutique.nom, p.nom, p.motif].join(';'));
    }
  }
  fs.writeFileSync(chemin, lignes.join('\n'), 'utf8');
  console.log(`Rapport CSV écrit : ${chemin}`);
}

// -------------------------------------------------------------------- main

(async () => {
  const boutiques = await lireBoutiques();
  console.log(
    `${boutiques.length} boutique(s) · mode : ${apply ? 'ÉCRITURE' : 'essai à blanc'}`,
  );

  const resultats = [];
  for (const b of boutiques) {
    process.stdout.write(`  traitement de ${b.nom}…\n`);
    resultats.push(await traiterBoutique(b));
  }

  afficherRapport(resultats);
  if (csvPath) ecrireCsv(resultats, csvPath);

  if (!apply) {
    const total = resultats.reduce((acc, r) => acc + r.ecritures.length, 0);
    console.log(
      `Essai à blanc : aucune écriture. ${total} vente(s) seraient mises à jour.`,
    );
    console.log('Relancer avec --apply après validation du rapport.');
    return;
  }

  console.log('\nÉcriture en base…');
  let total = 0;
  for (const r of resultats) {
    total += await ecrire(r.ecritures);
  }
  console.log(`Terminé : ${total} vente(s) mises à jour.`);
})().catch((e) => {
  console.error('\nÉchec :', e);
  process.exit(1);
});
