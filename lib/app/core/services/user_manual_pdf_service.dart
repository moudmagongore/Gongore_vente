import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';
import '../utils/pdf_share_helper.dart';
import 'pdf_theme_service.dart';

/// Génère un manuel utilisateur PDF complet de l'application.
///
/// Le manuel couvre les trois rôles (super-admin, administrateur,
/// gestionnaire) en un seul document. Il est généré à la demande depuis
/// l'app (accessible via le drawer > "Manuel utilisateur") et peut être
/// partagé / imprimé / enregistré.
class UserManualPdfService {
  UserManualPdfService._();

  static const PdfColor _primary = PdfColor.fromInt(0xFF1E3A8A); // navy
  static const PdfColor _accent = PdfColor.fromInt(0xFF14B8A6); // teal
  static const PdfColor _bgNote = PdfColor.fromInt(0xFFEFF6FF);
  static const PdfColor _borderNote = PdfColor.fromInt(0xFFBFDBFE);
  static const PdfColor _bgWarn = PdfColor.fromInt(0xFFFFF7ED);
  static const PdfColor _borderWarn = PdfColor.fromInt(0xFFFED7AA);
  static const PdfColor _bgTip = PdfColor.fromInt(0xFFF0FDF4);
  static const PdfColor _borderTip = PdfColor.fromInt(0xFFBBF7D0);

