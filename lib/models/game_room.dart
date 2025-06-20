import 'package:mafioso/models/player.dart';

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
  Map<String, String> votes;
  int currentRound;
  List<String> eliminatedPlayers;
  String? lastEliminatedPlayer;
  bool isGameOver;
  String? winner;

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
      'votes': votes,
      'currentRound': currentRound,
      'eliminatedPlayers': eliminatedPlayers,
      'lastEliminatedPlayer': lastEliminatedPlayer,
      'isGameOver': isGameOver,
      'winner': winner,
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
      votes: Map<String, String>.from(json['votes'] ?? {}),
      currentRound: json['currentRound'] as int? ?? 1,
      eliminatedPlayers: List<String>.from(json['eliminatedPlayers'] ?? []),
      lastEliminatedPlayer: json['lastEliminatedPlayer'] as String?,
      isGameOver: json['isGameOver'] as bool? ?? false,
      winner: json['winner'] as String?,
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