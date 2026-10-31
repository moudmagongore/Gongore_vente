import 'package:cloud_firestore/cloud_firestore.dart';

import 'paiement_caisse.dart';
import 'vente_model.dart' show ModePaiement;

/// Trace d'une imputation d'un règlement fournisseur sur une appro
/// précédemment en crédit. Permet l'inversion atomique en cas de
/// suppression du règlement.
class ImputationFournisseur {
  final String approId;
  /// Snapshot du numéro lisible de l'appro (préserve l'affichage offline).
  final String? numero;
  final double montant;

  const ImputationFournisseur({
    required this.approId,
    required this.montant,
    this.numero,
  });

  factory ImputationFournisseur.fromMap(Map<String, dynamic> map) =>
      ImputationFournisseur(
        approId: (map['approId'] ?? '') as String,
        numero: map['numero'] as String?,
        montant: (map['montant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'approId': approId,
        if (numero != null) 'numero': numero,
        'montant': montant,
      };
}

/// Règlement versé à un fournisseur en dehors d'un appro.
/// Diminue le solde du fournisseur de [montant] (atomique).
/// Le montant est imputé en FIFO sur les approvisionnements en crédit ;
/// chaque imputation est tracée dans [imputations] pour permettre
/// l'inversion en cas de suppression.
class ReglementFournisseurModel {
  final String id;
  final String fournisseurId;
  final String boutiqueId;
  final String userId;

  /// Montant versé (toujours positif).
  final double montant;

  /// Ancien canal de paiement. `null` pour les règlements imputés sur des
  /// caisses : c'est alors [paiements] qui dit d'où l'argent est sorti.
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

  /// Imputations FIFO sur les appros en crédit (renseignées à la création
  /// par [ReglementFournisseurRepository.create]). Le total des imputations
  /// peut être inférieur à [montant] : le surplus va en avance fournisseur
  /// (solde négatif).
  final List<ImputationFournisseur> imputations;

  const ReglementFournisseurModel({
    required this.id,
    required this.fournisseurId,
    required this.boutiqueId,
    required this.userId,
    required this.montant,
    required this.date,
    this.modePaiement,
    this.paiements = const [],
    this.note,
    this.imputations = const [],
  });

  factory ReglementFournisseurModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final raw = (map['imputations'] as List?) ?? const [];
    return ReglementFournisseurModel(
      id: id,
      fournisseurId: (map['fournisseurId'] ?? '') as String,
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
          .map((e) => ImputationFournisseur.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  factory ReglementFournisseurModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ReglementFournisseurModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'fournisseurId': fournisseurId,
        'boutiqueId': boutiqueId,
        'userId': userId,
        'montant': montant,
        if (modePaiement != null) 'modePaiement': modePaiement!.name,
        'paiements': paiements.map((p) => p.toMap()).toList(),
        'date': Timestamp.fromDate(date),
        'note': note,
        'imputations': imputations.map((i) => i.toMap()).toList(),
      };

  /// Total réellement imputé sur des appros (peut être < montant si surplus).
  double get totalImpute =>
      imputations.fold(0.0, (acc, i) => acc + i.montant);

  /// Surplus (avance versée au fournisseur) après imputation FIFO.
  double get surplus => montant - totalImpute;
}
