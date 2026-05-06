import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../data/models/user_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/user_form_controller.dart';

class UserFormView extends GetView<UserFormController> {
  const UserFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.title)),
      ),
      body: androidOnlySafeArea(
        Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ============ Identité ============
            _SectionTitle('Identité'),
            const SizedBox(height: 12),
            Obx(
              () => _LabeledField(
                label: 'Nom complet *',
                child: TextFormField(
                  controller: controller.nomCtrl,
                  // En self-edit non-super, le nom est grisé. Seul le
                  // super-admin peut modifier ses propres infos.
                  enabled: !controller.isSelfEditRestricted,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: controller.validateNom,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Obx(
              () {
                // Email modifiable seulement à la création OU en self-edit
                // pour le super-admin. Verrouillé pour tous les autres
                // (synchro Firebase Auth non gérée).
                final emailEnabled = !controller.isEdit ||
                    (controller.isSelfEdit &&
                        !controller.isSelfEditRestricted);
                return _LabeledField(
                  label: 'Email *',
                  child: TextFormField(
                    controller: controller.emailCtrl,
                    enabled: emailEnabled,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: controller.validateEmail,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Obx(
              () => _LabeledField(
                label: 'Téléphone',
                child: TextFormField(
                  controller: controller.telephoneCtrl,
                  // Téléphone : verrouillé pour un user qui édite son propre
                  // profil (sauf super-admin qui peut tout modifier).
                  enabled: !controller.isSelfEditRestricted,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ============ Rôle & Boutique ============
            _SectionTitle(
              controller.canCreateAdmin
                  ? 'Rôle et affectation'
                  : 'Affectation',
            ),
            const SizedBox(height: 12),
            // Self-edit : on n'autorise jamais le changement de rôle (même
            // pour le super-admin). On affiche le rôle en lecture seule.
            if (controller.isSelfEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RoleReadOnly(role: controller.role.value),
              )
            // Sinon, sélection du rôle uniquement pour le super-admin créant
            // ou éditant un autre utilisateur.
            else if (controller.canCreateAdmin) ...[
              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        role: UserRole.admin,
                        selected: controller.role.value == UserRole.admin,
                        onTap: () {
                          controller.role.value = UserRole.admin;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        role: UserRole.vendeur,
                        selected: controller.role.value == UserRole.vendeur,
                        onTap: () =>
                            controller.role.value = UserRole.vendeur,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Cumul admin + gestionnaire : visible quand le rôle sélectionné
            // est admin. Cumule les droits gestionnaire en plus de admin.
            Obx(() {
              if (controller.role.value != UserRole.admin) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: SwitchListTile(
                    value: controller.alsoGestionnaire.value,
                    onChanged: (v) =>
                        controller.alsoGestionnaire.value = v,
                    title: const Text(
                      'Aussi gestionnaire de la boutique',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Donne en plus tous les droits gestionnaire (caisse, '
                      'encaisser, verser règlement, créer vente...).',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    activeThumbColor: AppColors.secondary,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                  ),
                ),
              );
            }),
            // Sélecteur boutique :
            // - super-admin self-edit : caché (super-admin n'est lié à aucune boutique)
            // - super-admin sur autre user : picker éditable
            // - admin/vendeur : boutique verrouillée sur la sienne (lecture seule)
            if (controller.hideBoutiqueField)
              const SizedBox.shrink()
            else if (controller.canPickBoutique)
              Obx(() {
                if (controller.boutiques.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aucune boutique active. Créez d\'abord une '
                            'boutique.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final safeId = controller.boutiques
                        .any((b) => b.id == controller.boutiqueId.value)
                    ? controller.boutiqueId.value
                    : null;
                return _LabeledField(
                  label: 'Boutique *',
                  child: DropdownButtonFormField<String>(
                    initialValue: safeId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    items: controller.boutiques
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => controller.boutiqueId.value = v,
                    validator: controller.validateBoutique,
                  ),
                );
              })
            else
              Obx(() {
                final bId = controller.boutiqueId.value;
                final b = controller.boutiques
                    .firstWhereOrNull((x) => x.id == bId);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Boutique : ${b?.nom ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),

            // ============ Mot de passe (création seulement) ============
            Obx(() {
              if (controller.isEdit) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Mot de passe'),
                  const SizedBox(height: 12),
                  Obx(
                    () => _LabeledField(
                      label: 'Mot de passe initial *',
                      child: TextFormField(
                        controller: controller.passwordCtrl,
                        obscureText: controller.obscurePassword.value,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Générer',
                                onPressed: controller.generatePassword,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                              IconButton(
                                onPressed:
                                    controller.obscurePassword.toggle,
                                icon: Icon(
                                  controller.obscurePassword.value
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ],
                          ),
                          helperText: 'Au moins 6 caractères',
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                        ],
                        validator: controller.validatePassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => CheckboxListTile(
                      value: controller.sendResetEmail.value,
                      onChanged: (v) =>
                          controller.sendResetEmail.value = v ?? true,
                      title: const Text(
                        'Envoyer un email de définition du mot de passe',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'L\'utilisateur recevra un lien pour choisir lui-même '
                        'son mot de passe (recommandé).',
                        style: TextStyle(fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // ============ Statut ============
            // En self-edit, le switch est masqué (l'utilisateur ne peut pas
            // se désactiver lui-même).
            if (!controller.isSelfEdit) ...[
              _SectionTitle('Statut'),
              const SizedBox(height: 6),
              Obx(
                () => SwitchListTile(
                  value: controller.active.value,
                  onChanged: (v) => controller.active.value = v,
                  title: const Text('Compte actif'),
                  subtitle: Text(
                    controller.active.value
                        ? 'L\'utilisateur peut se connecter'
                        : 'L\'utilisateur ne peut pas se connecter',
                    style: const TextStyle(fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ============ Bouton "Enregistrer" identité ============
            // Placé juste après les sections identité / rôle / boutique /
            // statut — il sauvegarde ces informations. Caché pour les users
            // restreints en self-edit (non-super), qui ne peuvent rien
            // modifier ici à part leur mot de passe.
            if (!controller.isSelfEditRestricted) ...[
              Obx(
                () => ElevatedButton.icon(
                  onPressed:
                      controller.isSaving.value ? null : controller.save,
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(controller.isEdit
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded),
                  label: Text(
                    controller.isEdit
                        ? 'Enregistrer'
                        : 'Créer l\'utilisateur',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ============ Section changement de mot de passe ============
            // Visible UNIQUEMENT en self-edit. Possède son propre bouton
            // « Mettre à jour le mot de passe » à la fin.
            if (controller.isSelfEdit) ...[
              _ChangePasswordSection(),
              const SizedBox(height: 16),
            ],

            // ============ Bouton Annuler / Fermer ============
            OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                    color: AppColors.primary, width: 1.4),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                controller.isSelfEditRestricted ? 'Fermer' : 'Annuler',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  // ignore: use_super_parameters
  const _SectionTitle(this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.lightTextMuted,
      ),
    );
  }
}

/// Champ avec un petit label texte au-dessus (au lieu d'un labelText flottant
/// qui surcharge visuellement le formulaire).
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Section "Changer mon mot de passe" affichée uniquement en self-edit.
/// Demande le mot de passe actuel + nouveau (avec confirmation), puis
/// re-authentifie l'utilisateur via Firebase Auth avant de mettre à jour
/// son mot de passe.
class _ChangePasswordSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<UserFormController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Changer mon mot de passe'),
        const SizedBox(height: 12),
        Obx(
          () => _LabeledField(
            label: 'Mot de passe actuel',
            child: TextField(
              controller: c.currentPwdCtrl,
              obscureText: c.obscureCurrent.value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: c.obscureCurrent.toggle,
                  icon: Icon(
                    c.obscureCurrent.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Obx(
          () => _LabeledField(
            label: 'Nouveau mot de passe',
            child: TextField(
              controller: c.newPwdCtrl,
              obscureText: c.obscureNew.value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: c.obscureNew.toggle,
                  icon: Icon(
                    c.obscureNew.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                helperText: 'Au moins 6 caractères',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed:
                  c.isChangingPassword.value ? null : c.changeMyPassword,
              icon: c.isChangingPassword.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Mettre à jour le mot de passe'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Affichage lecture seule du rôle (utilisé en mode "Mon compte" — le rôle
/// n'est jamais modifiable par l'utilisateur lui-même, même super-admin).
class _RoleReadOnly extends StatelessWidget {
  final UserRole role;
  const _RoleReadOnly({required this.role});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (role) {
      case UserRole.superAdmin:
        icon = Icons.shield_rounded;
        color = const Color(0xFF6A1B9A);
        break;
      case UserRole.admin:
        icon = Icons.admin_panel_settings_rounded;
        color = AppColors.primary;
        break;
      case UserRole.vendeur:
        icon = Icons.point_of_sale_rounded;
        color = AppColors.secondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rôle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  role.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    final color = isAdmin ? AppColors.primary : AppColors.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.point_of_sale_rounded,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              role.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? 'Accès complet'
                  : 'Caisse + sa boutique',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
