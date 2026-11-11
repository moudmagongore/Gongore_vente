import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/caisse_model.dart';
import '../../data/models/paiement_caisse.dart';
import '../../theme/app_colors.dart';
import '../utils/caisse_calculator.dart';
import '../utils/caisse_contexte.dart';
import '../utils/format_helpers.dart';

/// Saisie de la répartition d'un paiement sur une ou plusieurs caisses.
///
/// Widget partagé par toutes les opérations qui font entrer ou sortir de
/// l'argent (dépense, vente, arrivage, règlements) : la mécanique de
/// répartition est la même partout, seul le sens change.
///
/// Si [caisses] est vide, le widget ne rend rien du tout — c'est à
/// l'appelant d'afficher le bandeau approprié (boutique sans caisse, ou
/// aucune caisse accessible).
///
/// Cas courant optimisé : tant qu'il n'y a qu'une ligne et que
/// l'utilisateur n'a pas touché son montant, celui-ci **suit
/// automatiquement** [montantAttendu]. Saisir « 50 000 » dans le champ
/// montant de l'opération remplit donc la caisse sans rien faire de plus.
class PaiementsCaisseField extends StatefulWidget {
  /// Caisses actives accessibles à l'utilisateur, dans l'ordre d'affichage.
  final List<CaisseModel> caisses;

  /// Montant total à répartir. Pour une vente, c'est le montant encaissé.
  final double montantAttendu;

  /// Répartition déjà enregistrée (correction d'une opération).
  final List<PaiementCaisse> initial;

  final ValueChanged<List<PaiementCaisse>> onChanged;

  /// Sens affiché dans les libellés : sortie d'argent ou entrée.
  final bool estSortie;

  const PaiementsCaisseField({
    super.key,
    required this.caisses,
    required this.montantAttendu,
    required this.onChanged,
    this.initial = const [],
    this.estSortie = true,
  });

  @override
  State<PaiementsCaisseField> createState() => _PaiementsCaisseFieldState();
}

/// Une ligne de saisie. Le contrôleur est porté par la ligne pour survivre
/// aux ajouts et suppressions d'autres lignes.
class _Ligne {
  String? caisseId;
  final TextEditingController ctrl;
  _Ligne({this.caisseId, String texte = ''})
      : ctrl = TextEditingController(text: texte);
}

class _PaiementsCaisseFieldState extends State<PaiementsCaisseField> {
  final List<_Ligne> _lignes = [];

