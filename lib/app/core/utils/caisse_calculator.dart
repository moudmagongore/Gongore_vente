// Planification des mouvements de caisse d'une opération.
//
// Isolé ici — sans Firestore ni GetX — parce que c'est la seule partie
// réellement délicate du module : regroupement des lignes, contrôle du
// solde négatif, calcul du solde après chaque mouvement. Tout le reste
// n'est que lecture et écriture.
//
// `CaisseRepository` lit les caisses dans la transaction, appelle cette
// fonction, puis écrit le plan obtenu. Aucun autre code ne modifie un
// solde.

import '../../data/models/caisse_model.dart';
import '../../data/models/mouvement_caisse_model.dart';
import '../../data/models/paiement_caisse.dart';
import 'format_helpers.dart';

/// Opération de caisse refusée. Le [message] est prêt à afficher.
class CaisseException implements Exception {
  final String message;
  CaisseException(this.message);
  @override
  String toString() => message;
}

/// Un mouvement calculé mais pas encore écrit.
class MouvementPlanifie {
  final String caisseId;
  final String caisseNom;

  /// Toujours positif : le sens est porté par le plan.
  final double montant;

  final double soldeAvant;
  final double soldeApres;

  const MouvementPlanifie({
    required this.caisseId,
    required this.caisseNom,
    required this.montant,
    required this.soldeAvant,
    required this.soldeApres,
  });
}

/// Ensemble des mouvements à écrire pour une opération.
class PlanPaiements {
  final List<MouvementPlanifie> mouvements;
  final SensMouvement sens;

  const PlanPaiements({required this.mouvements, required this.sens});

  /// Vrai quand il n'y a rien à écrire : opération sans paiement, ou
  /// boutique qui n'a pas encore de caisse (RG-9).
  bool get estVide => mouvements.isEmpty;

  double get total =>
      mouvements.fold<double>(0, (acc, m) => acc + m.montant);
}

/// Tolérance sur la comparaison à zéro du solde.
///
/// Sans elle, régler exactement le solde disponible pourrait être refusé :
/// la soustraction de deux doubles égaux peut rendre -1e-13, donc « < 0 ».
const _epsilon = 0.000001;

/// Somme des lignes de paiement saisies.
double totalPaiements(List<PaiementCaisse> paiements) =>
    paiements.fold<double>(0, (acc, p) => acc + p.montant);

/// Vérifie que la répartition sur les caisses couvre exactement [attendu].
///
/// Sert aux opérations dont le montant est connu d'avance : une dépense
/// (RG-15), un règlement. Une vente, elle, autorise une somme inférieure
/// au total — la différence partant en crédit client.
///
/// Renvoie `null` si la répartition est bonne, sinon le message à afficher.
/// Une liste vide est acceptée : c'est le cas d'une boutique sans caisse,
/// géré en amont par l'appelant.
String? verifierRepartition({
  required List<PaiementCaisse> paiements,
  required double attendu,
}) {
  if (paiements.isEmpty) return null;
  final total = totalPaiements(paiements);
  final ecart = total - attendu;
  if (ecart.abs() < _epsilon) return null;
  if (ecart > 0) {
    return 'La répartition dépasse le montant de '
        '${Fmt.money(ecart, currency: 'GNF')}.';
  }
  return 'Il reste ${Fmt.money(-ecart, currency: 'GNF')} à répartir '
      'sur les caisses.';
}

/// Regroupe les lignes de paiement par caisse, en sommant les montants.
///
/// Une même caisse ne doit figurer qu'une fois par opération (RG-10) ;
/// l'interface l'empêche, mais on somme plutôt que de refuser — deux
/// lignes sur la même caisse ont un sens arithmétique évident, et une
/// exception ici ne servirait qu'à perdre la saisie de l'utilisateur.
///
/// L'ordre des caisses rencontrées est conservé.
Map<String, double> regrouperParCaisse(List<PaiementCaisse> paiements) {
  final parCaisse = <String, double>{};
  for (final p in paiements) {
    parCaisse[p.caisseId] = (parCaisse[p.caisseId] ?? 0) + p.montant;
  }
  return parCaisse;
}

