import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/user_controller.dart';
import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../data/models/app_update_config_model.dart';
import '../../../data/repositories/app_update_repository.dart';
import '../../../theme/app_colors.dart';

class ParametresView extends StatefulWidget {
  const ParametresView({super.key});

  @override
  State<ParametresView> createState() => _ParametresViewState();
}

class _ParametresViewState extends State<ParametresView> {
  final _bio = BiometricService.to;
  final _updateRepo = AppUpdateRepository();

  bool _loading = true;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  String _bioLabel = 'biométrie';
  bool _busy = false;

  // Mise à jour forcée (super-admin uniquement).
  final _updateFormKey = GlobalKey<FormState>();
  final _minVersionCtrl = TextEditingController();
  final _iosStoreCtrl = TextEditingController();
  final _androidStoreCtrl = TextEditingController();
  final _updateMessageCtrl = TextEditingController();
  bool _savingUpdate = false;

  bool get _isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _minVersionCtrl.dispose();
    _iosStoreCtrl.dispose();
    _androidStoreCtrl.dispose();
    _updateMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final available = await _bio.isAvailable();
    final enabled = await _bio.isEnabled();
    final label = available ? await _bio.typeLabel() : 'biométrie';

    // Charge la config de mise à jour forcée si super-admin (best-effort).
    if (_isSuperAdmin) {
      try {
        final upd = await _updateRepo.get();
        _minVersionCtrl.text = upd.minVersion;
        _iosStoreCtrl.text = upd.iosStoreUrl;
        _androidStoreCtrl.text = upd.androidStoreUrl;
        _updateMessageCtrl.text = upd.message ?? '';
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
      _bioLabel = label;
      _loading = false;
    });
  }

  Future<void> _saveUpdateConfig() async {
    if (!(_updateFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingUpdate = true);
    try {
      await _updateRepo.save(AppUpdateConfigModel(
        minVersion: _minVersionCtrl.text.trim(),
        iosStoreUrl: _iosStoreCtrl.text.trim(),
        androidStoreUrl: _androidStoreCtrl.text.trim(),
        message: _updateMessageCtrl.text.trim().isEmpty
            ? null
            : _updateMessageCtrl.text.trim(),
      ));
      Get.snackbar(
        'Enregistré',
        'Configuration de mise à jour mise à jour.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        '$e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
      );
    } finally {
      if (mounted) setState(() => _savingUpdate = false);
    }
  }

  Future<void> _onToggleBiometric(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        await _enable();
      } else {
        await _disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    final user = UserController.to.user;
    final email = user?.email ?? AuthService.to.currentUser?.email;
    if (email == null) {
      _snackError('Impossible de récupérer votre email.');
      return;
    }

    final password = await _askPassword();
    if (password == null || password.isEmpty) return;

    // Vérifie que le mot de passe est correct en re-signant avant de stocker.
    try {
      await AuthService.to.signInWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _snackError('Mot de passe incorrect.');
      } else {
        _snackError(e.message ?? 'Erreur de vérification.');
      }
      return;
    }

    final ok = await _bio.authenticate(
      reason: 'Confirmez avec $_bioLabel pour activer la connexion rapide.',
    );
    if (!ok) return;

    await _bio.enable(email: email, password: password);
    if (!mounted) return;
    setState(() => _bioEnabled = true);
    Get.snackbar(
      'Activé',
      'Connexion avec $_bioLabel activée.',
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<void> _disable() async {
    await _bio.disable();
    if (!mounted) return;
    setState(() => _bioEnabled = false);
    Get.snackbar(
      'Désactivé',
      'Connexion avec $_bioLabel désactivée.',
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<String?> _askPassword() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    final result = await Get.dialog<String>(
      StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('Confirmer votre mot de passe'),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setLocal(() => obscure = !obscure),
                icon: Icon(obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<String?>(result: null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Get.back<String?>(result: ctrl.text),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    return result;
  }

  void _snackError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: androidOnlySafeArea(
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _SectionTitle('Sécurité'),
                  const SizedBox(height: 8),
                  _BiometricCard(
                    available: _bioAvailable,
                    enabled: _bioEnabled,
                    label: _bioLabel,
                    busy: _busy,
                    onChanged: _onToggleBiometric,
                  ),
                  if (_isSuperAdmin) ...[
                    const SizedBox(height: 24),
                    _SectionTitle('Mise à jour forcée'),
                    const SizedBox(height: 8),
                    _ForceUpdateCard(
                      formKey: _updateFormKey,
                      minVersionCtrl: _minVersionCtrl,
                      iosStoreCtrl: _iosStoreCtrl,
                      androidStoreCtrl: _androidStoreCtrl,
                      updateMessageCtrl: _updateMessageCtrl,
                      saving: _savingUpdate,
                      onSave: _saveUpdateConfig,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.greyText(context, 700),
        ),
      ),
    );
  }
}

class _BiometricCard extends StatelessWidget {
  final bool available;
  final bool enabled;
  final String label;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _BiometricCard({
    required this.available,
    required this.enabled,
    required this.label,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFace = label.toLowerCase().contains('face');
    final iconData = isFace ? Icons.face_rounded : Icons.fingerprint_rounded;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: AppColors.primary(context)),
          ),
          title: Text(
            available
                ? 'Connexion avec $label'
                : 'Biométrie indisponible',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            available
                ? 'Déverrouillez votre compte sans saisir votre mot de passe.'
                : 'Aucun matériel biométrique configuré sur cet appareil.',
            style: const TextStyle(fontSize: 12),
          ),
          value: enabled,
          onChanged: (!available || busy) ? null : onChanged,
        ),
      ),
    );
  }
}

/// Section super-admin : configuration de la version minimale forcée et
/// des URL des stores (App Store / Play Store). Le check tourne au splash
/// avant tout login.
class _ForceUpdateCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController minVersionCtrl;
  final TextEditingController iosStoreCtrl;
  final TextEditingController androidStoreCtrl;
  final TextEditingController updateMessageCtrl;
  final bool saving;
  final VoidCallback onSave;

  const _ForceUpdateCard({
    required this.formKey,
    required this.minVersionCtrl,
    required this.iosStoreCtrl,
    required this.androidStoreCtrl,
    required this.updateMessageCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quand un utilisateur ouvre l\'app, sa version est comparée '
                'à la version minimale ci-dessous. Si elle est plus '
                'ancienne, un dialog non-fermable l\'oblige à mettre à '
                'jour via le store. Laisser vide pour désactiver le forçage.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText(context, 700),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: minVersionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Version minimale',
                  hintText: 'ex: 1.2.5',
                  prefixIcon: Icon(Icons.system_update_rounded),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  if (!RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(t)) {
                    return 'Format MAJOR.MINOR.PATCH (ex: 1.2.5)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: iosStoreCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL App Store iOS',
                  hintText: 'https://apps.apple.com/app/id…',
                  prefixIcon: Icon(Icons.apple),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: androidStoreCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL Play Store Android',
                  hintText: 'https://play.google.com/store/apps/details?id=…',
                  prefixIcon: Icon(Icons.android),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: updateMessageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message (optionnel)',
                  hintText: 'Ex: Corrections importantes et nouveautés',
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(saving
                      ? 'Enregistrement...'
                      : 'Enregistrer la mise à jour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
