#!/usr/bin/env node
/**
 * Purge les données Firestore d'UNE boutique, sans toucher aux autres.
 *
 * Firestore n'a pas de « DELETE ... WHERE » : il faut lire les documents
 * correspondants puis les supprimer par lots. C'est ce que fait ce script.
 *
 * ⚠️  Suppression DÉFINITIVE et sans corbeille. Le mode par défaut est un
 *     essai à blanc (dry-run) qui ne supprime rien : il compte et affiche.
 *     Il faut passer --confirm pour écrire réellement.
 *
 * Usage :
 *   node purge_boutique.js --boutique=<ID>                  # essai à blanc
 *   node purge_boutique.js --boutique=<ID> --confirm        # suppression
 *   node purge_boutique.js --boutique=<ID> --only=produits  # une collection
 *   node purge_boutique.js --boutique=<ID> --include-users --include-abonnements
 *
 * Authentification (au choix) :
 *   export GOOGLE_APPLICATION_CREDENTIALS=/chemin/serviceAccountKey.json
 *   ou   gcloud auth application-default login
 */

const admin = require('firebase-admin');

// --------------------------------------------------------------- arguments
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const value = (name) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : null;
};

const boutiqueId = value('boutique');
const confirm = flag('confirm');
const only = value('only');
const includeUsers = flag('include-users');
const includeAbonnements = flag('include-abonnements');
const deleteBoutique = flag('delete-boutique');

if (!boutiqueId) {
  console.error('Erreur : --boutique=<ID> est obligatoire.');
  console.error('Astuce : l\'ID se lit dans Firestore, collection `boutiques`.');
  process.exit(1);
}

// ------------------------------------------------------------- collections
// Toutes portent un champ `boutiqueId`, donc filtrables directement.
const METIER = [
  'ventes',
  'reglements',
  'approvisionnements',
  'reglementsFournisseurs',
  'mouvementsStock',
  'depenses',
];

// Référentiels : à vider seulement si on veut repartir d'un catalogue vierge.
const CATALOGUE = [
  'produits', // + sous-collection `variantes`, traitée à part
  'categories',
  'clients',
  'fournisseurs',
  'naturesDepense',
];

// Sensible : jamais inclus sans demande explicite.
const SENSIBLE = [];
if (includeUsers) SENSIBLE.push('users');
if (includeAbonnements) SENSIBLE.push('abonnements');

let collections = [...METIER, ...CATALOGUE, ...SENSIBLE];
if (only) {
  const demandees = only.split(',').map((c) => c.trim()).filter(Boolean);
  const inconnues = demandees.filter(
    (c) => ![...METIER, ...CATALOGUE, 'users', 'abonnements'].includes(c),
  );
  if (inconnues.length) {
    console.error(`Collection(s) inconnue(s) : ${inconnues.join(', ')}`);
    process.exit(1);
  }
  collections = demandees;
}

// ------------------------------------------------------------------- setup
admin.initializeApp();
const db = admin.firestore();

const BATCH = 400; // marge sous la limite Firestore de 500 écritures

/** Supprime par lots tous les docs d'une query, en repaginant à chaque tour. */
async function purgeQuery(query, label) {
  let total = 0;
  for (;;) {
    const snap = await query.limit(BATCH).get();
    if (snap.empty) break;
    total += snap.size;
    if (!confirm) {
      // Essai à blanc : on ne peut pas repaginer sans supprimer, donc on
      // compte la totalité en une passe séparée puis on sort.
      const all = await query.count().get();
      return all.data().count;
    }
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    process.stdout.write(`  ${label} : ${total} supprimé(s)\r`);
  }
  return total;
}

/**
 * Les sous-collections ne partent PAS avec leur document parent : supprimer
 * un produit laisse ses `variantes` orphelines et invisibles. On les purge
 * donc explicitement, avant les produits eux-mêmes.
 */
async function purgeVariantes() {
  const produits = await db
    .collection('produits')
    .where('boutiqueId', '==', boutiqueId)
    .select()
    .get();
  let total = 0;
  for (const p of produits.docs) {
    const sous = p.ref.collection('variantes');
    const n = await purgeQuery(sous, `variantes/${p.id}`);
    total += n;
  }
  return total;
}

async function main() {
  const boutique = await db.collection('boutiques').doc(boutiqueId).get();
  if (!boutique.exists) {
    console.error(`Boutique "${boutiqueId}" introuvable. Rien n'a été touché.`);
    process.exit(1);
  }

  console.log('');
  console.log(`Boutique : ${boutique.data().nom}  (${boutiqueId})`);
  console.log(`Mode     : ${confirm ? '*** SUPPRESSION REELLE ***' : 'essai a blanc (aucune ecriture)'}`);
  console.log(`Cibles   : ${collections.join(', ')}`);
  console.log('');

  const resume = {};

  // Variantes d'abord, tant que les produits existent encore pour les lister.
  if (collections.includes('produits')) {
    resume['produits/variantes'] = await purgeVariantes();
  }

  for (const col of collections) {
    const q = db.collection(col).where('boutiqueId', '==', boutiqueId);
    resume[col] = await purgeQuery(q, col);
  }

  // `counters` est adressé par doc-id (= boutiqueId), pas par champ : il
  // porte les numéros séquentiels de ventes / appros de la boutique.
  if (!only) {
    const counter = db.collection('counters').doc(boutiqueId);
    const snap = await counter.get();
    resume['counters'] = snap.exists ? 1 : 0;
    if (confirm && snap.exists) await counter.delete();
  }

  if (deleteBoutique) {
    resume['boutiques (fiche)'] = 1;
    if (confirm) await db.collection('boutiques').doc(boutiqueId).delete();
  }

  console.log('\nRésumé :');
  let totalGlobal = 0;
  for (const [k, v] of Object.entries(resume)) {
    console.log(`  ${k.padEnd(24)} ${v}`);
    totalGlobal += v;
  }
  console.log(`  ${'TOTAL'.padEnd(24)} ${totalGlobal}`);

  if (!confirm) {
    console.log('\nRien n\'a été supprimé. Relancez avec --confirm pour exécuter.');
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('\nEchec :', e.message);
  process.exit(1);
});