  /// Génère le PDF puis ouvre l'écran de prévisualisation in-app
  /// (impression / partage / sauvegarde). Affiche un spinner pendant
  /// la génération.
  static Future<void> openAndPreview() async {
    // Spinner non-dismissible pendant la génération (peut prendre
    // 1-2 secondes selon le device).
    Get.dialog<void>(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await generate();
      // Ferme le spinner avant d'ouvrir le preview.
      if (Get.isDialogOpen ?? false) Get.back();
      await sharePdfBytes(
        bytes: Uint8List.fromList(bytes),
        filename: 'Manuel-${AppConstants.appName.replaceAll(' ', '-')}.pdf',
        previewTitle: 'Manuel utilisateur',
        // DPI bas pour éviter les OOM Android sur un document multi-pages.
        // Chaque page rasterisée consomme ~DPI² × 4 octets de RAM ; à 400
        // DPI × 30 pages, on dépasse la limite heap d'un device standard.
        // 150 DPI reste largement net pour une lecture A4 (équivalent
        // d'un rendu écran haute densité).
        dpi: 150,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Erreur',
        'Impossible de générer le manuel : $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  /// Génère le PDF du manuel et renvoie ses octets.
  static Future<List<int>> generate() async {
    final theme = await PdfThemeService.theme;
    final info = await PackageInfo.fromPlatform();
    final version = info.version;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final doc = pw.Document(theme: theme);

    // ============== Couverture ==============
    doc.addPage(_buildCoverPage(version, dateStr));

    // ============== Sommaire ==============
    doc.addPage(_buildTocPage());

    // ============== Sections (MultiPage pour pagination auto) ==============
    _addSection(
      doc,
      title: '1. Introduction',
      builder: _buildIntroduction,
    );
    _addSection(
      doc,
      title: '2. Premier accès',
      builder: _buildPremierAcces,
    );
    _addSection(
      doc,
      title: '3. Navigation & concepts',
      builder: _buildNavigation,
    );
    _addSection(
      doc,
      title: '4. Guide super-administrateur',
      builder: _buildSuperAdmin,
    );
    _addSection(
      doc,
      title: '5. Guide administrateur',
      builder: _buildAdmin,
    );
    _addSection(
      doc,
      title: '6. Guide gestionnaire',
      builder: _buildGestionnaire,
    );
    _addSection(
      doc,
      title: '7. Multi-boutique',
      builder: _buildMultiBoutique,
    );
    _addSection(
      doc,
      title: '8. Abonnements',
      builder: _buildAbonnements,
    );
    _addSection(
      doc,
      title: '9. FAQ',
      builder: _buildFaq,
    );
    _addSection(
      doc,
      title: '10. Support',
      builder: _buildSupport,
    );

    return doc.save();
  }

  // ============================================================
  // Helpers de page / mise en forme
  // ============================================================

  static void _addSection(
    pw.Document doc, {
    required String title,
    required List<pw.Widget> Function() builder,
  }) {
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(40, 50, 40, 40),
        header: (ctx) => _header(title),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => builder(),
      ),
    );
  }

  static pw.Widget _header(String section) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            AppConstants.appName,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.Text(
            section,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Manuel utilisateur — ${AppConstants.appName}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Pages spéciales (couverture + sommaire)
  // ============================================================

  static pw.Page _buildCoverPage(String version, String dateStr) {
    return pw.Page(
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Container(
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
            colors: [_primary, _accent],
          ),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                height: 100,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                  shape: pw.BoxShape.circle,
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'G',
                  style: pw.TextStyle(
                    fontSize: 60,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  fontSize: 42,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white.shade(0.2),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'Manuel utilisateur',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 80),
              pw.Text(
                'Version $version',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Édité le $dateStr',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.white,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Page _buildTocPage() {
    final entries = <List<String>>[
      ['1', 'Introduction'],
      ['2', 'Premier accès'],
      ['3', 'Navigation & concepts'],
      ['4', 'Guide super-administrateur'],
      ['5', 'Guide administrateur'],
      ['6', 'Guide gestionnaire'],
      ['7', 'Multi-boutique'],
      ['8', 'Abonnements'],
      ['9', 'FAQ'],
      ['10', 'Support'],
    ];

    return pw.Page(
      margin: const pw.EdgeInsets.fromLTRB(40, 50, 40, 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sommaire',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 3, width: 60, color: _accent),
          pw.SizedBox(height: 30),
          ...entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 28,
                    height: 28,
                    decoration: pw.BoxDecoration(
                      color: _primary,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      e[0],
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Text(
                      e[1],
                      style: pw.TextStyle(
                        fontSize: 15,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Widgets de contenu réutilisables
  // ============================================================

  static pw.Widget _h1(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 3, width: 40, color: _accent),
          ],
        ),
      );

  static pw.Widget _h2(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
      );

  static pw.Widget _h3(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      );

  static pw.Widget _p(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 11,
            lineSpacing: 2,
            color: PdfColors.grey900,
          ),
          textAlign: pw.TextAlign.justify,
        ),
      );

  static pw.Widget _bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 4,
              height: 4,
              margin: const pw.EdgeInsets.only(top: 5, right: 8),
              decoration: const pw.BoxDecoration(
                color: _accent,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 11,
                  lineSpacing: 2,
                  color: PdfColors.grey900,
                ),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _bullets(List<String> items) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items.map(_bullet).toList(),
        ),
      );

  /// Encadré coloré : info (bleu), tip (vert), warn (orange).
  static pw.Widget _box(String text,
      {required _BoxKind kind, String? title}) {
    final PdfColor bg;
    final PdfColor border;
    final String prefix;
    switch (kind) {
      case _BoxKind.info:
        bg = _bgNote;
        border = _borderNote;
        prefix = 'i';
        break;
      case _BoxKind.tip:
        bg = _bgTip;
        border = _borderTip;
        prefix = '+';
        break;
      case _BoxKind.warn:
        bg = _bgWarn;
        border = _borderWarn;
        prefix = '!';
        break;
    }
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 18,
            height: 18,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: border,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Text(
              prefix,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                ],
                pw.Text(
                  text,
                  style: pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Contenu des sections
  // ============================================================

  static List<pw.Widget> _buildIntroduction() => [
        _h1('1. Introduction'),
        _p(
          'Bienvenue dans le manuel utilisateur de ${AppConstants.appName}, '
          'une application complète de gestion de boutique pensée pour les '
          'commerces multi-points de vente. Elle vous permet de gérer vos '
          'produits, vos ventes, vos clients, vos fournisseurs et vos '
          'approvisionnements depuis votre téléphone, en mode connecté.',
        ),
        _h2('Pour qui ?'),
        _p(
          'L\'application est conçue pour trois profils d\'utilisateurs '
          'qui collaborent autour des mêmes données :',
        ),
        _bullets([
          'Super-administrateur : gère la plateforme dans son ensemble — '
              'crée les boutiques, leurs administrateurs, configure les '
              'tarifs d\'abonnement et suit les paiements.',
          'Administrateur de boutique : gère le catalogue (produits, '
              'catégories, stock), supervise les gestionnaires et consulte '
              'les rapports. Peut être affecté à plusieurs boutiques.',
          'Gestionnaire (vendeur) : tient la caisse au quotidien — '
              'enregistre les ventes, encaisse les règlements, crée les '
              'clients, suit les approvisionnements.',
        ]),
        _h2('Concepts clés'),
        _bullets([
          'Une boutique = un espace de gestion indépendant (catalogue, '
              'stock, ventes, clients, comptes utilisateurs).',
          'Un utilisateur a un rôle (super-admin / admin / gestionnaire) et '
              'peut être lié à une ou plusieurs boutiques.',
          'Chaque boutique a un abonnement payant qui doit être renouvelé '
              'pour conserver l\'accès à l\'application.',
          'Tous les paiements et opérations sont enregistrés avec date et '
              'auteur pour une traçabilité complète.',
        ]),
        _box(
          'L\'application fonctionne uniquement avec une connexion internet. '
          'Les données sont synchronisées en temps réel : toute opération '
          'effectuée sur un appareil est visible immédiatement sur les autres.',
          kind: _BoxKind.info,
          title: 'Connexion requise',
        ),
      ];

  static List<pw.Widget> _buildPremierAcces() => [
        _h1('2. Premier accès'),
        _h2('Installation'),
        _bullets([
          'Téléchargez ${AppConstants.appName} depuis le Google Play Store '
              '(Android) ou l\'App Store (iOS) en cherchant le nom officiel '
              'de l\'application.',
          'Ouvrez l\'app après installation. L\'écran de connexion s\'affiche.',
        ]),
        _h2('Création du compte'),
        _p(
          'Aucun compte ne peut être créé librement depuis l\'app. Tous les '
          'comptes sont créés par votre super-administrateur ou par '
          'l\'administrateur de votre boutique. Vous recevrez un email '
          'avec un lien pour définir votre mot de passe initial.',
        ),
        _box(
          'Si vous n\'avez pas reçu l\'email, vérifiez votre dossier spam '
          'puis contactez le support.',
          kind: _BoxKind.tip,
          title: 'Email non reçu',
        ),
        _h2('Première connexion'),
        _p('Entrez votre identifiant (email ou numéro de téléphone) et '
            'votre mot de passe, puis tapez "Se connecter".'),
        _bullets([
          'Connexion par email : l\'email exact que vous avez communiqué.',
          'Connexion par téléphone : le numéro avec préfixe pays '
              '(ex. +224621785645).',
          'Mot de passe oublié : tapez sur "Mot de passe oublié ?" pour '
              'recevoir un lien de réinitialisation par email.',
        ]),
        _h2('Sécurité du compte'),
        _bullets([
          'Choisissez un mot de passe d\'au moins 6 caractères, mélangeant '
              'lettres, chiffres et symboles.',
          'Ne partagez jamais votre mot de passe — chaque action est tracée '
              'à votre compte.',
          'Vous pouvez modifier votre mot de passe à tout moment depuis le '
              'drawer > "Mon compte" > "Changer mon mot de passe".',
        ]),
      ];

  static List<pw.Widget> _buildNavigation() => [
        _h1('3. Navigation & concepts'),
        _h2('Le drawer (menu latéral)'),
        _p(
          'Le menu principal est accessible en tapant sur l\'icône en haut '
          'à gauche (trois lignes horizontales). Il regroupe toutes les '
          'sections de l\'application selon votre rôle.',
        ),
        _bullets([
          'Tableau de bord : aperçu rapide des chiffres du jour.',
          'Catalogue : produits, catégories, stock.',
          'Achats : fournisseurs, approvisionnements, règlements fournisseurs.',
          'Ventes & règlements : ventes, clients, encaissements.',
          'Rapports : statistiques sur la période choisie.',
          'Abonnements : statut d\'abonnement de la boutique.',
          'Paramètres : préférences personnelles.',
          'À propos : informations sur l\'application.',
        ]),
        _h2('L\'en-tête du drawer'),
        _p(
          'Affiche votre nom, email et rôle. Tapez dessus pour accéder à '
          'votre profil ("Mon compte"). Pour les administrateurs ayant '
          'accès à plusieurs boutiques, un sélecteur de boutique active '
          'apparaît juste en dessous.',
        ),
        _h2('Recherche'),
        _p(
          'La plupart des listes (produits, clients, ventes, etc.) disposent '
          'd\'un champ de recherche en haut. Tapez quelques caractères pour '
          'filtrer instantanément.',
        ),
        _h2('Filtres'),
        _p(
          'Sur les listes complexes (ventes, règlements, etc.), un filtre '
          'permet de restreindre par période (jour, semaine, mois, '
          'personnalisé), par boutique (pour super-admin) ou par utilisateur.',
        ),
        _h2('Mode sombre'),
        _p(
          'L\'application s\'adapte automatiquement au mode clair / sombre '
          'de votre téléphone. Vous pouvez forcer un mode dans les '
          'paramètres système ou via le bouton dédié dans l\'app.',
        ),
        _h2('Reçus PDF'),
        _p(
          'Tous les reçus (ventes, approvisionnements, règlements) peuvent '
          'être prévisualisés, imprimés, partagés (WhatsApp, mail) ou '
          'enregistrés directement depuis l\'app.',
        ),
      ];

  static List<pw.Widget> _buildSuperAdmin() => [
        _h1('4. Guide super-administrateur'),
        _p(
          'Le super-administrateur a un accès complet à toutes les '
          'fonctionnalités de la plateforme, sans restriction. Il supervise '
          'toutes les boutiques et leurs utilisateurs.',
        ),
        _h2('4.1 Gérer les boutiques'),
        _p('Drawer > "Boutiques". Liste de toutes les boutiques inscrites.'),
        _bullets([
          'Créer une boutique : bouton "+ Nouvelle boutique". Renseignez '
              'nom, devise (GNF, FCFA, EUR…), adresse, téléphone.',
          'Modifier : tapez sur une boutique pour l\'éditer.',
          'Désactiver : interrupteur "Actif". Une boutique désactivée '
              'devient inaccessible à ses utilisateurs.',
          'Supprimer : suppression définitive de la boutique ET de tout '
              'son contenu (produits, ventes, clients...). Action '
              'irréversible.',
        ]),
        _box(
          'La suppression d\'une boutique est définitive. Toutes les '
          'données (produits, ventes, historique) sont effacées. '
          'Privilégiez la désactivation pour conserver l\'historique.',
          kind: _BoxKind.warn,
          title: 'Action irréversible',
        ),
        _h2('4.2 Gérer les utilisateurs'),
        _p('Drawer > "Utilisateurs". Liste de tous les utilisateurs.'),
        _bullets([
          'Créer un utilisateur : "+ Nouvel utilisateur". Choisissez le '
              'rôle (administrateur ou gestionnaire) et la boutique '
              'd\'affectation.',
          'Pour un administrateur multi-boutique : sélectionnez la '
              'boutique principale puis les boutiques additionnelles via '
              'les chips ci-dessous.',
          'Cumul admin + gestionnaire : pour un admin qui doit aussi tenir '
              'la caisse, activez l\'interrupteur "Aussi gestionnaire".',
          'Désactiver / supprimer un utilisateur : ses sessions actives '
              'sont fermées immédiatement.',
        ]),
        _h2('4.3 Configurer les abonnements'),
        _p('Drawer > "Abonnements" > icône paramètres (engrenage).'),
        _bullets([
          'Tarifs par devise et par période (mensuel, trimestriel, '
              'semestriel, annuel) — pré-remplissent automatiquement le '
              'formulaire de paiement.',
          'Période de grâce : nombre de jours après expiration pendant '
              'lesquels la boutique reste accessible (avec bandeau '
              'd\'alerte). Au-delà, l\'accès est refusé.',
          'Délai d\'alerte : nombre de jours avant expiration à partir '
              'desquels les admins reçoivent une notification.',
        ]),
        _h2('4.4 Enregistrer un paiement d\'abonnement'),
        _p('Drawer > "Abonnements" > tapez sur une boutique.'),
        _bullets([
          'La fiche pré-remplit les valeurs du dernier paiement (période, '
              'montant, note).',
          'Modifiez si nécessaire, puis tapez "Enregistrer le paiement".',
          'L\'historique de la boutique apparaît en bas, avec les boutons '
              'Modifier / Supprimer sur chaque ligne.',
          'Modifier ou supprimer un paiement recalcule automatiquement la '
              'date de fin d\'abonnement de la boutique.',
        ]),
        _box(
          'Le montant 0 est autorisé (paiement offert / geste commercial).',
          kind: _BoxKind.tip,
        ),
        _h2('4.5 Rapports globaux'),
        _p('Drawer > "Rapports".'),
        _bullets([
          'Pour le super-admin, un filtre boutique permet de comparer ou '
              'd\'agréger les chiffres entre boutiques.',
          'KPIs : chiffre d\'affaires, ventes, articles vendus, ticket '
              'moyen, par période.',
          'Top produits, top clients, top fournisseurs, modes de paiement.',
          'Exports PDF disponibles.',
        ]),
        _h2('4.6 Filtres par boutique (partout)'),
        _p(
          'En tant que super-admin, vous voyez par défaut les données de '
          'toutes les boutiques. Un filtre "Boutique" est disponible sur :',
        ),
        _bullets([
          'Ventes, règlements, règlements fournisseurs, approvisionnements',
          'Produits, catégories, stock, historique des mouvements',
          'Clients, fournisseurs, utilisateurs',
          'Rapports',
        ]),
        _h2('4.7 Mise à jour forcée'),
        _p(
          'Drawer > "Paramètres" > "Mise à jour forcée". Si vous publiez '
          'une nouvelle version sur les stores, indiquez ici la version '
          'minimale acceptée. Au prochain lancement de l\'app, les '
          'utilisateurs sur une version antérieure verront un popup '
          'non-dismissible les invitant à mettre à jour.',
        ),
      ];

  static List<pw.Widget> _buildAdmin() => [
        _h1('5. Guide administrateur'),
        _p(
          'L\'administrateur gère sa boutique au quotidien : catalogue, '
          'gestionnaires, contrôle des opérations. S\'il est affecté à '
          'plusieurs boutiques, il peut basculer entre elles via le drawer.',
        ),
        _h2('5.1 Tableau de bord'),
        _p(
          'Aperçu de l\'activité : ventes du jour, du mois, évolution du CA, '
          'top produits, modes de paiement. Le badge d\'abonnement affiche '
          'la date de fin et le nombre de jours restants. Si la fin '
          'approche, un bandeau d\'alerte s\'affiche.',
        ),
        _h2('5.2 Gérer le catalogue'),
        _h3('Catégories'),
        _bullets([
          'Drawer > "Catalogue" > "Catégories".',
          'Créez les catégories qui structurent vos produits (Boissons, '
              'Alimentaire, Cosmétiques, …).',
          'Une catégorie peut être supprimée tant qu\'aucun produit ne '
              's\'y rattache.',
        ]),
        _h3('Produits'),
        _bullets([
          'Drawer > "Catalogue" > "Produits".',
          'Champs requis : nom, catégorie, prix de vente, prix d\'achat.',
          'Le prix d\'achat sera ensuite calculé automatiquement à chaque '
              'approvisionnement via la formule du Coût Moyen Unitaire '
              'Pondéré (CMUP).',
          'Variantes : si votre produit a plusieurs déclinaisons (taille, '
              'couleur), activez l\'interrupteur "Avec variantes". Chaque '
              'variante a son propre stock.',
          'Seuil d\'alerte : nombre en dessous duquel le produit apparaît '
              'comme "Stock bas".',
        ]),
        _box(
          'Une fois qu\'un approvisionnement est passé sur un produit, '
          'le prix d\'achat se verrouille — il est désormais calculé '
          'automatiquement (CMUP) pour préserver la cohérence du stock.',
          kind: _BoxKind.info,
          title: 'Verrou CMUP',
        ),
        _h3('Stock'),
        _bullets([
          'Drawer > "Catalogue" > "Stock".',
          'Vue d\'ensemble de tous les produits avec leur quantité, statut '
              '(rupture / stock bas / OK) et valeur.',
          'Filtres : catégorie, état du stock, recherche.',
          'Pour saisir un mouvement manuel (entrée, sortie, ajustement, '
              'perte), tapez "+ Nouveau mouvement". Tous les mouvements '
              'sont tracés dans l\'historique.',
        ]),
        _h2('5.3 Gérer les gestionnaires'),
        _bullets([
          'Drawer > "Mes gestionnaires" (admin) ou "Utilisateurs" (super-admin).',
          'Créer : "+ Nouvel utilisateur". Rôle = gestionnaire. Boutique '
              'sera automatiquement la vôtre.',
          'Activer / désactiver via l\'interrupteur "Compte actif". Un '
              'gestionnaire désactivé ne peut plus se connecter.',
          'Renvoyer le mail de définition du mot de passe via le menu '
              'd\'options.',
        ]),
        _h2('5.4 Suivre les ventes'),
        _p(
          'En tant qu\'administrateur pur (sans cumul gestionnaire), vous '
          'consultez les ventes en lecture seule. Vous pouvez filtrer par '
          'période, gestionnaire, mode de paiement, etc.',
        ),
        _h2('5.5 Activer "Aussi gestionnaire"'),
        _p(
          'Drawer > "Mon compte" > interrupteur "Aussi gestionnaire". '
          'Vous obtenez alors tous les droits de la caisse en plus de vos '
          'droits administrateur : créer des ventes, encaisser, gérer '
          'clients et fournisseurs.',
        ),
        _h2('5.6 Rapports'),
        _p(
          'Drawer > "Rapports". Filtres par période et par gestionnaire. '
          'KPIs, top produits, évolution du CA.',
        ),
      ];

  static List<pw.Widget> _buildGestionnaire() => [
        _h1('6. Guide gestionnaire'),
        _p(
          'Le gestionnaire (vendeur) est en charge des opérations '
          'quotidiennes de la caisse. Il ne modifie pas le catalogue ; il '
          'enregistre les ventes et règlements.',
        ),
        _h2('6.1 Tableau de bord'),
        _p(
          'Affiche en temps réel le nombre de ventes du jour, le chiffre '
          'd\'affaires, et un bouton flottant "Vendre" pour démarrer une '
          'nouvelle vente.',
        ),
        _h2('6.2 Enregistrer une vente'),
        _bullets([
          'Tapez le bouton "+ Vendre" (FAB vert) sur le tableau de bord '
              'ou la liste des ventes.',
          'Ajoutez des articles : tapez sur la catégorie puis sur le '
              'produit. Pour un produit à variantes, choisissez la '
              'variante (taille, couleur).',
          'Vous pouvez modifier la quantité ou le prix unitaire d\'une '
              'ligne en tapant dessus.',
          'Appliquez une remise globale si besoin.',
          'Sélectionnez le client (existant) ou tapez "Client divers".',
          'Choisissez le mode de paiement : espèces, mobile money, '
              'crédit, etc.',
          'Si le client ne paie qu\'une partie, le reste passe en crédit '
              '(à recevoir).',
          'Tapez "Valider la vente". Un reçu PDF est généré et peut être '
              'partagé immédiatement.',
        ]),
        _box(
          'Une vente validée ne peut plus être modifiée. Seule '
          'l\'annulation est possible (depuis le détail de la vente), '
          'avec un motif obligatoire. Le stock est alors restitué.',
          kind: _BoxKind.warn,
          title: 'Vente immuable',
        ),
        _h2('6.3 Encaisser un règlement client'),
        _bullets([
          'Drawer > "Règlements clients" > bouton "Encaisser".',
          'Choisissez le client. Son solde à recevoir s\'affiche.',
          'Saisissez le montant encaissé et le mode de paiement.',
          'Le règlement est imputé automatiquement sur les ventes les '
              'plus anciennes (FIFO).',
        ]),
        _h2('6.4 Gérer les clients'),
        _bullets([
          'Drawer > "Clients". Liste avec solde de chaque client.',
          '"+ Nouveau client" pour ajouter un contact : nom, téléphone, '
              'adresse, note.',
          'Tapez sur un client pour voir son historique : ventes, '
              'règlements, solde courant.',
        ]),
        _h2('6.5 Approvisionnements'),
        _bullets([
          'Drawer > "Achats" > "Approvisionnements" > "+ Nouvel appro".',
          'Choisissez le fournisseur, ajoutez les articles reçus avec leur '
              'prix d\'achat unitaire.',
          'Le stock se met à jour automatiquement et le CMUP des produits '
              'est recalculé.',
          'Réglez tout ou partie du fournisseur. Le reste est en dette '
              '(à payer).',
        ]),
        _h2('6.6 Règlements fournisseurs'),
        _p('Drawer > "Règlements fournisseurs" > "Verser".'),
        _p(
          'Symétrique aux règlements clients : choisissez le fournisseur, '
          'saisissez le montant versé, le mode. Imputation FIFO sur les '
          'approvisionnements les plus anciens.',
        ),
        _h2('6.7 Annuler une vente'),
        _p(
          'Ouvrez le détail de la vente (depuis la liste). Tapez sur '
          '"Annuler la vente", saisissez un motif. Le stock est restitué, '
          'la vente passe en statut "Annulée" mais reste dans l\'historique '
          'pour audit.',
        ),
      ];

  static List<pw.Widget> _buildMultiBoutique() => [
        _h1('7. Multi-boutique'),
        _p(
          'Un administrateur peut être affecté à plusieurs boutiques par '
          'le super-administrateur (boutique principale + boutiques '
          'additionnelles). Il bascule entre elles via le drawer.',
        ),
        _h2('7.1 Le switcher dans le drawer'),
        _bullets([
          'En haut du drawer, sous votre nom, un bandeau cliquable affiche '
              'la boutique active courante.',
          'Tapez dessus pour ouvrir la liste de toutes vos boutiques '
              'accessibles.',
          'Choisissez une boutique : l\'application bascule entièrement '
              'sur cette boutique (produits, ventes, clients… tout est '
              'scopé).',
        ]),
        _h2('7.2 Boutiques inaccessibles'),
        _p(
          'Une boutique apparaît dans la liste mais son switch est bloqué '
          'si :',
        ),
        _bullets([
          'Elle est désactivée par le super-admin.',
          'Elle n\'a aucun abonnement actif.',
          'Son abonnement est expiré (au-delà de la période de grâce).',
        ]),
        _h2('7.3 Conséquences du switch'),
        _bullets([
          'Toutes les listes (produits, ventes, clients, …) sont filtrées '
              'sur la boutique active.',
          'Toute nouvelle action (création produit, vente, etc.) est '
              'enregistrée sur la boutique active.',
          'Vous êtes redirigé sur le tableau de bord après le switch pour '
              'éviter toute confusion.',
        ]),
        _box(
          'Si votre boutique active devient indisponible (désactivation / '
          'expiration), vous êtes déconnecté. Au re-login, vous serez '
          'automatiquement redirigé vers la première de vos boutiques '
          'restée fonctionnelle.',
          kind: _BoxKind.info,
          title: 'Auto-redirection',
        ),
      ];

  static List<pw.Widget> _buildAbonnements() => [
        _h1('8. Abonnements'),
        _h2('8.1 Principe'),
        _p(
          'Chaque boutique dispose d\'un abonnement payant qui doit être '
          'renouvelé périodiquement. Les périodes disponibles sont : '
          'mensuel, trimestriel, semestriel, annuel.',
        ),
        _h2('8.2 Suivre votre abonnement'),
        _p(
          'En tant qu\'administrateur : Drawer > "Mon abonnement". '
          'Affiche le statut courant et l\'historique complet des paiements.',
        ),
        _h2('8.3 Période de grâce'),
        _p(
          'À l\'expiration de l\'abonnement, une période de grâce '
          '(configurable par le super-admin) permet de continuer à '
          'utiliser l\'app avec un bandeau d\'alerte. Au-delà, l\'accès '
          'est bloqué jusqu\'à enregistrement d\'un nouveau paiement.',
        ),
        _h2('8.4 Alerte avant expiration'),
        _p(
          'Un délai d\'alerte (configurable, généralement 7 jours) '
          'déclenche un snackbar à la connexion ainsi qu\'un bandeau '
          'permanent sur le tableau de bord, pour vous rappeler de '
          'renouveler.',
        ),
        _h2('8.5 Renouvellement'),
        _p(
          'Contactez votre super-administrateur ou le support pour '
          'enregistrer un nouveau paiement. La nouvelle période s\'ajoute '
          'à la fin courante (cumul, pas de perte de jours en cas de '
          'paiement anticipé).',
        ),
        _box(
          'Le super-administrateur peut accorder un paiement à 0 (geste '
          'commercial, période offerte).',
          kind: _BoxKind.tip,
        ),
      ];

  static List<pw.Widget> _buildFaq() => [
        _h1('9. FAQ'),
        _h3('Comment se connecter avec un numéro de téléphone ?'),
        _p(
          'Saisissez votre numéro complet avec préfixe pays '
          '(ex. +224621785645) dans le champ "Identifiant", puis votre '
          'mot de passe habituel. L\'app résoudra automatiquement votre '
          'compte.',
        ),
        _h3('J\'ai oublié mon mot de passe.'),
        _p(
          'Tapez "Mot de passe oublié ?" sur l\'écran de connexion. Un '
          'email de réinitialisation est envoyé à l\'adresse de votre '
          'compte. Suivez le lien pour choisir un nouveau mot de passe.',
        ),
        _h3('Pourquoi je ne peux pas modifier le prix d\'achat d\'un produit ?'),
        _p(
          'Dès qu\'un approvisionnement a été enregistré sur ce produit, '
          'le prix d\'achat se transforme en Coût Moyen Unitaire Pondéré '
          '(CMUP) qui est calculé automatiquement. Cela garantit la '
          'cohérence de la valorisation du stock.',
        ),
        _h3('Comment ajouter une variante à un produit existant ?'),
        _p(
          'Ouvrez le produit, activez l\'interrupteur "Avec variantes". '
          'Note : ce passage n\'est possible que si le stock du produit '
          'est à 0 (pour éviter d\'avoir un stock orphelin sans '
          'rattachement à une variante).',
        ),
        _h3('Je suis admin de plusieurs boutiques, comment basculer ?'),
        _p(
          'Ouvrez le drawer. Sous votre nom apparaît un bandeau de '
          'sélection de boutique. Tapez dessus, choisissez une boutique '
          'de la liste. L\'application bascule entièrement.',
        ),
        _h3('Une vente est-elle modifiable après validation ?'),
        _p(
          'Non. Une vente est immuable pour des raisons d\'audit. Vous '
          'pouvez en revanche :',
        ),
        _bullets([
          'Annuler la vente (depuis le détail) > restitution du stock + '
              'inscription d\'un motif.',
          'Enregistrer un règlement client supplémentaire pour solder une '
              'vente partiellement payée.',
        ]),
        _h3('Comment supprimer un client ou un fournisseur ?'),
        _p(
          'Possible UNIQUEMENT si aucune opération n\'a jamais été '
          'enregistrée sur ce client / fournisseur. Sinon, conservez-le '
          'pour préserver l\'historique. Vous pouvez le marquer comme '
          'inactif si vous souhaitez le retirer des listes courantes.',
        ),
        _h3('Comment exporter un rapport ?'),
        _p(
          'Sur la page Rapports, tapez sur l\'icône de partage. L\'app '
          'génère un PDF de la période courante avec les filtres actifs.',
        ),
        _h3('Pourquoi l\'app me redirige vers une autre boutique ?'),
        _p(
          'Cela arrive quand votre boutique active devient indisponible '
          '(désactivation par le super-admin, expiration d\'abonnement). '
          'Pour ne pas vous bloquer, l\'app vous bascule automatiquement '
          'sur une boutique restée fonctionnelle.',
        ),
        _h3('L\'app me dit "Mise à jour requise" — pourquoi ?'),
        _p(
          'Le super-admin a publié une nouvelle version obligatoire (par '
          'exemple pour un correctif important). Tapez "Mettre à jour" et '
          'installez la nouvelle version depuis le store.',
        ),
      ];

  static List<pw.Widget> _buildSupport() => [
        _h1('10. Support'),
        _p(
          'Pour toute question, demande d\'évolution ou problème technique, '
          'contactez le support :',
        ),
        _h2('Comment contacter le support'),
        _bullets([
          'Depuis l\'app : drawer > "À propos" > tapez sur le numéro de '
              'téléphone (lance un appel direct) ou sur l\'email (ouvre '
              'votre client mail).',
          'Décrivez précisément votre problème : étapes pour le '
              'reproduire, capture d\'écran si possible, version de l\'app.',
        ]),
        _h2('Avant de contacter'),
        _bullets([
          'Vérifiez votre connexion internet (l\'app a besoin du réseau).',
          'Forcez la fermeture de l\'app puis rouvrez-la.',
          'Vérifiez que vous êtes sur la dernière version disponible sur '
              'le store.',
          'Consultez la section FAQ ci-dessus.',
        ]),
        _h2('Informations utiles à transmettre'),
        _bullets([
          'Votre adresse email de connexion.',
          'Le nom de votre boutique.',
          'La version de l\'app (visible dans le drawer > "À propos").',
          'Le système (Android / iOS) et sa version.',
        ]),
        _box(
          'Le support ne vous demandera JAMAIS votre mot de passe. En cas '
          'de doute sur un message ou un email, contactez directement le '
          'support par téléphone.',
          kind: _BoxKind.warn,
          title: 'Sécurité',
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Merci d\'utiliser ${AppConstants.appName} !',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Ce manuel est mis à jour régulièrement. Vous pouvez le '
                'régénérer à tout moment depuis le menu de l\'application.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
      ];
}

enum _BoxKind { info, tip, warn }
