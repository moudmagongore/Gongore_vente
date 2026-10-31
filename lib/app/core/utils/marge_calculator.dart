// Calcul des marges figées d'une vente.
//
// Isolé ici — sans Firestore ni GetX — pour deux raisons :
//
// 1. c'est la seule partie réellement délicate du lot (répartition de la
//    remise globale, reliquat), donc la seule qui mérite des tests ;
// 2. le script de reprise `scripts/backfill_marges_ventes.js` applique
//    exactement les mêmes règles. Il tourne sur le SDK Admin, en
//    JavaScript : les deux implémentations **doivent rester
//    synchronisées**, et sont couvertes par les mêmes jeux de cas
//    (`test/marge_calculator_test.dart` et `scripts/test/`).
//
// Toute modification ici doit être reportée là-bas, et inversement.

import '../../data/models/vente_model.dart';

/// Résultat du calcul pour une vente entière.
class MargesVente {
  /// Lignes enrichies de `prixAchatUnitaire`, `remiseGlobaleAllouee`
  /// et `marge`.
  final List<VenteArticle> articles;

  /// Somme de `prixAchatUnitaire × quantite` sur toutes les lignes.
  final double coutAchatTotal;

  /// Somme des marges de ligne.
  final double margeTotale;

  const MargesVente({
    required this.articles,
    required this.coutAchatTotal,
    required this.margeTotale,
  });
}

/// Calcule les marges d'une vente et renvoie les lignes enrichies.
///
/// [prixAchatParProduit] donne le CMUP en vigueur au moment de la vente,
/// indexé par `produitId`. Les variantes ne portent pas de prix d'achat :
/// le CMUP est toujours celui du produit parent (cf. `VarianteModel`).
///
/// Un produit absent de la table — supprimé entre la mise au panier et la
/// validation, ou introuvable lors d'une reprise — est traité comme un
/// coût d'achat nul : la ligne compte alors pour sa totalité en marge.
/// C'est volontairement visible plutôt que silencieux, pour que le cas
/// ressorte dans les rapports au lieu d'être écarté du calcul.
///
/// [remiseGlobale] est la remise appliquée à la vente entière. Elle n'est
/// portée par aucune ligne : on la répartit **au prorata du montant net**
/// de chaque ligne (après remise de ligne).
MargesVente calculerMarges({
  required List<VenteArticle> articles,
  required double remiseGlobale,
  required Map<String, double> prixAchatParProduit,
}) {
  if (articles.isEmpty) {
    return const MargesVente(
      articles: [],
      coutAchatTotal: 0,
      margeTotale: 0,
    );
  }

  final parts = repartirRemiseGlobale(
    articles: articles,
    remiseGlobale: remiseGlobale,
  );

  final enrichies = <VenteArticle>[];
  var coutTotal = 0.0;
  var margeTotale = 0.0;

  for (var i = 0; i < articles.length; i++) {
    final a = articles[i];
    final pa = prixAchatParProduit[a.produitId] ?? 0.0;
    final cout = pa * a.quantite;
    final part = parts[i];
    final marge = a.sousTotal - part - cout;

    enrichies.add(a.copyWith(
      prixAchatUnitaire: pa,
      remiseGlobaleAllouee: part,
      marge: marge,
    ));
    coutTotal += cout;
    margeTotale += marge;
  }

  return MargesVente(
    articles: enrichies,
    coutAchatTotal: coutTotal,
    margeTotale: margeTotale,
  );
}

/// Répartit [remiseGlobale] sur les lignes, au prorata de leur montant net.
///
/// Renvoie une part par ligne, dans le même ordre que [articles]. La somme
/// des parts est **exactement** égale à [remiseGlobale] : la dernière ligne
/// absorbe le reliquat, sans quoi les erreurs d'arrondi flottant feraient
/// diverger la somme des marges du total réel de la vente.
///
/// Cas limites traités :
/// - remise nulle ou négative → que des zéros ;
/// - base nulle (lignes toutes à 0, ou remises de ligne couvrant tout) →
///   répartition impossible au prorata, on verse tout sur la dernière
///   ligne plutôt que de perdre la remise.
List<double> repartirRemiseGlobale({
  required List<VenteArticle> articles,
  required double remiseGlobale,
}) {
  final n = articles.length;
  if (n == 0) return const [];
  if (remiseGlobale <= 0) return List<double>.filled(n, 0);

  final base = articles.fold<double>(0, (acc, a) => acc + a.sousTotal);
  final parts = List<double>.filled(n, 0);

  if (base <= 0) {
    parts[n - 1] = remiseGlobale;
    return parts;
  }

  var cumul = 0.0;
  // La dernière ligne est calculée par différence : voir doc ci-dessus.
  for (var i = 0; i < n - 1; i++) {
    final part = remiseGlobale * (articles[i].sousTotal / base);
    parts[i] = part;
    cumul += part;
  }
  parts[n - 1] = remiseGlobale - cumul;
  return parts;
}
