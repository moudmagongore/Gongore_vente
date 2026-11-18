/// Levée quand on tente de modifier le solde initial d'un client ou d'un
/// fournisseur qui a déjà des opérations : à partir de là, le solde n'évolue
/// plus que par les ventes, approvisionnements et règlements.
class SoldeVerrouilleException implements Exception {
  const SoldeVerrouilleException();

  @override
  String toString() =>
      'Le solde initial ne peut plus être modifié : des opérations '
      'existent déjà.';
}
