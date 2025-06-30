import 'package:mafioso/models/player.dart';

class VoteInfo {
  final String targetId;
  final bool isWrongVote;
  final String voterRole;
  final int timestamp;

  VoteInfo({
    required this.targetId,
    required this.isWrongVote,
    required this.voterRole,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetId': targetId,
      'isWrongVote': isWrongVote,
      'voterRole': voterRole,
      'timestamp': timestamp,
    };
  }

  factory VoteInfo.fromJson(Map<String, dynamic> json) {
    return VoteInfo(
      targetId: json['targetId'] as String,
      isWrongVote: json['isWrongVote'] as bool? ?? false,
      voterRole: json['voterRole'] as String? ?? 'مدني',
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

class GameRoom {
  final String id;
  final String hostId;
  List<Player> players;
  String status;
  String currentPhase;
  int timeLeft;
  String caseTitle;
  String caseDescription;
  List<String> clues;
  int currentRound;
  List<String> eliminatedPlayers;
  String? lastEliminatedPlayer;
  bool isGameOver;
  String? winner;
  int discussionDuration;
  List<String> defensePlayers;
  List<Map<String, dynamic>> chatMessages;
  int currentClueIndex;
  final String roomName;
  final String pin;
  bool isFinalShowdown;
  String mafiosoStory;
  String? lastEliminatedPlayerId;
  String? phaseMessage;

  GameRoom({
    required this.id,
    required this.hostId,
    required this.players,
    this.status = 'waiting',
    this.currentPhase = 'waiting',
    this.timeLeft = 300,
    this.caseTitle = '',
    this.caseDescription = '',
    this.clues = const [],
    this.currentRound = 1,
    this.eliminatedPlayers = const [],
    this.lastEliminatedPlayer,
    this.isGameOver = false,
    this.winner,
    this.discussionDuration = 300,
    this.defensePlayers = const [],
    this.chatMessages = const [],
    this.currentClueIndex = 0,
    required this.roomName,
    required this.pin,
    this.isFinalShowdown = false,
    this.mafiosoStory = '',
    this.lastEliminatedPlayerId,
    this.phaseMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status,
      'currentPhase': currentPhase,
      'timeLeft': timeLeft,
      'caseTitle': caseTitle,
      'caseDescription': caseDescription,
      'clues': clues,
      'currentRound': currentRound,
      'eliminatedPlayers': eliminatedPlayers,
      'lastEliminatedPlayer': lastEliminatedPlayer,
      'isGameOver': isGameOver,
      'winner': winner,
      'discussionDuration': discussionDuration,
      'defensePlayers': defensePlayers,
      'chatMessages': chatMessages,
      'currentClueIndex': currentClueIndex,
      'roomName': roomName,
      'pin': pin,
      'isFinalShowdown': isFinalShowdown,
      'confession': mafiosoStory,
      'lastEliminatedPlayerId': lastEliminatedPlayerId,
      'phaseMessage': phaseMessage,
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    var playersData = json['players'] as List<dynamic>? ?? [];
    var chatMessagesData = json['chatMessages'];

    List<Map<String, dynamic>> chatMessagesList = [];
    if (chatMessagesData is Map) {
      // If it's a map (from Firebase), convert it to a list of its values.
      chatMessagesList = chatMessagesData.values
          .map((msg) => Map<String, dynamic>.from(msg as Map))
          .toList();
    } else if (chatMessagesData is List) {
      // If it's already a list, use it directly.
      chatMessagesList = chatMessagesData
          .map((msg) => Map<String, dynamic>.from(msg as Map))
          .toList();
    }

    return GameRoom(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      players: playersData
          .map((p) => Player.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      status: json['status'] as String? ?? 'waiting',
      currentPhase: json['currentPhase'] as String? ?? 'waiting',
      timeLeft: json['timeLeft'] as int? ?? 300,
      caseTitle: json['caseTitle'] as String? ?? '',
      caseDescription: json['caseDescription'] as String? ?? '',
      clues: List<String>.from(json['clues'] ?? []),
      currentRound: json['currentRound'] as int? ?? 1,
      eliminatedPlayers: List<String>.from(json['eliminatedPlayers'] ?? []),
      lastEliminatedPlayer: json['lastEliminatedPlayer'] as String?,
      isGameOver: json['isGameOver'] as bool? ?? false,
      winner: json['winner'] as String?,
      discussionDuration: json['discussionDuration'] as int? ?? 300,
      defensePlayers: List<String>.from(json['defensePlayers'] ?? []),
      chatMessages: chatMessagesList,
      currentClueIndex: json['currentClueIndex'] as int? ?? 0,
      roomName: json['roomName'] as String? ?? '',
      pin: json['pin'] as String? ?? '',
      isFinalShowdown: json['isFinalShowdown'] as bool? ?? false,
      mafiosoStory: json['confession'] as String? ?? '',
      lastEliminatedPlayerId: json['lastEliminatedPlayerId'] as String?,
      phaseMessage: json['phaseMessage'],
    );
  }

  // Helper methods
  List<Player> get alivePlayers => players.where((p) => p.isAlive).toList();
  List<Player> get deadPlayers => players.where((p) => !p.isAlive).toList();
  int get mafiosoCount => players.where((p) => p.role == 'مافيوسو').length;
  int get civilianCount => players.where((p) => p.role == 'مدني').length;
  
  bool get isVotingPhase => currentPhase == 'voting';
  bool get isDiscussionPhase => currentPhase == 'discussion';
  bool get isDefensePhase => currentPhase == 'defense';
  bool get isRevealPhase => currentPhase == 'reveal';

  GameRoom copyWith({
    List<Player>? players,
    String? status,
    String? currentPhase,
    int? timeLeft,
    String? caseTitle,
    String? caseDescription,
    List<String>? clues,
    int? currentRound,
    List<String>? eliminatedPlayers,
    String? lastEliminatedPlayer,
    bool? isGameOver,
    String? winner,
    int? discussionDuration,
    List<String>? defensePlayers,
    List<Map<String, dynamic>>? chatMessages,
    int? currentClueIndex,
    String? roomName,
    String? pin,
    bool? isFinalShowdown,
    String? mafiosoStory,
    String? lastEliminatedPlayerId,
    String? phaseMessage,
  }) {
    return GameRoom(
      id: id,
      hostId: hostId,
      players: players ?? this.players,
      status: status ?? this.status,
      currentPhase: currentPhase ?? this.currentPhase,
      timeLeft: timeLeft ?? this.timeLeft,
      caseTitle: caseTitle ?? this.caseTitle,
      caseDescription: caseDescription ?? this.caseDescription,
      clues: clues ?? this.clues,
      currentRound: currentRound ?? this.currentRound,
      eliminatedPlayers: eliminatedPlayers ?? this.eliminatedPlayers,
      lastEliminatedPlayer: lastEliminatedPlayer ?? this.lastEliminatedPlayer,
      isGameOver: isGameOver ?? this.isGameOver,
      winner: winner ?? this.winner,
      discussionDuration: discussionDuration ?? this.discussionDuration,
      defensePlayers: defensePlayers ?? this.defensePlayers,
      chatMessages: chatMessages ?? this.chatMessages,
      currentClueIndex: currentClueIndex ?? this.currentClueIndex,
      roomName: roomName ?? this.roomName,
      pin: pin ?? this.pin,
      isFinalShowdown: isFinalShowdown ?? this.isFinalShowdown,
      mafiosoStory: mafiosoStory ?? this.mafiosoStory,
      lastEliminatedPlayerId: lastEliminatedPlayerId ?? this.lastEliminatedPlayerId,
      phaseMessage: phaseMessage ?? this.phaseMessage,
    );
  }
}