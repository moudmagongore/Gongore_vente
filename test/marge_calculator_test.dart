import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/core/utils/marge_calculator.dart';
import 'package:gongore_vente/app/data/models/vente_model.dart';

/// Les mêmes cas sont rejoués côté JavaScript dans
/// `scripts/test/marge_calculator.test.js`. Toute modification ici doit y
/// être reportée : les deux implémentations doivent rester d'accord.

VenteArticle _ligne({
  required String produitId,
  required int quantite,
  required double prixUnitaire,
  double remise = 0,
}) {
  return VenteArticle(
    produitId: produitId,
    nom: produitId,
    quantite: quantite,
    prixUnitaire: prixUnitaire,
    remise: remise,
  );
}

void main() {
  group('repartirRemiseGlobale', () {
    test('repartit au prorata du montant net (cas de la specification)', () {
      // Vente de 100 000 (60 000 + 40 000), remise globale de 10 000.
      final parts = repartirRemiseGlobale(
        articles: [
          _ligne(produitId: 'a', quantite: 1, prixUnitaire: 60000),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 40000),
        ],
        remiseGlobale: 10000,
      );
      expect(parts, [6000, 4000]);
    });

    test('la somme des parts est exacte quand la division ne tombe pas juste',
        () {
      // 3 lignes identiques, remise de 10 000 : 3 333,33… par ligne.
      final parts = repartirRemiseGlobale(
        articles: [
          _ligne(produitId: 'a', quantite: 1, prixUnitaire: 1000),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 1000),
          _ligne(produitId: 'c', quantite: 1, prixUnitaire: 1000),
        ],
        remiseGlobale: 10000,
      );
      // Le reliquat tombe sur la derniere ligne : la somme reste exacte.
      expect(parts.reduce((a, b) => a + b), 10000);
    });

    test('tient compte de la remise de ligne dans le prorata', () {
      // Ligne A : 60 000 - 20 000 = 40 000 net. Ligne B : 40 000 net.
      // Les deux pesent donc pareil malgre des prix differents.
      final parts = repartirRemiseGlobale(
        articles: [
          _ligne(
              produitId: 'a',
              quantite: 1,
              prixUnitaire: 60000,
              remise: 20000),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 40000),
        ],
        remiseGlobale: 10000,
      );
      expect(parts, [5000, 5000]);
    });

    test('remise nulle : que des zeros', () {
      final parts = repartirRemiseGlobale(
        articles: [
          _ligne(produitId: 'a', quantite: 1, prixUnitaire: 1000),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 2000),
        ],
        remiseGlobale: 0,
      );
      expect(parts, [0, 0]);
    });

    test('base nulle : la remise va sur la derniere ligne sans etre perdue',
        () {
      final parts = repartirRemiseGlobale(
        articles: [
          _ligne(produitId: 'a', quantite: 1, prixUnitaire: 0),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 0),
        ],
        remiseGlobale: 5000,
      );
      expect(parts.reduce((a, b) => a + b), 5000);
    });

    test('liste vide', () {
      expect(repartirRemiseGlobale(articles: [], remiseGlobale: 1000),
          isEmpty);
    });
  });

  group('calculerMarges', () {
    test('cas nominal sans remise globale', () {
      // 10 unites vendues 1 500, achetees 1 000 → marge 5 000.
      final r = calculerMarges(
        articles: [
          _ligne(produitId: 'p1', quantite: 10, prixUnitaire: 1500),
        ],
        remiseGlobale: 0,
        prixAchatParProduit: {'p1': 1000},
      );
      expect(r.coutAchatTotal, 10000);
      expect(r.margeTotale, 5000);
      expect(r.articles.single.prixAchatUnitaire, 1000);
      expect(r.articles.single.remiseGlobaleAllouee, 0);
      expect(r.articles.single.marge, 5000);
    });

    test('la remise globale est deduite de la marge', () {
      final r = calculerMarges(
        articles: [
          _ligne(produitId: 'a', quantite: 1, prixUnitaire: 60000),
          _ligne(produitId: 'b', quantite: 1, prixUnitaire: 40000),
        ],
        remiseGlobale: 10000,
        prixAchatParProduit: {'a': 50000, 'b': 30000},
      );
      // a : 60 000 - 6 000 - 50 000 = 4 000
      // b : 40 000 - 4 000 - 30 000 = 6 000
      expect(r.articles[0].marge, 4000);
      expect(r.articles[1].marge, 6000);
      expect(r.margeTotale, 10000);
      expect(r.coutAchatTotal, 80000);
    });

    test('la marge totale egale le total net moins le cout d achat', () {
      final articles = [
        _ligne(produitId: 'a', quantite: 3, prixUnitaire: 1700, remise: 200),
        _ligne(produitId: 'b', quantite: 7, prixUnitaire: 900),
      ];
      const remiseGlobale = 1234.0;
      final r = calculerMarges(
        articles: articles,
        remiseGlobale: remiseGlobale,
        prixAchatParProduit: {'a': 1200, 'b': 650},
      );
      final totalNet =
          articles.fold<double>(0, (acc, a) => acc + a.sousTotal) -
              remiseGlobale;
      expect(r.margeTotale, closeTo(totalNet - r.coutAchatTotal, 0.000001));
    });

    test('vente a perte : marge negative conservee telle quelle', () {
      final r = calculerMarges(
        articles: [
          _ligne(produitId: 'p1', quantite: 2, prixUnitaire: 800),
        ],
        remiseGlobale: 0,
        prixAchatParProduit: {'p1': 1000},
      );
      expect(r.margeTotale, -400);
      expect(r.articles.single.marge, -400);
    });

    test('produit absent : cout nul, la ligne compte quand meme', () {
      // Produit supprime entre la mise au panier et la validation.
      // L ancienne formule ignorait la ligne ; ici elle est comptee.
      final r = calculerMarges(
        articles: [
          _ligne(produitId: 'disparu', quantite: 1, prixUnitaire: 5000),
        ],
        remiseGlobale: 0,
        prixAchatParProduit: const {},
      );
      expect(r.articles.single.prixAchatUnitaire, 0);
      expect(r.margeTotale, 5000);
      expect(r.coutAchatTotal, 0);
    });

    test('les decimales du CMUP sont conservees', () {
      // Le CMUP tombe rarement juste : aucun arrondi ne doit etre applique.
      final r = calculerMarges(
        articles: [
          _ligne(produitId: 'p1', quantite: 3, prixUnitaire: 1000),
        ],
        remiseGlobale: 0,
        prixAchatParProduit: {'p1': 333.3333333333333},
      );
      expect(r.coutAchatTotal, closeTo(999.9999999999999, 0.000001));
      expect(r.articles.single.prixAchatUnitaire, 333.3333333333333);
    });

    test('vente vide', () {
      final r = calculerMarges(
        articles: [],
        remiseGlobale: 0,
        prixAchatParProduit: const {},
      );
      expect(r.articles, isEmpty);
      expect(r.margeTotale, 0);
      expect(r.coutAchatTotal, 0);
    });
  });
}
