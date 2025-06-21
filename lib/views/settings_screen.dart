import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../cubits/settings_cubit.dart';
import '../models/user_settings.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load user settings when screen opens
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      context.read<SettingsCubit>().loadUserSettings(currentUser.uid);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'اللعبة'),
            Tab(icon: Icon(Icons.person), text: 'الحساب'),
            Tab(icon: Icon(Icons.volume_up), text: 'الصوت'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGameSettings(),
            _buildAccountSettings(),
            _buildAudioSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameSettings() {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state is SettingsLoaded) {
          final settings = state.settings;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('إعدادات اللعبة العامة'),
                _buildSwitchTile(
                  'تخطي المراحل تلقائياً',
                  'تخطي المراحل عند انتهاء الوقت',
                  settings.autoSkipPhase,
                  (value) => context.read<SettingsCubit>().toggleAutoSkipPhase(),
                ),
                _buildSwitchTile(
                  'إظهار الدور بعد الموت',
                  'إظهار دور اللاعب بعد إقصائه',
                  settings.showRoleAfterDeath,
                  (value) => context.read<SettingsCubit>().toggleShowRoleAfterDeath(),
                ),
                _buildSwitchTile(
                  'إظهار المؤقت',
                  'إظهار مؤقت المرحلة',
                  settings.showTimer,
                  (value) => context.read<SettingsCubit>().toggleShowTimer(),
                ),
                _buildSwitchTile(
                  'إظهار الأدلة',
                  'إظهار أدلة القضية',
                  settings.showClues,
                  (value) => context.read<SettingsCubit>().toggleShowClues(),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('مدة النقاش الافتراضية'),
                _buildDurationSelector(settings.defaultDiscussionDuration),
                const SizedBox(height: 20),
                _buildSectionHeader('المظهر'),
                _buildThemeSelector(settings.theme),
                const SizedBox(height: 20),
                _buildSectionHeader('اللغة'),
                _buildLanguageSelector(settings.language),
              ],
            ),
          );
        }
        
        return const Center(child: Text('لا توجد إعدادات متاحة'));
      },
    );
  }

  Widget _buildAccountSettings() {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state is SettingsLoaded) {
          final settings = state.settings;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('معلومات الحساب'),
                _buildInfoCard('اسم المستخدم', settings.username),
                _buildInfoCard('البريد الإلكتروني', settings.email),
                _buildInfoCard('الألعاب الملعوبة', settings.gamesPlayed.toString()),
                _buildInfoCard('الألعاب المربوحة', settings.gamesWon.toString()),
                _buildInfoCard('النقاط الإجمالية', settings.totalScore.toString()),
                const SizedBox(height: 20),
                _buildSectionHeader('إعدادات الإشعارات'),
                _buildSwitchTile(
                  'إشعارات البريد الإلكتروني',
                  'استلام إشعارات عبر البريد الإلكتروني',
                  settings.emailNotifications,
                  (value) => context.read<SettingsCubit>().updateUserSettings(
                    settings.copyWith(emailNotifications: value),
                  ),
                ),
                _buildSwitchTile(
                  'إشعارات التطبيق',
                  'استلام إشعارات في التطبيق',
                  settings.pushNotifications,
                  (value) => context.read<SettingsCubit>().updateUserSettings(
                    settings.copyWith(pushNotifications: value),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('الخصوصية'),
                _buildSwitchTile(
                  'إظهار حالة الاتصال',
                  'إظهار أنك متصل للآخرين',
                  settings.showOnlineStatus,
                  (value) => context.read<SettingsCubit>().updateUserSettings(
                    settings.copyWith(showOnlineStatus: value),
                  ),
                ),
                _buildSwitchTile(
                  'السماح بطلبات الصداقة',
                  'السماح للآخرين بإرسال طلبات صداقة',
                  settings.allowFriendRequests,
                  (value) => context.read<SettingsCubit>().updateUserSettings(
                    settings.copyWith(allowFriendRequests: value),
                  ),
                ),
              ],
            ),
          );
        }
        
        return const Center(child: Text('لا توجد إعدادات متاحة'));
      },
    );
  }

  Widget _buildAudioSettings() {
    final audioService = AudioService();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('إعدادات الموسيقى'),
          _buildSwitchTile(
            'تفعيل الموسيقى',
            'تشغيل موسيقى الخلفية',
            audioService.isMusicEnabled,
            (value) async {
              await audioService.setMusicEnabled(value);
              setState(() {});
            },
          ),
          if (audioService.isMusicEnabled) ...[
            const SizedBox(height: 10),
            _buildVolumeSlider(
              'مستوى الموسيقى',
              audioService.musicVolume,
              (value) async {
                await audioService.setMusicVolume(value);
                setState(() {});
              },
            ),
          ],
          const SizedBox(height: 20),
          _buildSectionHeader('إعدادات الأصوات'),
          _buildSwitchTile(
            'تفعيل الأصوات',
            'تشغيل أصوات التأثيرات',
            audioService.isSfxEnabled,
            (value) async {
              await audioService.setSfxEnabled(value);
              setState(() {});
            },
          ),
          if (audioService.isSfxEnabled) ...[
            const SizedBox(height: 10),
            _buildVolumeSlider(
              'مستوى الأصوات',
              audioService.sfxVolume,
              (value) async {
                await audioService.setSfxVolume(value);
                setState(() {});
              },
            ),
          ],
          const SizedBox(height: 20),
          _buildSectionHeader('اختبار الأصوات'),
          _buildTestButtons(audioService),
        ],
      ),
    );
  }

  Widget _buildTestButtons(AudioService audioService) {
    return Card(
      color: Colors.blueGrey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختبار الأصوات', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton('صوت الزر', () => audioService.playButtonClick()),
                _buildTestButton('صوت البطاقة', () => audioService.playCardFlip()),
                _buildTestButton('صوت الإقصاء', () => audioService.playPlayerEliminated()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Card(
      color: Colors.blueGrey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepPurple[300],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      color: Colors.blueGrey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Text(value, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVolumeSlider(String title, double value, Function(double) onChanged) {
    return Card(
      color: Colors.blueGrey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white)),
            Slider(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.deepPurple[300],
              inactiveColor: Colors.grey[600],
            ),
            Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector(int currentDuration) {
    final durations = [
      {'label': '2 دقائق', 'value': 120},
      {'label': '4 دقائق', 'value': 240},
      {'label': '6 دقائق', 'value': 360},
    ];

    return Card(
      color: Colors.blueGrey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر مدة النقاش الافتراضية', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: durations.map((duration) {
                final isSelected = currentDuration == duration['value'];
                return ChoiceChip(
                  label: Text(duration['label'] as String),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple[300],
                  backgroundColor: Colors.grey[700],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      context.read<SettingsCubit>().setDefaultDiscussionDuration(duration['value'] as int);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(String currentTheme) {
    final themes = [
      {'label': 'داكن', 'value': 'dark'},
      {'label': 'فاتح', 'value': 'light'},
      {'label': 'تلقائي', 'value': 'auto'},
    ];

    return Card(
      color: Colors.blueGrey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر المظهر', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: themes.map((theme) {
                final isSelected = currentTheme == theme['value'];
                return ChoiceChip(
                  label: Text(theme['label'] as String),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple[300],
                  backgroundColor: Colors.grey[700],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      context.read<SettingsCubit>().setTheme(theme['value'] as String);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(String currentLanguage) {
    final languages = [
      {'label': 'العربية', 'value': 'ar'},
      {'label': 'English', 'value': 'en'},
    ];

    return Card(
      color: Colors.blueGrey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر اللغة', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: languages.map((language) {
                final isSelected = currentLanguage == language['value'];
                return ChoiceChip(
                  label: Text(language['label'] as String),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple[300],
                  backgroundColor: Colors.grey[700],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      context.read<SettingsCubit>().setLanguage(language['value'] as String);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
} 