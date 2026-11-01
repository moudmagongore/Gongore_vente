/// Une ligne « caisse + montant » d'une opération.
///
/// Portée par la vente, l'arrivage, le règlement ou la dépense sous forme
/// de liste : une opération peut être réglée sur plusieurs caisses
/// (paiement mixte). Le nom est dénormalisé pour que l'historique reste
/// lisible après un renommage ou une suppression de la caisse.
class PaiementCaisse {
  final String caisseId;
  final String caisseNom;
  final double montant;

  /// Id du mouvement écrit pour cette ligne. `null` tant que l'opération
  /// n'est pas enregistrée : il est renseigné par la transaction.
  final String? mouvementId;

  const PaiementCaisse({
    required this.caisseId,
    required this.caisseNom,
    required this.montant,
    this.mouvementId,
  });

  factory PaiementCaisse.fromMap(Map<String, dynamic> map) {
    return PaiementCaisse(
      caisseId: (map['caisseId'] ?? '') as String,
      caisseNom: (map['caisseNom'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      mouvementId: map['mouvementId'] as String?,
    );
  }

  static List<PaiementCaisse> listFromMap(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PaiementCaisse.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  Map<String, dynamic> toMap() => {
        'caisseId': caisseId,
        'caisseNom': caisseNom,
        'montant': montant,
        if (mouvementId != null) 'mouvementId': mouvementId,
      };

  PaiementCaisse copyWith({String? mouvementId}) => PaiementCaisse(
        caisseId: caisseId,
        caisseNom: caisseNom,
        montant: montant,
        mouvementId: mouvementId ?? this.mouvementId,
      );
}
