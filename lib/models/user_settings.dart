class UserSettings {
  final String userId;
  final String username;
  final String email;
  final String avatar;
  final int gamesPlayed;
  final int gamesWon;
  final int totalScore;
  
  // Game Settings
  final bool soundEnabled;
  final bool musicEnabled;
  final double soundVolume;
  final double musicVolume;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final String language;
  final String theme;
  final int defaultDiscussionDuration;
  final bool autoSkipPhase;
  final bool showRoleAfterDeath;
  final bool showTimer;
  final bool showClues;
  
  // Account Settings
  final bool emailNotifications;
  final bool pushNotifications;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
  final String timezone;
  final String dateFormat;
  final String timeFormat;

  UserSettings({
    required this.userId,
    required this.username,
    required this.email,
    this.avatar = '👤',
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalScore = 0,
    
    // Game Settings
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.soundVolume = 0.7,
    this.musicVolume = 0.5,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.language = 'ar',
    this.theme = 'dark',
    this.defaultDiscussionDuration = 300,
    this.autoSkipPhase = false,
    this.showRoleAfterDeath = false,
    this.showTimer = true,
    this.showClues = true,
    
    // Account Settings
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.showOnlineStatus = true,
    this.allowFriendRequests = true,
    this.timezone = 'Asia/Riyadh',
    this.dateFormat = 'dd/MM/yyyy',
    this.timeFormat = 'HH:mm',
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'avatar': avatar,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'totalScore': totalScore,
      
      // Game Settings
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
      'soundVolume': soundVolume,
      'musicVolume': musicVolume,
      'vibrationEnabled': vibrationEnabled,
      'notificationsEnabled': notificationsEnabled,
      'language': language,
      'theme': theme,
      'defaultDiscussionDuration': defaultDiscussionDuration,
      'autoSkipPhase': autoSkipPhase,
      'showRoleAfterDeath': showRoleAfterDeath,
      'showTimer': showTimer,
      'showClues': showClues,
      
      // Account Settings
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'showOnlineStatus': showOnlineStatus,
      'allowFriendRequests': allowFriendRequests,
      'timezone': timezone,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['userId'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String? ?? '👤',
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
      totalScore: json['totalScore'] as int? ?? 0,
      
      // Game Settings
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      soundVolume: (json['soundVolume'] as num?)?.toDouble() ?? 0.7,
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.5,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'ar',
      theme: json['theme'] as String? ?? 'dark',
      defaultDiscussionDuration: json['defaultDiscussionDuration'] as int? ?? 300,
      autoSkipPhase: json['autoSkipPhase'] as bool? ?? false,
      showRoleAfterDeath: json['showRoleAfterDeath'] as bool? ?? false,
      showTimer: json['showTimer'] as bool? ?? true,
      showClues: json['showClues'] as bool? ?? true,
      
      // Account Settings
      emailNotifications: json['emailNotifications'] as bool? ?? true,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
      allowFriendRequests: json['allowFriendRequests'] as bool? ?? true,
      timezone: json['timezone'] as String? ?? 'Asia/Riyadh',
      dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
      timeFormat: json['timeFormat'] as String? ?? 'HH:mm',
    );
  }

  UserSettings copyWith({
    String? userId,
    String? username,
    String? email,
    String? avatar,
    int? gamesPlayed,
    int? gamesWon,
    int? totalScore,
    bool? soundEnabled,
    bool? musicEnabled,
    double? soundVolume,
    double? musicVolume,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    String? language,
    String? theme,
    int? defaultDiscussionDuration,
    bool? autoSkipPhase,
    bool? showRoleAfterDeath,
    bool? showTimer,
    bool? showClues,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? showOnlineStatus,
    bool? allowFriendRequests,
    String? timezone,
    String? dateFormat,
    String? timeFormat,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      totalScore: totalScore ?? this.totalScore,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      defaultDiscussionDuration: defaultDiscussionDuration ?? this.defaultDiscussionDuration,
      autoSkipPhase: autoSkipPhase ?? this.autoSkipPhase,
      showRoleAfterDeath: showRoleAfterDeath ?? this.showRoleAfterDeath,
      showTimer: showTimer ?? this.showTimer,
      showClues: showClues ?? this.showClues,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowFriendRequests: allowFriendRequests ?? this.allowFriendRequests,
      timezone: timezone ?? this.timezone,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
} 