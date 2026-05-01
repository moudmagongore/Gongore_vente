import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ============ Identité ============
            _SectionTitle('Identité'),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: controller.validateNom,
            ),
            const SizedBox(height: 14),
            Obx(
              () => TextFormField(
                controller: controller.emailCtrl,
                enabled: !controller.isEdit,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  helperText: controller.isEdit
                      ? 'L\'email ne peut pas être modifié'
                      : null,
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: controller.validateEmail,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.telephoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+224 ...',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // ============ Rôle & Boutique ============
            _SectionTitle(
              controller.canCreateAdmin
                  ? 'Rôle et affectation'
                  : 'Affectation',
            ),
            const SizedBox(height: 12),
            // Sélection du rôle uniquement pour le super-admin
            if (controller.canCreateAdmin) ...[
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
            // Sélecteur boutique : visible pour super-admin uniquement.
            // Pour admin de boutique, la boutique est verrouillée sur la sienne.
            if (controller.canPickBoutique)
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
                return DropdownButtonFormField<String>(
                  initialValue: safeId,
                  decoration: const InputDecoration(
                    labelText: 'Boutique *',
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
                    () => TextFormField(
                      controller: controller.passwordCtrl,
                      obscureText: controller.obscurePassword.value,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe initial *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Générer',
                              onPressed: controller.generatePassword,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                            IconButton(
                              onPressed: controller.obscurePassword.toggle,
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
            const SizedBox(height: 32),

            // ============ Actions ============
            Obx(
              () => ElevatedButton.icon(
                onPressed: controller.isSaving.value ? null : controller.save,
                icon: controller.isSaving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Annuler'),
            ),
          ],
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
