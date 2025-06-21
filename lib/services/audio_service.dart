import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  bool _isMusicEnabled = true;
  bool _isSfxEnabled = true;
  double _musicVolume = 0.7;
  double _sfxVolume = 1.0;

  // Music tracks

  // Sound effects
  static const String buttonClick = 'assets/sounds/buttonclick.wav';
  static const String cardFlip = 'assets/sounds/cardflip.wav';
  static const String timerTick = 'assets/sounds/timer.wav';
  static const String playerEliminated = 'assets/sounds/eliminated.wav';
  static const String phaseTransition = 'assets/sounds/phase.wav';
  static const String reveal = 'assets/sounds/reveal.mp3';

  // Initialize audio settings
  Future<void> initialize() async {
    await _loadSettings();
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _musicVolume = prefs.getDouble('music_volume') ?? 0.7;
    _sfxVolume = prefs.getDouble('sfx_volume') ?? 1.0;
  }

  // Save settings
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _isMusicEnabled);
    await prefs.setBool('sfx_enabled', _isSfxEnabled);
    await prefs.setDouble('music_volume', _musicVolume);
    await prefs.setDouble('sfx_volume', _sfxVolume);
  }

  // Music controls
  Future<void> playMusic(String track) async {
    if (!_isMusicEnabled) return;
    
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.play(AssetSource(track));
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  Future<void> pauseMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    if (_isMusicEnabled) {
      await _musicPlayer.resume();
    }
  }

  // Sound effects
  Future<void> playSfx(String sound) async {
    if (!_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource(sound));
    } catch (e) {
      print('Error playing sound effect: $e');
    }
  }

  // Specific sound methods
  Future<void> playButtonClick() async => await playSfx(buttonClick);
  Future<void> playCardFlip() async => await playSfx(cardFlip);
  Future<void> playTimerTick() async => await playSfx(timerTick);
  Future<void> playPlayerEliminated() async => await playSfx(playerEliminated);
  Future<void> playPhaseTransition() async => await playSfx(phaseTransition);
  Future<void> playReveal() async => await playSfx(reveal);

  // Specific music methods

  // Settings getters and setters
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    if (!enabled) {
      await stopMusic();
    }
    await _saveSettings();
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _isSfxEnabled = enabled;
    await _saveSettings();
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    await _musicPlayer.setVolume(volume);
    await _saveSettings();
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume;
    await _saveSettings();
  }

  // Dispose
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }
} 