import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/user_controller.dart';
import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../theme/app_colors.dart';

class ParametresView extends StatefulWidget {
  const ParametresView({super.key});

  @override
  State<ParametresView> createState() => _ParametresViewState();
}

class _ParametresViewState extends State<ParametresView> {
  final _bio = BiometricService.to;

  bool _loading = true;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  String _bioLabel = 'biométrie';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final available = await _bio.isAvailable();
    final enabled = await _bio.isEnabled();
    final label = available ? await _bio.typeLabel() : 'biométrie';
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
      _bioLabel = label;
      _loading = false;
    });
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.lightTextMuted,
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: AppColors.primary),
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
