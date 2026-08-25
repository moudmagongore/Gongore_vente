import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/services/phone_index_migration.dart';
import '../../../../data/models/abonnement_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/abonnement_params_controller.dart';

class AbonnementParamsView extends GetView<AbonnementParamsController> {
  const AbonnementParamsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres abonnements')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // Tarifs par devise
                for (final devise in AbonnementParamsController.devises) ...[
                  _SectionTitle(label: 'Tarifs ($devise)'),
                  const SizedBox(height: 8),
                  _TarifsBlock(devise: devise, controller: controller),
                  const SizedBox(height: 20),
                ],

                _SectionTitle(label: 'Période de grâce'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Délai post-expiration (en jours) pendant lequel '
                        'l\'app reste accessible avec un bandeau d\'alerte. '
                        'Au-delà, le login est refusé.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText(context, 700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller.graceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jours de grâce',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'Valeur invalide';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _SectionTitle(label: 'Délai d\'alerte'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre de jours avant la fin de l\'abonnement à '
                        'partir duquel l\'admin / gestionnaire de la '
                        'boutique reçoit une alerte (snackbar à la '
                        'connexion + bandeau permanent sur le tableau '
                        'de bord).',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText(context, 700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller.warningCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jours avant alerte',
                          prefixIcon: Icon(Icons.notifications_active_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'Valeur invalide';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Obx(
                  () => FilledButton.icon(
                    onPressed:
                        controller.isSaving.value ? null : controller.save,
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(controller.isSaving.value
                        ? 'Enregistrement...'
                        : 'Enregistrer'),
                  ),
                ),

                const SizedBox(height: 28),

                // ===== Maintenance =====
                _SectionTitle(label: 'Maintenance'),
                const SizedBox(height: 8),
                _PhoneIndexMigrationBlock(),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.greyText(context, 700),
      ),
    );
  }
}

class _TarifsBlock extends StatelessWidget {
  final String devise;
  final AbonnementParamsController controller;
  const _TarifsBlock({required this.devise, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tarif pré-rempli au formulaire d\'enregistrement de paiement. '
            'Laisser vide = saisie manuelle obligatoire.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.greyText(context, 700),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < AbonnementPeriode.values.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _TarifField(
              periode: AbonnementPeriode.values[i],
              devise: devise,
              ctrl: controller
                  .tarifCtrls['${devise}_${AbonnementPeriode.values[i].name}']!,
            ),
          ],
        ],
      ),
    );
  }
}

class _TarifField extends StatelessWidget {
  final AbonnementPeriode periode;
  final String devise;
  final TextEditingController ctrl;
  const _TarifField({
    required this.periode,
    required this.devise,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: periode.label,
        suffixText: devise,
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null; // tarif optionnel
        final n = double.tryParse(t.replaceAll(',', '.'));
        if (n == null || n < 0) return 'Montant invalide';
        return null;
      },
    );
  }
}

/// Bloc de maintenance pour reconstruire la collection `phone_index`
/// (login hybride email/téléphone) à partir des utilisateurs existants.
/// À utiliser après le déploiement initial de la fonctionnalité ou si
/// l'index est désynchronisé.
class _PhoneIndexMigrationBlock extends StatefulWidget {
  @override
  State<_PhoneIndexMigrationBlock> createState() =>
      _PhoneIndexMigrationBlockState();
}

class _PhoneIndexMigrationBlockState
    extends State<_PhoneIndexMigrationBlock> {
  bool _running = false;
  String? _lastResult;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lastResult = null;
    });
    try {
      final res = await PhoneIndexMigration.run();
      setState(() => _lastResult = res.summary);
      Get.snackbar(
        'Migration terminée',
        res.summary,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      setState(() => _lastResult = 'Erreur : $e');
      Get.snackbar(
        'Migration échouée',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reconstruire l\'index téléphone → email pour permettre la '
            'connexion par numéro. À lancer une fois après le déploiement '
            'de la fonctionnalité, ou si certains utilisateurs n\'arrivent '
            'pas à se connecter avec leur téléphone.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.greyText(context, 700),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(_running
                ? 'Migration en cours...'
                : 'Reconstruire l\'index téléphone'),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 10),
            Text(
              _lastResult!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText(context, 800),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
