import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_settings.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  UserSettings? _currentSettings;

  SettingsCubit() : super(SettingsInitial());

  UserSettings? get currentSettings => _currentSettings;

  Future<void> loadUserSettings(String userId) async {
    emit(SettingsLoading());
    try {
      final snapshot = await _database.child('users').child(userId).child('settings').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _currentSettings = UserSettings.fromJson(data);
        emit(SettingsLoaded(_currentSettings!));
      } else {
        // Create default settings if none exist
        _currentSettings = UserSettings(
          userId: userId,
          username: '',
          email: '',
        );
        await saveUserSettings(_currentSettings!);
        emit(SettingsLoaded(_currentSettings!));
      }
    } catch (e) {
      emit(SettingsError('فشل في تحميل الإعدادات: $e'));
    }
  }

  Future<void> saveUserSettings(UserSettings settings) async {
    emit(SettingsLoading());
    try {
      await _database.child('users').child(settings.userId).child('settings').set(settings.toJson());
      _currentSettings = settings;
      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(SettingsError('فشل في حفظ الإعدادات: $e'));
    }
  }

  Future<void> updateUserSettings(UserSettings updatedSettings) async {
    if (_currentSettings == null) return;
    
    final newSettings = _currentSettings!.copyWith(
      soundEnabled: updatedSettings.soundEnabled,
      musicEnabled: updatedSettings.musicEnabled,
      soundVolume: updatedSettings.soundVolume,
      musicVolume: updatedSettings.musicVolume,
      vibrationEnabled: updatedSettings.vibrationEnabled,
      notificationsEnabled: updatedSettings.notificationsEnabled,
      language: updatedSettings.language,
      theme: updatedSettings.theme,
      defaultDiscussionDuration: updatedSettings.defaultDiscussionDuration,
      autoSkipPhase: updatedSettings.autoSkipPhase,
      showRoleAfterDeath: updatedSettings.showRoleAfterDeath,
      showTimer: updatedSettings.showTimer,
      showClues: updatedSettings.showClues,
      emailNotifications: updatedSettings.emailNotifications,
      pushNotifications: updatedSettings.pushNotifications,
      showOnlineStatus: updatedSettings.showOnlineStatus,
      allowFriendRequests: updatedSettings.allowFriendRequests,
      timezone: updatedSettings.timezone,
      dateFormat: updatedSettings.dateFormat,
      timeFormat: updatedSettings.timeFormat,
    );

    await saveUserSettings(newSettings);
  }

  Future<void> updateUserProfile(String userId, String username, String email, String avatar) async {
    if (_currentSettings == null) return;
    
    final newSettings = _currentSettings!.copyWith(
      userId: userId,
      username: username,
      email: email,
      avatar: avatar,
    );

    await saveUserSettings(newSettings);
  }

  Future<void> incrementGameStats({required String userId, required bool didWin}) async {
    // Ensure settings are loaded first. If not, load them.
    if (_currentSettings == null || _currentSettings!.userId != userId) {
      await loadUserSettings(userId);
    }
    
    // If settings are still null after trying to load, we cannot proceed.
    if (_currentSettings == null) {
      emit(SettingsError('لا يمكن تحديث الإحصائيات لأن إعدادات المستخدم غير متاحة.'));
      return;
    }

    final newGamesPlayed = _currentSettings!.gamesPlayed + 1;
    final newGamesWon = didWin ? _currentSettings!.gamesWon + 1 : _currentSettings!.gamesWon;
    final newTotalScore = didWin ? _currentSettings!.totalScore + 10 : _currentSettings!.totalScore + 1; // 10 points for a win, 1 for a loss

    final newSettings = _currentSettings!.copyWith(
      gamesPlayed: newGamesPlayed,
      gamesWon: newGamesWon,
      totalScore: newTotalScore,
    );

    await saveUserSettings(newSettings);
  }

  // Helper methods for specific settings
  Future<void> toggleSound() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(soundEnabled: !_currentSettings!.soundEnabled));
  }

  Future<void> toggleMusic() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(musicEnabled: !_currentSettings!.musicEnabled));
  }

  Future<void> setSoundVolume(double volume) async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(soundVolume: volume));
  }

  Future<void> setMusicVolume(double volume) async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(musicVolume: volume));
  }

  Future<void> toggleVibration() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(vibrationEnabled: !_currentSettings!.vibrationEnabled));
  }

  Future<void> toggleNotifications() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(notificationsEnabled: !_currentSettings!.notificationsEnabled));
  }

  Future<void> setTheme(String theme) async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(theme: theme));
  }

  Future<void> setLanguage(String language) async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(language: language));
  }

  Future<void> setDefaultDiscussionDuration(int duration) async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(defaultDiscussionDuration: duration));
  }

  Future<void> toggleAutoSkipPhase() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(autoSkipPhase: !_currentSettings!.autoSkipPhase));
  }

  Future<void> toggleShowRoleAfterDeath() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(showRoleAfterDeath: !_currentSettings!.showRoleAfterDeath));
  }

  Future<void> toggleShowTimer() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(showTimer: !_currentSettings!.showTimer));
  }

  Future<void> toggleShowClues() async {
    if (_currentSettings == null) return;
    await updateUserSettings(_currentSettings!.copyWith(showClues: !_currentSettings!.showClues));
  }
} 