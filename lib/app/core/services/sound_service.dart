import 'package:audioplayers/audioplayers.dart';

/// Sons courts de l'application (assets/sounds/).
///
/// Le lecteur est un singleton : on évite d'instancier un `AudioPlayer`
/// par lecture, ce qui laisserait des ressources natives ouvertes.
///
/// Toutes les méthodes sont **best-effort** : un son est un agrément, son
/// échec (appareil en silencieux, canal audio occupé, codec indisponible)
/// ne doit jamais interrompre le parcours utilisateur.
class SoundService {
  SoundService._();

  static final AudioPlayer _player = AudioPlayer();

  /// Son joué à l'arrivée sur l'écran d'accueil après une connexion
  /// réussie (mot de passe comme biométrie).
  static Future<void> playLoginSuccess() => _play('sounds/sound.mp3');

  static Future<void> _play(String assetPath) async {
    try {
      // stop() avant play() : si le son précédent tourne encore, on
      // repart du début plutôt que de superposer deux lectures.
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Silencieux volontairement — voir la doc de la classe.
    }
  }
}