/// Calcule les mouvements à écrire pour une liste de paiements.
///
/// [caisses] doit contenir les caisses citées par [paiements], **lues dans
/// la transaction** : c'est leur solde qui sert de base de calcul, pas
/// celui affiché à l'écran.
///
/// [exigerActive] est mis à `false` pour une annulation : une caisse
/// désactivée entre-temps doit pouvoir être recréditée, sinon l'opération
/// deviendrait impossible à annuler.
///
/// Lève [CaisseException] si une caisse manque, est désactivée, ou passerait
/// en négatif sans y être autorisée. Renvoie un plan vide quand il n'y a
/// aucun paiement.
PlanPaiements planifierPaiements({
  required List<PaiementCaisse> paiements,
  required Map<String, CaisseModel> caisses,
  required SensMouvement sens,
  bool exigerActive = true,
}) {
  if (paiements.isEmpty) {
    return PlanPaiements(mouvements: const [], sens: sens);
  }

  final mouvements = <MouvementPlanifie>[];
  regrouperParCaisse(paiements).forEach((caisseId, montant) {
    final caisse = caisses[caisseId];
    if (caisse == null) {
      throw CaisseException(
        'Caisse introuvable : elle a peut-être été supprimée. '
        'Reprenez la saisie.',
      );
    }
    if (montant <= 0) {
      throw CaisseException(
        'Le montant affecté à « ${caisse.nom} » doit être supérieur à 0.',
      );
    }
    if (exigerActive && !caisse.active) {
      throw CaisseException(
        'La caisse « ${caisse.nom} » a été désactivée. '
        'Choisissez-en une autre.',
      );
    }

    final soldeApres = caisse.solde + sens.signe * montant;
    if (soldeApres < -_epsilon && !caisse.autoriseNegatif) {
      throw CaisseException(
        'Solde insuffisant sur ${caisse.nom} '
        '(disponible : ${Fmt.money(caisse.solde, currency: 'GNF')}).',
      );
    }

    mouvements.add(MouvementPlanifie(
      caisseId: caisseId,
      caisseNom: caisse.nom,
      montant: montant,
      soldeAvant: caisse.solde,
      soldeApres: soldeApres,
    ));
  });

  return PlanPaiements(mouvements: mouvements, sens: sens);
}

/// Plan d'un transfert entre deux caisses : une sortie et une entrée,
/// toujours écrites ensemble (RG-22).
class PlanTransfert {
  final MouvementPlanifie sortie;
  final MouvementPlanifie entree;
  const PlanTransfert({required this.sortie, required this.entree});
}

/// Calcule les deux mouvements d'un transfert.
///
/// La règle du solde négatif ne s'applique qu'à la caisse **source** : la
/// destination ne peut que monter.
///
/// Lève [CaisseException] si les deux caisses sont la même, si le montant
/// est nul ou négatif, ou si la source passerait sous zéro sans y être
/// autorisée.
PlanTransfert planifierTransfert({
  required CaisseModel source,
  required CaisseModel destination,
  required double montant,
}) {
  if (source.id == destination.id) {
    throw CaisseException(
      'La caisse de départ et la caisse d\'arrivée doivent être '
      'différentes.',
    );
  }
  if (montant <= 0) {
    throw CaisseException('Le montant doit être supérieur à 0.');
  }

  final soldeSource = source.solde - montant;
  if (soldeSource < -_epsilon && !source.autoriseNegatif) {
    throw CaisseException(
      'Solde insuffisant sur ${source.nom} '
      '(disponible : ${Fmt.money(source.solde, currency: 'GNF')}).',
    );
  }

  return PlanTransfert(
    sortie: MouvementPlanifie(
      caisseId: source.id,
      caisseNom: source.nom,
      montant: montant,
      soldeAvant: source.solde,
      soldeApres: soldeSource,
    ),
    entree: MouvementPlanifie(
      caisseId: destination.id,
      caisseNom: destination.nom,
      montant: montant,
      soldeAvant: destination.solde,
      soldeApres: destination.solde + montant,
    ),
  );
}
