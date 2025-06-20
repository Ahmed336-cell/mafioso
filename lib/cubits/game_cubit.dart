import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../models/game_room.dart';
import '../models/player.dart';

part 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  GameRoom? currentRoom;
  Player? currentPlayer;
  StreamSubscription? _roomSubscription;
  Timer? _gameTimer;

  GameCubit() : super(GameInitial());

  @override
  Future<void> close() {
    _roomSubscription?.cancel();
    _gameTimer?.cancel();
    return super.close();
  }

  Future<void> createRoom(String playerName) async {
    emit(GameLoading());
    try {
      String roomId = _generateRoomId();
      String playerId = DateTime.now().millisecondsSinceEpoch.toString();

      Player host = Player(
        id: playerId,
        name: playerName,
        role: 'مضيف',
        avatar: '👑',
      );

      final List<Map<String, dynamic>> cases = [
        {
          'title': 'جريمة في القصر',
          'description': 'تم العثور على سيد القصر ميتاً في مكتبه. الباب مقفل من الداخل والنافذة محطمة.',
          'clues': [
            'تم العثور على بقع دم على السجادة',
            'الخزنة مفتوحة والأموال مفقودة',
            'رائحة سم في كوب الشاي',
            'خطاب تهديد في الدرج',
          ]
        },
        {
          'title': 'لغز المتحف',
          'description': 'اختفت لوحة ثمينة من المتحف ليلاً. كاميرات المراقبة معطلة.',
          'clues': [
            'آثار أقدام على الأرض',
            'نافذة مكسورة في الطابق العلوي',
            'تقرير أمني مفقود',
            'بطاقة موظف مسروقة',
          ]
        },
        {
          'title': 'جريمة في المطعم',
          'description': 'تم العثور على طاهي المطعم ميتاً في المطبخ. الأدلة تشير إلى تسمم.',
          'clues': [
            'طعام مسموم في الطبق الرئيسي',
            'مفتاح خزنة مفقود',
            'رسالة غامضة في جيب الضحية',
            'شاهد يزعم رؤية شخص مشبوه',
          ]
        }
      ];

      Map<String, dynamic> caseData = cases[Random().nextInt(cases.length)];

      GameRoom room = GameRoom(
        id: roomId,
        hostId: playerId,
        players: [host],
        caseTitle: caseData['title'],
        caseDescription: caseData['description'],
        clues: List<String>.from(caseData['clues']),
      );

      await _database.child('rooms').child(roomId).set(room.toJson());

      currentRoom = room;
      currentPlayer = host;

      _listenToRoomUpdates(roomId);

      emit(GameRoomLoaded(room, host));
    } catch (e) {
      emit(GameError('حدث خطأ أثناء إنشاء الغرفة'));
    }
  }

  Future<void> joinRoom(String roomId, String playerName) async {
    emit(GameLoading());
    try {
      DatabaseEvent snapshot = await _database.child('rooms').child(roomId).once();

      if (!snapshot.snapshot.exists) {
        emit(GameError('الغرفة غير موجودة'));
        return;
      }

      GameRoom room = GameRoom.fromJson(
        Map<String, dynamic>.from(snapshot.snapshot.value as Map)
      );

      if (room.players.length >= 12) {
        emit(GameError('الغرفة ممتلئة'));
        return;
      }

      if (room.status != 'waiting') {
        emit(GameError('اللعبة قد بدأت بالفعل'));
        return;
      }

      String playerId = DateTime.now().millisecondsSinceEpoch.toString();
      Player newPlayer = Player(
        id: playerId,
        name: playerName,
        role: 'مدني',
        avatar: _getRandomAvatar(),
      );

      room.players.add(newPlayer);

      await _database.child('rooms').child(roomId).child('players').set(
        room.players.map((p) => p.toJson()).toList()
      );

      currentRoom = room;
      currentPlayer = newPlayer;

      _listenToRoomUpdates(roomId);

      emit(GameRoomLoaded(room, newPlayer));
    } catch (e) {
      emit(GameError('حدث خطأ أثناء الانضمام للغرفة'));
    }
  }

  Future<void> startGame() async {
    if (currentRoom == null || currentPlayer?.id != currentRoom?.hostId) return;
    if (currentRoom!.players.length < 4) {
      emit(GameError('يجب أن يكون هناك 4 لاعبين على الأقل'));
      return;
    }

    try {
      List<Player> players = List.from(currentRoom!.players);
      int mafiosoCount = (players.length / 4).floor();

      // Assign roles randomly
      players.shuffle();
      for (int i = 0; i < mafiosoCount; i++) {
        players[i] = players[i].copyWith(role: 'مافيوسو');
      }

      // Assign character information
      players = _assignCharacterInfo(players);

      await _database.child('rooms').child(currentRoom!.id).update({
        'status': 'playing',
        'currentPhase': 'discussion',
        'timeLeft': 300, // 5 minutes for discussion
        'players': players.map((p) => p.toJson()).toList(),
        'currentRound': 1,
      });

      _startGameTimer();
    } catch (e) {
      emit(GameError('حدث خطأ أثناء بدء اللعبة'));
    }
  }

  Future<void> vote(String targetPlayerId) async {
    if (currentRoom == null || currentPlayer == null) return;
    if (currentRoom!.status != 'playing') return;
    if (currentRoom!.currentPhase != 'voting') return;

    try {
      await _database.child('rooms').child(currentRoom!.id)
          .child('votes').child(currentPlayer!.id)
          .set(targetPlayerId);
    } catch (e) {
      emit(GameError('حدث خطأ أثناء التصويت'));
    }
  }

  Future<void> endDiscussionPhase() async {
    if (currentRoom == null) return;
    
    try {
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'voting',
        'timeLeft': 60, // 1 minute for voting
      });
    } catch (e) {
      emit(GameError('حدث خطأ أثناء الانتقال لمرحلة التصويت'));
    }
  }

  Future<void> endVotingPhase() async {
    if (currentRoom == null) return;
    
    try {
      // Count votes and eliminate player
      Map<String, int> voteCount = {};
      currentRoom!.votes.forEach((voterId, targetId) {
        voteCount[targetId] = (voteCount[targetId] ?? 0) + 1;
      });

      String? eliminatedPlayerId;
      int maxVotes = 0;
      
      voteCount.forEach((playerId, votes) {
        if (votes > maxVotes) {
          maxVotes = votes;
          eliminatedPlayerId = playerId;
        }
      });

      if (eliminatedPlayerId != null) {
        List<Player> updatedPlayers = currentRoom!.players.map((player) {
          if (player.id == eliminatedPlayerId) {
            return player.copyWith(isAlive: false);
          }
          return player;
        }).toList();

        // Check if game is over
        bool gameOver = false;
        String? winner;
        
        int aliveMafioso = updatedPlayers.where((p) => p.isAlive && p.role == 'مافيوسو').length;
        int aliveCivilians = updatedPlayers.where((p) => p.isAlive && p.role == 'مدني').length;

        if (aliveMafioso == 0) {
          gameOver = true;
          winner = 'مدنيين';
        } else if (aliveMafioso >= aliveCivilians) {
          gameOver = true;
          winner = 'مافيوسو';
        }

        await _database.child('rooms').child(currentRoom!.id).update({
          'currentPhase': 'reveal',
          'timeLeft': 30, // 30 seconds to show elimination
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'lastEliminatedPlayer': eliminatedPlayerId,
          'isGameOver': gameOver,
          'winner': winner,
        });
      }
    } catch (e) {
      emit(GameError('حدث خطأ أثناء حساب الأصوات'));
    }
  }

  Future<void> startNextRound() async {
    if (currentRoom == null) return;
    
    try {
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'discussion',
        'timeLeft': 300, // 5 minutes for discussion
        'currentRound': currentRoom!.currentRound + 1,
        'votes': {},
        'lastEliminatedPlayer': null,
      });
    } catch (e) {
      emit(GameError('حدث خطأ أثناء بدء الجولة التالية'));
    }
  }

  Future<void> addDummyPlayers(int count) async {
    if (currentRoom == null) return;

    try {
      List<Player> newPlayers = List.from(currentRoom!.players);
      for (int i = 0; i < count; i++) {
        String playerId = '${DateTime.now().millisecondsSinceEpoch}-$i';
        Player dummyPlayer = Player(
          id: playerId,
          name: 'لاعب وهمي ${i + 1}',
          role: 'مدني',
          avatar: _getRandomAvatar(),
        );
        newPlayers.add(dummyPlayer);
      }

      await _database
          .child('rooms')
          .child(currentRoom!.id)
          .child('players')
          .set(newPlayers.map((p) => p.toJson()).toList());
    } catch (e) {
      emit(GameError('حدث خطأ أثناء إضافة لاعبين وهميين'));
    }
  }

  void _listenToRoomUpdates(String roomId) {
    _roomSubscription?.cancel();

    _roomSubscription = _database.child('rooms').child(roomId)
        .onValue.listen((event) {
      if (!event.snapshot.exists) {
        emit(GameError('تم حذف الغرفة'));
        return;
      }

      try {
        currentRoom = GameRoom.fromJson(
          Map<String, dynamic>.from(event.snapshot.value as Map)
        );
        currentPlayer = currentRoom!.players.firstWhere(
          (p) => p.id == currentPlayer?.id,
          orElse: () => currentPlayer!,
        );
        emit(GameRoomLoaded(currentRoom!, currentPlayer!));
      } catch (e) {
        emit(GameError('حدث خطأ أثناء تحديث حالة الغرفة'));
      }
    });
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (currentRoom == null) {
        timer.cancel();
        return;
      }

      if (currentRoom!.timeLeft > 0) {
        await _database.child('rooms').child(currentRoom!.id).update({
          'timeLeft': currentRoom!.timeLeft - 1,
        });
      } else {
        timer.cancel();
        // Auto-advance phase based on current phase
        if (currentRoom!.isDiscussionPhase) {
          await endDiscussionPhase();
        } else if (currentRoom!.isVotingPhase) {
          await endVotingPhase();
        } else if (currentRoom!.isRevealPhase && !currentRoom!.isGameOver) {
          await startNextRound();
        }
      }
    });
  }

  List<Player> _assignCharacterInfo(List<Player> players) {
    final List<Map<String, String>> characters = [
      {
        'name': 'الطبيب',
        'description': 'طبيب محلي معروف بسمعته الطيبة',
        'relationship': 'كان يعالج الضحية',
        'alibi': 'كان في المستشفى وقت الجريمة',
      },
      {
        'name': 'الخادمة',
        'description': 'خادمة تعمل في المكان منذ سنوات',
        'relationship': 'تعرف الضحية جيداً',
        'alibi': 'كانت تنظف الطابق العلوي',
      },
      {
        'name': 'الشرطي',
        'description': 'ضابط شرطة محلي',
        'relationship': 'كان يحقق في قضايا سابقة للضحية',
        'alibi': 'كان في مركز الشرطة',
      },
      {
        'name': 'الطاهي',
        'description': 'طاهي مشهور في المنطقة',
        'relationship': 'كان يعد الطعام للضحية',
        'alibi': 'كان في المطبخ يعد العشاء',
      },
      {
        'name': 'السائق',
        'description': 'سائق خاص للضحية',
        'relationship': 'يعمل مع الضحية منذ سنوات',
        'alibi': 'كان يغسل السيارة في المرآب',
      },
      {
        'name': 'المحامي',
        'description': 'محامي معروف في المدينة',
        'relationship': 'كان يمثل الضحية في قضايا قانونية',
        'alibi': 'كان في مكتبه يعد أوراق قضية',
      },
      {
        'name': 'البستاني',
        'description': 'بستاني يعمل في المكان',
        'relationship': 'يعرف الضحية من خلال عمله',
        'alibi': 'كان يزرع الزهور في الحديقة',
      },
      {
        'name': 'الكاتب',
        'description': 'كاتب وصحفي محلي',
        'relationship': 'كان يكتب مقالاً عن الضحية',
        'alibi': 'كان في مكتب الصحيفة',
      },
    ];

    // Shuffle characters and assign to players
    characters.shuffle();
    for (int i = 0; i < players.length && i < characters.length; i++) {
      final character = characters[i];
      players[i] = players[i].copyWith(
        characterName: character['name']!,
        characterDescription: character['description']!,
        relationshipToVictim: character['relationship']!,
        alibi: character['alibi']!,
      );
    }

    return players;
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  String _getRandomAvatar() {
    List<String> avatars = ['👤', '👨', '👩', '🧑', '👱', '🧔', '👴', '👵'];
    return avatars[Random().nextInt(avatars.length)];
  }
}