  /// Vrai tant que l'utilisateur n'a pas saisi de montant à la main.
  bool _montantAuto = true;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) {
      _montantAuto = false;
      for (final p in widget.initial) {
        _lignes.add(_Ligne(
          caisseId: p.caisseId,
          texte: p.montant.toStringAsFixed(0),
        ));
      }
    } else if (widget.caisses.isNotEmpty) {
      _lignes.add(_Ligne(caisseId: widget.caisses.first.id));
      // Écriture directe : `initState` précède le premier build, rien
      // n'est en cours de construction.
      _lignes.first.ctrl.text = _texteMontantAuto();
    }
  }

  @override
  void didUpdateWidget(PaiementsCaisseField old) {
    super.didUpdateWidget(old);

    // Première caisse arrivée après coup (stream) : on crée la ligne.
    if (_lignes.isEmpty && widget.caisses.isNotEmpty) {
      _lignes.add(_Ligne(caisseId: widget.caisses.first.id));
      _planifierMontantAuto();
    }
    if (widget.montantAttendu != old.montantAttendu) {
      _planifierMontantAuto();
    }
  }

  String _texteMontantAuto() => widget.montantAttendu > 0
      ? widget.montantAttendu.toStringAsFixed(0)
      : '';

  /// Recopie le montant de l'opération sur l'unique ligne, tant que
  /// l'utilisateur ne l'a pas reprise en main.
  ///
  /// **Toujours après la frame.** Écrire dans un `TextEditingController`
  /// notifie ses auditeurs, dont le `FormField` qui l'entoure : appelé
  /// pendant le build — ce qui est le cas depuis `didUpdateWidget`, lui-même
  /// déclenché par un `Obx` qui se reconstruit — cela demande au `Form` de
  /// se reconstruire alors qu'il l'est déjà, et Flutter lève
  /// « setState() or markNeedsBuild() called during build ».
  ///
  /// Les conditions sont revérifiées dans le callback : une frame s'est
  /// écoulée, l'utilisateur a pu saisir un montant ou ajouter une ligne
  /// entre-temps.
  void _planifierMontantAuto() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_montantAuto || _lignes.length != 1) return;
      final texte = _texteMontantAuto();
      if (_lignes.first.ctrl.text == texte) return;
      // `setState` est indispensable, et pas seulement par habitude : le
      // champ se repeint tout seul puisqu'il écoute son contrôleur, mais
      // « Reste à répartir » est calculé dans `build` à partir du texte
      // des lignes. Sans reconstruction, cette ligne reste sur la valeur
      // précédente — on voyait « Reste à répartir : 45 000 » alors que la
      // caisse affichait déjà 50 000, l'écart étant exactement la frappe
      // qui venait d'avoir lieu.
      //
      // Légal ici : on est dans un post-frame callback, donc hors de la
      // phase de construction.
      setState(() => _lignes.first.ctrl.text = texte);
      _notifier();
    });
  }

  @override
  void dispose() {
    for (final l in _lignes) {
      l.ctrl.dispose();
    }
    super.dispose();
  }

  List<PaiementCaisse> get _paiements {
    final out = <PaiementCaisse>[];
    for (final l in _lignes) {
      final id = l.caisseId;
      if (id == null) continue;
      final montant = double.tryParse(l.ctrl.text.trim()) ?? 0;
      if (montant <= 0) continue;
      final caisse = widget.caisses.firstWhere(
        (c) => c.id == id,
        orElse: () => CaisseModel(id: id, nom: '?', boutiqueId: ''),
      );
      out.add(PaiementCaisse(
        caisseId: id,
        caisseNom: caisse.nom,
        montant: montant,
      ));
    }
    return out;
  }

  void _notifier() {
    if (!mounted) return;
    widget.onChanged(_paiements);
  }

  /// Caisses encore proposables pour une ligne : les autres lignes ont déjà
  /// pris les leurs (RG-10 — une caisse ne figure qu'une fois).
  List<CaisseModel> _disponiblesPour(_Ligne ligne) {
    final prises = _lignes
        .where((l) => l != ligne && l.caisseId != null)
        .map((l) => l.caisseId)
        .toSet();
    return widget.caisses.where((c) => !prises.contains(c.id)).toList();
  }

  void _ajouterLigne() {
    final libres = _disponiblesPour(_Ligne());
    final deja = _lignes.map((l) => l.caisseId).toSet();
    final suivante = libres.firstWhere(
      (c) => !deja.contains(c.id),
      orElse: () => libres.first,
    );
    setState(() {
      // Dès qu'il y a plusieurs lignes, le montant n'est plus recopié
      // automatiquement : c'est l'utilisateur qui répartit.
      _montantAuto = false;
      _lignes.add(_Ligne(caisseId: suivante.id));
    });
    _notifier();
  }

  void _supprimerLigne(_Ligne ligne) {
    setState(() {
      _lignes.remove(ligne);
      ligne.ctrl.dispose();
    });
    _notifier();
  }

  void _toutSurPremiere() {
    if (_lignes.isEmpty) return;
    setState(() {
      for (final l in _lignes.skip(1)) {
        l.ctrl.dispose();
      }
      _lignes.removeRange(1, _lignes.length);
      _montantAuto = true;
      // Déclenché par un tap : pas de build en cours, écriture directe.
      _lignes.first.ctrl.text = _texteMontantAuto();
    });
    _notifier();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caisses.isEmpty) return const SizedBox.shrink();

    final total = totalPaiements(_paiements);
    final reste = widget.montantAttendu - total;
    final plusieursPossible = widget.caisses.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 16, color: AppColors.primary(context)),
            const SizedBox(width: 6),
            Text(
              widget.estSortie ? 'Payé depuis *' : 'Encaissé sur *',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_lignes.length > 1)
              TextButton(
                onPressed: _toutSurPremiere,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Tout sur une caisse',
                    style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ..._lignes.map((ligne) {
          final dispo = _disponiblesPour(ligne);
          final valide =
              dispo.any((c) => c.id == ligne.caisseId) ? ligne.caisseId : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: valide,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: dispo
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.nom,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => ligne.caisseId = v);
                      _notifier();
                    },
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Caisse requise' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: ligne.ctrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Montant',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) {
                      _montantAuto = false;
                      setState(_notifier);
                    },
                  ),
                ),
                if (_lignes.length > 1)
                  IconButton(
                    onPressed: () => _supprimerLigne(ligne),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: AppColors.danger,
                    tooltip: 'Retirer cette ligne',
                  ),
              ],
            ),
          );
        }),
        if (plusieursPossible && _lignes.length < widget.caisses.length)
          TextButton.icon(
            onPressed: _ajouterLigne,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Ajouter une caisse',
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        // L'écart n'a de sens que si l'utilisateur gère la répartition
        // lui-même. Avec une ligne unique en recopie automatique, le
        // montant finit toujours par égaler celui de l'opération : la
        // frappe crée un écart d'une frame, et l'afficher faisait
        // apparaître puis disparaître la ligne à chaque caractère tapé.
        if (_lignes.length > 1 || (!_montantAuto && reste.abs() > 0.5))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              reste.abs() < 0.5
                  ? 'Réparti : ${Fmt.money(total, currency: 'GNF')}'
                  : reste > 0
                      ? 'Reste à répartir : '
                          '${Fmt.money(reste, currency: 'GNF')}'
                      : 'Dépassement de '
                          '${Fmt.money(-reste, currency: 'GNF')}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: reste.abs() < 0.5
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// Zone « payé depuis / encaissé sur » prête à poser dans un bottom sheet
/// autonome, avec ses quatre états.
///
/// [contexte] vaut `null` pendant le chargement : on affiche alors une
/// ligne d'attente plutôt que rien, sinon le bloc apparaîtrait d'un coup
/// sous les doigts de l'utilisateur.
class PaiementsCaisseBloc extends StatelessWidget {
  final CaisseContexte? contexte;
  final double montant;
  final ValueChanged<List<PaiementCaisse>> onChanged;
  final bool estSortie;

  const PaiementsCaisseBloc({
    super.key,
    required this.contexte,
    required this.montant,
    required this.onChanged,
    this.estSortie = false,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = contexte;
    if (ctx == null) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation(AppColors.greyText(context, 500)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Chargement des caisses...',
            style: TextStyle(
                fontSize: 11.5, color: AppColors.greyText(context, 600)),
          ),
        ],
      );
    }

    if (ctx.manquante) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aucune caisse disponible, contactez votre administrateur.',
                style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    // Boutique sans caisse : rien à demander, l'opération se déroule comme
    // avant le module (RG-9).
    if (!ctx.disponible) return const SizedBox.shrink();

    return PaiementsCaisseField(
      caisses: ctx.caisses,
      montantAttendu: montant,
      onChanged: onChanged,
      estSortie: estSortie,
    );
  }
}
