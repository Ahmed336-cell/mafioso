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
  Map<String, dynamic> votes; // Changed to dynamic to support both old and new format
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
    this.votes = const {},
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
  });

  // Helper method to get vote info
  VoteInfo? getVoteInfo(String voterId) {
    final voteData = votes[voterId];
    if (voteData == null) return null;
    
    if (voteData is String) {
      // Old format - just target ID
      return VoteInfo(
        targetId: voteData,
        isWrongVote: false,
        voterRole: 'مدني',
        timestamp: 0,
      );
    } else if (voteData is Map<String, dynamic>) {
      // New format - with additional info
      return VoteInfo.fromJson(voteData);
    }
    return null;
  }

  // Helper method to get all wrong votes by civilians
  List<VoteInfo> get wrongVotesByCivilians {
    List<VoteInfo> wrongVotes = [];
    votes.forEach((voterId, voteData) {
      final voteInfo = getVoteInfo(voterId);
      if (voteInfo != null && voteInfo.isWrongVote && voteInfo.voterRole == 'مدني') {
        wrongVotes.add(voteInfo);
      }
    });
    return wrongVotes;
  }

  // Helper method to get simple vote mapping (for backward compatibility)
  Map<String, String> get simpleVotes {
    Map<String, String> simpleVotes = {};
    votes.forEach((voterId, voteData) {
      final voteInfo = getVoteInfo(voterId);
      if (voteInfo != null) {
        simpleVotes[voterId] = voteInfo.targetId;
      }
    });
    return simpleVotes;
  }

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
      'votes': votes,
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
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    var playersData = json['players'] as List<dynamic>? ?? [];

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
      votes: Map<String, dynamic>.from(json['votes'] ?? {}),
      currentRound: json['currentRound'] as int? ?? 1,
      eliminatedPlayers: List<String>.from(json['eliminatedPlayers'] ?? []),
      lastEliminatedPlayer: json['lastEliminatedPlayer'] as String?,
      isGameOver: json['isGameOver'] as bool? ?? false,
      winner: json['winner'] as String?,
      discussionDuration: json['discussionDuration'] as int? ?? 300,
      defensePlayers: List<String>.from(json['defensePlayers'] ?? []),
      chatMessages: (json['chatMessages'] as List<dynamic>? ?? []).map((msg) => Map<String, dynamic>.from(msg)).toList(),
      currentClueIndex: json['currentClueIndex'] as int? ?? 0,
      roomName: json['roomName'] as String? ?? '',
      pin: json['pin'] as String? ?? '',
      isFinalShowdown: json['isFinalShowdown'] as bool? ?? false,
      mafiosoStory: json['confession'] as String? ?? '',
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
}