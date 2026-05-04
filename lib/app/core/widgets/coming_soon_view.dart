import 'package:flutter/material.dart';

import '../services/user_controller.dart';
import 'admin_drawer.dart';
import 'vendeur_drawer.dart';

/// Page placeholder pour les sections pas encore implémentées.
class ComingSoonView extends StatelessWidget {
  final String title;
  final String currentRoute;
  final IconData icon;
  final String? subtitle;

  const ComingSoonView({
    super.key,
    required this.title,
    required this.currentRoute,
    this.icon = Icons.construction_rounded,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserController.to.isAnyAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: isAdmin
          ? AdminDrawer(currentRoute: currentRoute)
          : VendeurDrawer(currentRoute: currentRoute),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 96, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle ?? 'Cette section sera disponible prochainement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
