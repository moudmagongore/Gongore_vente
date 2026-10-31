import 'package:cloud_firestore/cloud_firestore.dart';

import 'paiement_caisse.dart';
import 'vente_model.dart';

/// Trace d'une imputation : « ce règlement a couvert X sur la vente Y ».
/// Permet l'inversion atomique en cas de suppression du règlement.
class Imputation {
  final String venteId;
  /// Numéro affichable de la vente (snapshot pour affichage offline).
  final String? numero;
  final double montant;

  const Imputation({
    required this.venteId,
    required this.montant,
    this.numero,
  });

  factory Imputation.fromMap(Map<String, dynamic> map) => Imputation(
        venteId: (map['venteId'] ?? '') as String,
        numero: map['numero'] as String?,
        montant: (map['montant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'venteId': venteId,
        if (numero != null) 'numero': numero,
        'montant': montant,
      };
}

/// Règlement de dette d'un client : entrée d'argent en dehors d'une vente.
/// Diminue le solde du client de [montant] (atomique côté repository).
/// Le montant est imputé en FIFO sur les ventes en crédit du client ;
/// chaque imputation est tracée dans [imputations] pour permettre l'inversion
/// en cas de suppression du règlement.
class ReglementModel {
  final String id;
  final String clientId;
  final String boutiqueId;
  final String userId;

  /// Montant encaissé (toujours positif).
  final double montant;

  /// Ancien canal de paiement (Espèces / Mobile Money...). `null` pour les
  /// règlements imputés sur des caisses : c'est alors [paiements] qui dit
  /// où l'argent est entré. Conservé pour l'historique antérieur au module
  /// de caisse.
  final ModePaiement? modePaiement;

  /// Répartition sur les caisses (RG-10). Vide pour les règlements
  /// antérieurs au module de caisse et pour les boutiques qui n'en ont
  /// pas encore (RG-9).
  final List<PaiementCaisse> paiements;

  bool get passeParCaisse => paiements.isNotEmpty;

  /// Libellé du canal de paiement, pour l'affichage et les reçus : les
  /// caisses quand il y en a, sinon l'ancien mode de paiement.
  ///
  /// Un seul point de vérité : les écrans n'ont pas à savoir lequel des
  /// deux renseigner.
  String get libellePaiement => passeParCaisse
      ? paiements.map((p) => p.caisseNom).join(' + ')
      : (modePaiement?.label ?? '—');

  final DateTime date;
  final String? note;

  /// Imputations FIFO sur les ventes en crédit (renseignées à la création
  /// par [ReglementRepository.create]). Le total des imputations peut être
  /// inférieur à [montant] : le surplus va en avance (solde négatif).
  final List<Imputation> imputations;

  const ReglementModel({
    required this.id,
    required this.clientId,
    required this.boutiqueId,
    required this.userId,
    required this.montant,
    required this.date,
    this.modePaiement,
    this.paiements = const [],
    this.note,
    this.imputations = const [],
  });

  factory ReglementModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = (map['imputations'] as List?) ?? const [];
    return ReglementModel(
      id: id,
      clientId: (map['clientId'] ?? '') as String,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      modePaiement: map['modePaiement'] == null
          ? null
          : ModePaiement.fromString(map['modePaiement'] as String?),
      paiements: PaiementCaisse.listFromMap(map['paiements']),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      imputations: raw
          .map((e) => Imputation.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory ReglementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ReglementModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'montant': montant,
        if (modePaiement != null) 'modePaiement': modePaiement!.name,
        'paiements': paiements.map((p) => p.toMap()).toList(),
        'date': Timestamp.fromDate(date),
        'note': note,
        'imputations': imputations.map((i) => i.toMap()).toList(),
      };

  /// Total réellement imputé sur des ventes (peut être < montant si surplus).
  double get totalImpute =>
      imputations.fold(0.0, (acc, i) => acc + i.montant);

  /// Surplus (avance) déposé sur le solde après imputation FIFO.
  double get surplus => montant - totalImpute;
}
