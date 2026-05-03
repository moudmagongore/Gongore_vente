import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/admin_drawer.dart';
import '../../../../data/models/user_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/users_controller.dart';

class UsersListView extends GetView<UsersController> {
  const UsersListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isSuperAdmin ? 'Utilisateurs' : 'Mes vendeurs',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom, email, téléphone...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminUsers),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          _FiltersBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filtered;
              if (list.isEmpty) {
                return _Empty(hasSearch: controller.search.value.isNotEmpty);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _UserTile(user: list[i]),
              );
            }),
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.adminUserForm),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          controller.isSuperAdmin ? 'Nouvel utilisateur' : 'Nouveau vendeur',
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final UsersController controller;

  const _FiltersBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(() {
        // Admin de boutique : pas de filtre rôle (toujours vendeurs)
        if (!controller.isSuperAdmin) {
          return Row(
            children: [
              _Chip(
                label: 'Mes vendeurs (${controller.nbVendeurs})',
                selected: true,
                onTap: () {},
              ),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'Tous',
                selected: controller.filterRole.value == null,
                onTap: () => controller.setFilterRole(null),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Admins (${controller.nbAdmins})',
                selected: controller.filterRole.value == UserRole.admin,
                onTap: () => controller.setFilterRole(UserRole.admin),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Vendeurs (${controller.nbVendeurs})',
                selected: controller.filterRole.value == UserRole.vendeur,
                onTap: () => controller.setFilterRole(UserRole.vendeur),
              ),
              if (controller.boutiques.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 12),
                _BoutiqueDropdown(controller: controller),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BoutiqueDropdown extends StatelessWidget {
  final UsersController controller;

  const _BoutiqueDropdown({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<String?>(
        value: controller.filterBoutiqueId.value,
        underline: const SizedBox.shrink(),
        isDense: true,
        hint: const Text('Toutes boutiques', style: TextStyle(fontSize: 12)),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Toutes boutiques', style: TextStyle(fontSize: 12)),
          ),
          ...controller.boutiques.map(
            (b) => DropdownMenuItem<String?>(
              value: b.id,
              child: Text(b.nom, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
        onChanged: controller.setFilterBoutique,
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UsersController>();
    final color = user.isAdmin ? AppColors.primary : AppColors.secondary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.adminUserForm,
          arguments: user,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  user.nom.isEmpty ? '?' : user.nom[0].toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _RoleBadge(role: user.role),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.isVendeur)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                controller.boutiqueNom(user.boutiqueId),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!user.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DÉSACTIVÉ',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Get.toNamed(AppRoutes.adminUserForm, arguments: user);
                      break;
                    case 'reset':
                      controller.sendPasswordReset(user);
                      break;
                    case 'toggle':
                      controller.toggleActive(user);
                      break;
                    case 'delete':
                      controller.confirmDelete(user);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: ListTile(
                      leading: Icon(Icons.lock_reset_rounded),
                      title: Text('Réinitialiser mot de passe'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        user.active
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined,
                      ),
                      title: Text(user.active ? 'Désactiver' : 'Activer'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    final color = isAdmin ? AppColors.primary : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'VENDEUR',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasSearch;
  const _Empty({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun utilisateur ne correspond.'
                  : 'Aucun utilisateur (à part vous).',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
