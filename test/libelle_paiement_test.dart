import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/data/models/paiement_caisse.dart';
import 'package:gongore_vente/app/data/models/reglement_fournisseur_model.dart';
import 'package:gongore_vente/app/data/models/reglement_model.dart';
import 'package:gongore_vente/app/data/models/vente_model.dart';

/// `libellePaiement` est le point de verite unique de l'affichage du canal
/// de paiement : six ecrans et deux recus en dependent (listes, fiches
/// client et fournisseur, recus PDF). D'ou ces tests malgre sa brievete.

ReglementModel _reglement({
  ModePaiement? mode,
  List<PaiementCaisse> paiements = const [],
}) {
  return ReglementModel(
    id: 'r1',
    clientId: 'c1',
    boutiqueId: 'b1',
    userId: 'u1',
    montant: 1000,
    modePaiement: mode,
    paiements: paiements,
    date: DateTime(2026, 10, 31),
  );
}

PaiementCaisse _p(String nom, double montant) =>
    PaiementCaisse(caisseId: nom, caisseNom: nom, montant: montant);

void main() {
  group('ReglementModel.libellePaiement', () {
    test('une caisse : son nom', () {
      final r = _reglement(paiements: [_p('Tiroir espèces', 1000)]);
      expect(r.libellePaiement, 'Tiroir espèces');
      expect(r.passeParCaisse, isTrue);
    });

    test('paiement mixte : les caisses sont jointes', () {
      final r = _reglement(
        paiements: [_p('Tiroir', 600), _p('Orange Money', 400)],
      );
      expect(r.libellePaiement, 'Tiroir + Orange Money');
    });

    test('pas de caisse : on retombe sur l ancien mode', () {
      final r = _reglement(mode: ModePaiement.orangeMoney);
      expect(r.libellePaiement, 'Orange Money');
      expect(r.passeParCaisse, isFalse);
    });

    test('ni caisse ni mode : tiret, jamais une valeur inventee', () {
      // Cas d un document ancien incomplet : il ne faut surtout pas
      // afficher « Espèces » par defaut, ce serait une information fausse.
      expect(_reglement().libellePaiement, '—');
    });

    test('la caisse prime sur le mode quand les deux existent', () {
      final r = _reglement(
        mode: ModePaiement.especes,
        paiements: [_p('Banque', 1000)],
      );
      expect(r.libellePaiement, 'Banque');
    });
  });

  group('ReglementFournisseurModel.libellePaiement', () {
    ReglementFournisseurModel build({
      ModePaiement? mode,
      List<PaiementCaisse> paiements = const [],
    }) {
      return ReglementFournisseurModel(
        id: 'rf1',
        fournisseurId: 'f1',
        boutiqueId: 'b1',
        userId: 'u1',
        montant: 1000,
        modePaiement: mode,
        paiements: paiements,
        date: DateTime(2026, 10, 31),
      );
    }

    test('meme regle que du cote client', () {
      expect(build(paiements: [_p('Banque', 1000)]).libellePaiement, 'Banque');
      expect(build(mode: ModePaiement.especes).libellePaiement, 'Espèces');
      expect(build().libellePaiement, '—');
    });
  });
}
