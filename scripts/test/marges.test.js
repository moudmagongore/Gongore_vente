'use strict';

/**
 * Lancé par `node --test` (aucune dépendance à installer).
 *
 * Les cas de `calculerMarges` et `repartirRemiseGlobale` sont les mêmes que
 * dans `test/marge_calculator_test.dart` : les deux implémentations doivent
 * rester d'accord, sinon une vente reprise par ce script et une vente
 * récente enregistrée par l'app ne seraient pas comparables.
 */

const test = require('node:test');
const assert = require('node:assert');
const {
  repartirRemiseGlobale,
  calculerMarges,
  rejouerCmup,
} = require('../lib/marges');

const ligne = (produitId, quantite, prixUnitaire, remise = 0) => ({
  produitId,
  nom: produitId,
  quantite,
  prixUnitaire,
  remise,
});

// ---------------------------------------------------------- remise globale

test('repartit au prorata du montant net (cas de la specification)', () => {
  const parts = repartirRemiseGlobale(
    [ligne('a', 1, 60000), ligne('b', 1, 40000)],
    10000,
  );
  assert.deepStrictEqual(parts, [6000, 4000]);
});

test('la somme des parts est exacte quand la division ne tombe pas juste', () => {
  const parts = repartirRemiseGlobale(
    [ligne('a', 1, 1000), ligne('b', 1, 1000), ligne('c', 1, 1000)],
    10000,
  );
  assert.strictEqual(parts.reduce((a, b) => a + b, 0), 10000);
});

test('tient compte de la remise de ligne dans le prorata', () => {
  const parts = repartirRemiseGlobale(
    [ligne('a', 1, 60000, 20000), ligne('b', 1, 40000)],
    10000,
  );
  assert.deepStrictEqual(parts, [5000, 5000]);
});

test('remise nulle : que des zeros', () => {
  assert.deepStrictEqual(
    repartirRemiseGlobale([ligne('a', 1, 1000), ligne('b', 1, 2000)], 0),
    [0, 0],
  );
});

test('base nulle : la remise va sur la derniere ligne sans etre perdue', () => {
  const parts = repartirRemiseGlobale(
    [ligne('a', 1, 0), ligne('b', 1, 0)],
    5000,
  );
  assert.strictEqual(parts.reduce((a, b) => a + b, 0), 5000);
});

test('liste vide', () => {
  assert.deepStrictEqual(repartirRemiseGlobale([], 1000), []);
});

// ----------------------------------------------------------------- marges

test('cas nominal sans remise globale', () => {
  const r = calculerMarges([ligne('p1', 10, 1500)], 0, { p1: 1000 });
  assert.strictEqual(r.coutAchatTotal, 10000);
  assert.strictEqual(r.margeTotale, 5000);
  assert.strictEqual(r.articles[0].prixAchatUnitaire, 1000);
  assert.strictEqual(r.articles[0].remiseGlobaleAllouee, 0);
});

test('la remise globale est deduite de la marge', () => {
  const r = calculerMarges(
    [ligne('a', 1, 60000), ligne('b', 1, 40000)],
    10000,
    { a: 50000, b: 30000 },
  );
  assert.strictEqual(r.articles[0].marge, 4000);
  assert.strictEqual(r.articles[1].marge, 6000);
  assert.strictEqual(r.margeTotale, 10000);
  assert.strictEqual(r.coutAchatTotal, 80000);
});

test('vente a perte : marge negative conservee telle quelle', () => {
  const r = calculerMarges([ligne('p1', 2, 800)], 0, { p1: 1000 });
  assert.strictEqual(r.margeTotale, -400);
});

test('produit absent : cout nul, la ligne compte quand meme', () => {
  const r = calculerMarges([ligne('disparu', 1, 5000)], 0, {});
  assert.strictEqual(r.articles[0].prixAchatUnitaire, 0);
  assert.strictEqual(r.margeTotale, 5000);
});

test('les decimales du CMUP sont conservees', () => {
  const r = calculerMarges([ligne('p1', 3, 1000)], 0, {
    p1: 333.3333333333333,
  });
  assert.ok(Math.abs(r.coutAchatTotal - 999.9999999999999) < 1e-6);
});

