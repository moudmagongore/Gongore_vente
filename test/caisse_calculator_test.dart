import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/core/utils/caisse_calculator.dart';
import 'package:gongore_vente/app/data/models/caisse_model.dart';
import 'package:gongore_vente/app/data/models/mouvement_caisse_model.dart';
import 'package:gongore_vente/app/data/models/paiement_caisse.dart';

CaisseModel _caisse(
  String id, {
  double solde = 0,
  bool autoriseNegatif = false,
  bool active = true,
}) {
  return CaisseModel(
    id: id,
    nom: id,
    boutiqueId: 'b1',
    solde: solde,
    active: active,
    autoriseNegatif: autoriseNegatif,
  );
}

PaiementCaisse _ligne(String caisseId, double montant) =>
    PaiementCaisse(caisseId: caisseId, caisseNom: caisseId, montant: montant);

void main() {
  group('regrouperParCaisse', () {
    test('somme les lignes d une meme caisse', () {
      final parCaisse = regrouperParCaisse([
        _ligne('especes', 100000),
        _ligne('om', 50000),
        _ligne('especes', 25000),
      ]);
      expect(parCaisse, {'especes': 125000.0, 'om': 50000.0});
    });

    test('conserve l ordre de saisie', () {
      final parCaisse = regrouperParCaisse([
        _ligne('om', 1),
        _ligne('especes', 1),
      ]);
      expect(parCaisse.keys.toList(), ['om', 'especes']);
    });

    test('liste vide', () {
      expect(regrouperParCaisse([]), isEmpty);
    });
  });

  group('planifierTransfert', () {
    test('cas nominal : la source baisse, la destination monte', () {
      final plan = planifierTransfert(
        source: _caisse('tiroir', solde: 1500000),
        destination: _caisse('banque', solde: 200000),
        montant: 1000000,
      );
      expect(plan.sortie.soldeApres, 500000);
      expect(plan.entree.soldeApres, 1200000);
      expect(plan.sortie.montant, plan.entree.montant);
    });

    test('meme caisse en depart et arrivee : refuse', () {
      expect(
        () => planifierTransfert(
          source: _caisse('tiroir', solde: 1000),
          destination: _caisse('tiroir', solde: 1000),
          montant: 100,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('source insuffisante : refuse', () {
      expect(
        () => planifierTransfert(
          source: _caisse('tiroir', solde: 500),
          destination: _caisse('banque', solde: 0),
          montant: 1000,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('source autorisee au negatif : accepte', () {
      final plan = planifierTransfert(
        source: _caisse('tiroir', solde: 500, autoriseNegatif: true),
        destination: _caisse('banque', solde: 0),
        montant: 1000,
      );
      expect(plan.sortie.soldeApres, -500);
    });

    test('la destination peut etre non autorisee au negatif : elle monte', () {
      final plan = planifierTransfert(
        source: _caisse('tiroir', solde: 1000),
        destination: _caisse('banque', solde: 0),
        montant: 1000,
      );
      expect(plan.sortie.soldeApres, 0);
      expect(plan.entree.soldeApres, 1000);
    });

    test('montant nul : refuse', () {
      expect(
        () => planifierTransfert(
          source: _caisse('a', solde: 1000),
          destination: _caisse('b'),
          montant: 0,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('transferer tout le solde disponible passe', () {
      final plan = planifierTransfert(
        source: _caisse('a', solde: 0.1 + 0.2),
        destination: _caisse('b'),
        montant: 0.3,
      );
      expect(plan.sortie.soldeApres.abs(), lessThan(0.000001));
    });
  });

  group('verifierRepartition', () {
    test('repartition exacte : aucun probleme', () {
      expect(
        verifierRepartition(
          paiements: [_ligne('especes', 200000), _ligne('om', 150000)],
          attendu: 350000,
        ),
        isNull,
      );
    });

    test('repartition incomplete : annonce le reste', () {
      final msg = verifierRepartition(
        paiements: [_ligne('especes', 200000)],
        attendu: 350000,
      );
      expect(msg, isNotNull);
      expect(msg, contains('150'));
    });

    test('depassement : annonce l ecart', () {
      final msg = verifierRepartition(
        paiements: [_ligne('especes', 400000)],
        attendu: 350000,
      );
      expect(msg, isNotNull);
      expect(msg, contains('50'));
    });

    test('liste vide acceptee : boutique sans caisse (RG-9)', () {
      expect(verifierRepartition(paiements: const [], attendu: 350000),
          isNull);
    });

    test('tolerance a l erreur flottante', () {
      expect(
        verifierRepartition(
          paiements: [_ligne('a', 0.1), _ligne('b', 0.2)],
          attendu: 0.3,
        ),
        isNull,
      );
    });
  });

  group('totalPaiements', () {
    test('somme toutes les lignes, meme caisse comprise', () {
      expect(
        totalPaiements([
          _ligne('especes', 1000),
          _ligne('especes', 500),
          _ligne('om', 250),
        ]),
        1750,
      );
    });

    test('liste vide : zero', () {
      expect(totalPaiements([]), 0);
    });
  });

  group('planifierPaiements', () {
    test('aucun paiement : plan vide, rien a ecrire (RG-9)', () {
      final plan = planifierPaiements(
        paiements: const [],
        caisses: const {},
        sens: SensMouvement.entree,
      );
      expect(plan.estVide, isTrue);
      expect(plan.total, 0);
    });

    test('paiement mixte : un mouvement par caisse, soldes calcules', () {
      // Vente de 350 000 : 200 000 en especes, 150 000 par Orange Money.
      final plan = planifierPaiements(
        paiements: [_ligne('especes', 200000), _ligne('om', 150000)],
        caisses: {
          'especes': _caisse('especes', solde: 500000),
          'om': _caisse('om', solde: 1000000),
        },
        sens: SensMouvement.entree,
      );
      expect(plan.mouvements.length, 2);
      expect(plan.total, 350000);
      expect(plan.mouvements[0].soldeApres, 700000);
      expect(plan.mouvements[1].soldeApres, 1150000);
    });

    test('deux lignes sur la meme caisse ne font qu un mouvement (RG-10)', () {
      final plan = planifierPaiements(
        paiements: [_ligne('especes', 60000), _ligne('especes', 40000)],
        caisses: {'especes': _caisse('especes', solde: 0)},
        sens: SensMouvement.entree,
      );
      expect(plan.mouvements.length, 1);
      expect(plan.mouvements.first.montant, 100000);
      expect(plan.mouvements.first.soldeApres, 100000);
    });

    test('une sortie diminue le solde', () {
      final plan = planifierPaiements(
        paiements: [_ligne('especes', 30000)],
        caisses: {'especes': _caisse('especes', solde: 100000)},
        sens: SensMouvement.sortie,
      );
      expect(plan.mouvements.first.montant, 30000);
      expect(plan.mouvements.first.soldeApres, 70000);
    });

    test('solde insuffisant : refuse, message nommant la caisse (RG-3)', () {
      expect(
        () => planifierPaiements(
          paiements: [_ligne('Tiroir', 200000)],
          caisses: {'Tiroir': _caisse('Tiroir', solde: 150000)},
          sens: SensMouvement.sortie,
        ),
        throwsA(
          isA<CaisseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Tiroir'), contains('150'), contains('GNF')),
          ),
        ),
      );
    });

    test('solde insuffisant accepte si la caisse autorise le negatif', () {
      final plan = planifierPaiements(
        paiements: [_ligne('especes', 200000)],
        caisses: {
          'especes':
              _caisse('especes', solde: 150000, autoriseNegatif: true),
        },
        sens: SensMouvement.sortie,
      );
      expect(plan.mouvements.first.soldeApres, -50000);
    });

    test('regler exactement le solde disponible passe', () {
      // Le controle est tolerant a l erreur flottante : 0.1 + 0.2 - 0.3
      // ne vaut pas exactement zero en double.
      final plan = planifierPaiements(
        paiements: [_ligne('especes', 0.3)],
        caisses: {'especes': _caisse('especes', solde: 0.1 + 0.2)},
        sens: SensMouvement.sortie,
      );
      expect(plan.mouvements.first.soldeApres.abs(), lessThan(0.000001));
    });

    test('caisse introuvable : refuse', () {
      expect(
        () => planifierPaiements(
          paiements: [_ligne('disparue', 1000)],
          caisses: const {},
          sens: SensMouvement.entree,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('caisse desactivee : refusee pour une operation', () {
      expect(
        () => planifierPaiements(
          paiements: [_ligne('ancienne', 1000)],
          caisses: {
            'ancienne': _caisse('ancienne', solde: 5000, active: false),
          },
          sens: SensMouvement.entree,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('caisse desactivee : acceptee pour une annulation', () {
      // Sinon une operation payee sur une caisse desactivee depuis
      // deviendrait impossible a annuler.
      final plan = planifierPaiements(
        paiements: [_ligne('ancienne', 1000)],
        caisses: {
          'ancienne': _caisse('ancienne', solde: 5000, active: false),
        },
        sens: SensMouvement.sortie,
        exigerActive: false,
      );
      expect(plan.mouvements.first.soldeApres, 4000);
    });

    test('montant nul ou negatif : refuse', () {
      expect(
        () => planifierPaiements(
          paiements: [_ligne('especes', 0)],
          caisses: {'especes': _caisse('especes', solde: 1000)},
          sens: SensMouvement.entree,
        ),
        throwsA(isA<CaisseException>()),
      );
    });

    test('annulation : le plan inverse ramene le solde a sa valeur', () {
      const soldeInitial = 500000.0;
      final paiements = [_ligne('especes', 120000)];

      final vente = planifierPaiements(
        paiements: paiements,
        caisses: {'especes': _caisse('especes', solde: soldeInitial)},
        sens: SensMouvement.entree,
      );
      final apresVente = vente.mouvements.first.soldeApres;

      final annulation = planifierPaiements(
        paiements: paiements,
        caisses: {'especes': _caisse('especes', solde: apresVente)},
        sens: SensMouvement.sortie,
        exigerActive: false,
      );
      expect(annulation.mouvements.first.soldeApres, soldeInitial);
    });

    test('annulation refusee si elle viderait une caisse non autorisee', () {
      // L argent encaisse a ete depense depuis : annuler ferait passer la
      // caisse en negatif (RG-16).
      expect(
        () => planifierPaiements(
          paiements: [_ligne('especes', 120000)],
          caisses: {'especes': _caisse('especes', solde: 30000)},
          sens: SensMouvement.sortie,
          exigerActive: false,
        ),
        throwsA(isA<CaisseException>()),
      );
    });
  });
}
