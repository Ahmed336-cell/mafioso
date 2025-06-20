class Player {
  final String id;
  final String name;
  String role;
  final String avatar;
  bool isAlive;
  int votes;
  String characterName;
  String characterDescription;
  String relationshipToVictim;
  String alibi;
  bool hasVoted;

  Player({
    required this.id,
    required this.name,
    this.role = 'مدني',
    required this.avatar,
    this.isAlive = true,
    this.votes = 0,
    this.characterName = '',
    this.characterDescription = '',
    this.relationshipToVictim = '',
    this.alibi = '',
    this.hasVoted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'avatar': avatar,
      'isAlive': isAlive,
      'votes': votes,
      'characterName': characterName,
      'characterDescription': characterDescription,
      'relationshipToVictim': relationshipToVictim,
      'alibi': alibi,
      'hasVoted': hasVoted,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? 'مدني',
      avatar: json['avatar'] as String,
      isAlive: json['isAlive'] as bool? ?? true,
      votes: json['votes'] as int? ?? 0,
      characterName: json['characterName'] as String? ?? '',
      characterDescription: json['characterDescription'] as String? ?? '',
      relationshipToVictim: json['relationshipToVictim'] as String? ?? '',
      alibi: json['alibi'] as String? ?? '',
      hasVoted: json['hasVoted'] as bool? ?? false,
    );
  }

  Player copyWith({
    String? id,
    String? name,
    String? role,
    String? avatar,
    bool? isAlive,
    int? votes,
    String? characterName,
    String? characterDescription,
    String? relationshipToVictim,
    String? alibi,
    bool? hasVoted,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      isAlive: isAlive ?? this.isAlive,
      votes: votes ?? this.votes,
      characterName: characterName ?? this.characterName,
      characterDescription: characterDescription ?? this.characterDescription,
      relationshipToVictim: relationshipToVictim ?? this.relationshipToVictim,
      alibi: alibi ?? this.alibi,
      hasVoted: hasVoted ?? this.hasVoted,
    );
  }
} 