test('vente vide', () => {
  const r = calculerMarges([], 0, {});
  assert.deepStrictEqual(r.articles, []);
  assert.strictEqual(r.margeTotale, 0);
});

// ------------------------------------------------------------ rejeu CMUP

test('cas nominal : le CMUP suit la formule pondérée', () => {
  // 10 à 1 000, puis 10 à 2 000 → CMUP 1 500 pour la vente suivante.
  const { cmupParVente, repli } = rejouerCmup([
    { type: 'appro', quantite: 10, prixAchatUnitaire: 1000 },
    { type: 'vente', venteId: 'v1', quantite: 2 },
    { type: 'appro', quantite: 10, prixAchatUnitaire: 2000 },
    { type: 'vente', venteId: 'v2', quantite: 1 },
  ]);
  assert.strictEqual(repli, null);
  assert.strictEqual(cmupParVente.get('v1'), 1000);
  // Stock au 2e appro : 10 - 2 = 8 → (8×1000 + 10×2000) / 18
  assert.ok(Math.abs(cmupParVente.get('v2') - 28000 / 18) < 1e-9);
});

test('un mouvement de stock manuel change le CMUP des appros suivants', () => {
  // Sans le mouvement, le 2e appro pondererait sur 10 unites au lieu de 4.
  const sansMouvement = rejouerCmup([
    { type: 'appro', quantite: 10, prixAchatUnitaire: 1000 },
    { type: 'appro', quantite: 10, prixAchatUnitaire: 2000 },
    { type: 'vente', venteId: 'v1', quantite: 1 },
  ]).cmupParVente.get('v1');

  const avecMouvement = rejouerCmup([
    { type: 'appro', quantite: 10, prixAchatUnitaire: 1000 },
    { type: 'mouvement', delta: -6 }, // perte / casse
    { type: 'appro', quantite: 10, prixAchatUnitaire: 2000 },
    { type: 'vente', venteId: 'v1', quantite: 1 },
  ]).cmupParVente.get('v1');

  assert.notStrictEqual(sansMouvement, avecMouvement);
  // (4×1000 + 10×2000) / 14
  assert.ok(Math.abs(avecMouvement - 24000 / 14) < 1e-9);
});

test('un appro annule garde son effet sur le prix d achat', () => {
  // L annulation d un appro ne recalcule pas le PA (cf. code applicatif) :
  // son effet persiste, seul le stock est repris.
  const { cmupParVente } = rejouerCmup([
    { type: 'appro', quantite: 10, prixAchatUnitaire: 1000 },
    { type: 'appro', quantite: 10, prixAchatUnitaire: 3000 },
    { type: 'approAnnule', quantite: 10 },
    { type: 'vente', venteId: 'v1', quantite: 1 },
  ]);
  // Le CMUP reste celui calcule avec l appro annule : 2 000.
  assert.strictEqual(cmupParVente.get('v1'), 2000);
});

test('repli : vente anterieure a tout approvisionnement', () => {
  const { repli } = rejouerCmup([
    { type: 'vente', venteId: 'v1', quantite: 1 },
  ]);
  assert.strictEqual(repli, 'vente anterieure a tout approvisionnement');
});

test('repli : stock reconstitue negatif', () => {
  const { repli } = rejouerCmup([
    { type: 'appro', quantite: 2, prixAchatUnitaire: 1000 },
    { type: 'vente', venteId: 'v1', quantite: 5 },
  ]);
  assert.strictEqual(repli, 'stock reconstitue negatif');
});

test('une vente annulee recoit son CMUP sans bouger le stock', () => {
  const { cmupParVente, repli } = rejouerCmup([
    { type: 'appro', quantite: 5, prixAchatUnitaire: 1000 },
    { type: 'vente', venteId: 'v1', quantite: 5, annulee: true },
    { type: 'appro', quantite: 5, prixAchatUnitaire: 2000 },
    { type: 'vente', venteId: 'v2', quantite: 1 },
  ]);
  assert.strictEqual(repli, null);
  assert.strictEqual(cmupParVente.get('v1'), 1000);
  // Le stock est reste a 5 : (5×1000 + 5×2000) / 10 = 1 500.
  assert.strictEqual(cmupParVente.get('v2'), 1500);
});
