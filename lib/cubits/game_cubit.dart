import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../models/game_room.dart';
import '../models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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

  String _generatePin([int length = 6]) {
    final rand = Random();
    return List.generate(length, (_) => rand.nextInt(10).toString()).join();
  }

  Future<void> createRoom(String roomName, {String? pin}) async {
    emit(GameLoading());
    try {
      String roomId = _generateRoomId();
      final generatedPin = pin ?? _generatePin();
      GameRoom room = GameRoom(
        id: roomId,
        hostId: '',
        players: [],
        caseTitle: '',
        caseDescription: '',
        clues: [],
        votes: {},
        eliminatedPlayers: [],
        defensePlayers: [],
        chatMessages: [],
        currentClueIndex: 0,
        currentRound: 1,
        discussionDuration: 300,
        isGameOver: false,
        winner: null,
        status: 'waiting',
        currentPhase: 'waiting',
        timeLeft: 300,
        roomName: roomName,
        pin: generatedPin,
      );
      await _database.child('rooms').child(roomId).set(room.toJson());
      currentRoom = room;
      currentPlayer = null;
      _listenToRoomUpdates(roomId);
      emit(GameRoomLoaded(room, null));
    } catch (e) {
      emit(GameError('حدث خطأ أثناء إنشاء الغرفة'));
    }
  }

  Future<void> joinRoom(String roomId, {required String pin}) async {
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
      if (room.pin != pin) {
        emit(GameError('الرقم السري غير صحيح'));
        return;
      }
      if (room.players.length >= 12) {
        emit(GameError('الغرفة ممتلئة'));
        return;
      }
      if (room.status != 'waiting') {
        emit(GameError('اللعبة قد بدأت بالفعل'));
        return;
      }
      currentRoom = room;
      currentPlayer = null;
      _listenToRoomUpdates(roomId);
      emit(GameRoomLoaded(room, null));
    } catch (e) {
      emit(GameError('حدث خطأ أثناء الانضمام للغرفة'));
    }
  }

  Future<void> startGame({int discussionDuration = 300, required Map<String, dynamic> selectedCase}) async {
    if (currentRoom == null || currentPlayer?.id != currentRoom?.hostId) return;
    if (currentRoom!.players.length < 3) {
      emit(GameError('يجب أن يكون هناك لاعبين اثنين على الأقل (بالإضافة للمضيف)'));
      return;
    }

    try {
      List<Player> playingPlayers = currentRoom!.players.where((p) => p.id != currentRoom!.hostId).toList();
      int mafiosoCount = (playingPlayers.length / 4).ceil().clamp(1, playingPlayers.length - 1);

      playingPlayers.shuffle();
      for (int i = 0; i < mafiosoCount; i++) {
        playingPlayers[i] = playingPlayers[i].copyWith(role: 'مافيوسو');
      }
      for (int i = mafiosoCount; i < playingPlayers.length; i++) {
        playingPlayers[i] = playingPlayers[i].copyWith(role: 'مدني');
      }

      final assignedPlayingPlayers = _assignCharacterInfo(playingPlayers);

      List<Player> finalPlayers = [];
      
      final hostPlayer = currentRoom!.players.firstWhere((p) => p.id == currentRoom!.hostId);
      finalPlayers.add(hostPlayer.copyWith(
        role: 'مضيف',
        isAlive: false,
        characterName: 'مدير اللعبة',
        characterDescription: 'مدير اللعبة والمضيف',
      ));
      
      finalPlayers.addAll(assignedPlayingPlayers);

      await _database.child('rooms').child(currentRoom!.id).update({
        'status': 'playing',
        'currentPhase': 'discussion',
        'timeLeft': discussionDuration,
        'discussionDuration': discussionDuration,
        'players': finalPlayers.map((p) => p.toJson()).toList(),
        'currentRound': 1,
        'caseTitle': selectedCase['title'],
        'caseDescription': selectedCase['description'],
        'clues': List<String>.from(selectedCase['clues'] ?? []),
        'mafiosoStory': selectedCase['confession'] ?? 'لم يتم الكشف عن القصة...',
        'currentClueIndex': 0,
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
    
    // Prevent host from voting
    if (currentPlayer!.role == 'مضيف') {
      emit(GameError('المضيف لا يمكنه التصويت'));
      return;
    }

    try {
      debugPrint('vote: player ${currentPlayer!.name} voting for $targetPlayerId');
      
      // Check if this is a wrong vote by a civilian
      bool isWrongVote = false;
      if (currentPlayer!.role == 'مدني') {
        // Find the target player in the current room
        final targetPlayer = currentRoom!.players.firstWhere(
          (p) => p.id == targetPlayerId,
          orElse: () => Player(id: '', name: '', role: 'مدني', avatar: ''),
        );
        // If target player is also civilian, this is a wrong vote
        if (targetPlayer.role == 'مدني') {
          isWrongVote = true;
        }
      }

      final voteData = {
        'targetId': targetPlayerId,
        'isWrongVote': isWrongVote,
        'voterRole': currentPlayer!.role,
        'timestamp': ServerValue.timestamp,
      };
      
      debugPrint('vote: vote data: $voteData');
      
      await _database.child('rooms').child(currentRoom!.id)
          .child('votes').child(currentPlayer!.id)
          .set(voteData);
          
      debugPrint('vote: vote saved successfully');
    } catch (e) {
      debugPrint('vote error: $e');
      emit(GameError('حدث خطأ أثناء التصويت: $e'));
    }
  }

  Future<void> endDiscussionPhase() async {
    if (currentRoom == null) return;
    try {
      debugPrint('endDiscussionPhase: setting phase to voting');
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
      debugPrint('endVotingPhase: counting votes and updating phase');
      
      // Get playing players (excluding host)
      final playingPlayers = currentRoom!.players.where((p) => p.role != 'مضيف' && p.isAlive).toList();
      
      debugPrint('endVotingPhase: playing players count: ${playingPlayers.length}');
      debugPrint('endVotingPhase: total votes count: ${currentRoom!.votes.length}');
      
      // Count votes and eliminate player (excluding host votes)
      Map<String, int> voteCount = {};
      currentRoom!.votes.forEach((voterId, voteData) {
        // Skip host votes
        final voter = currentRoom!.players.firstWhere(
          (p) => p.id == voterId,
          orElse: () => Player(id: '', name: '', role: 'مدني', avatar: ''),
        );
        if (voter.role == 'مضيف') return;
        
        String targetId;
        if (voteData is String) {
          // Old format
          targetId = voteData;
        } else if (voteData is Map<String, dynamic>) {
          // New format
          targetId = voteData['targetId'] as String;
        } else {
          debugPrint('endVotingPhase: invalid vote data format for voter $voterId');
          return; // Skip invalid vote data
        }
        voteCount[targetId] = (voteCount[targetId] ?? 0) + 1;
      });

      debugPrint('endVotingPhase: valid votes count: ${voteCount.length}');

      String? eliminatedPlayerId;
      int maxVotes = 0;
      List<String> topPlayers = [];
      
      voteCount.forEach((playerId, votes) {
        if (votes > maxVotes) {
          maxVotes = votes;
          topPlayers = [playerId];
        } else if (votes == maxVotes) {
          topPlayers.add(playerId);
        }
      });

      // إذا لم يكن هناك أي تصويت، اختر لاعب عشوائي للإقصاء
      if (voteCount.isEmpty && playingPlayers.isNotEmpty) {
        debugPrint('endVotingPhase: no votes cast, randomly eliminating a player');
        final random = Random();
        final randomPlayer = playingPlayers[random.nextInt(playingPlayers.length)];
        eliminatedPlayerId = randomPlayer.id;
        topPlayers = [randomPlayer.id];
        maxVotes = 1;
      }

      // إذا كان هناك تعادل
      if (topPlayers.length > 1) {
        debugPrint('endVotingPhase: tie detected, moving to defense phase');
        await _database.child('rooms').child(currentRoom!.id).update({
          'currentPhase': 'defense',
          'timeLeft': 30, // 30 ثانية للدفاع
          'defensePlayers': topPlayers,
        });
        return;
      }

      // إذا لم يكن هناك تعادل
      eliminatedPlayerId = topPlayers.isNotEmpty ? topPlayers.first : null;

      if (eliminatedPlayerId != null) {
        debugPrint('endVotingPhase: eliminating player $eliminatedPlayerId');
        
        List<Player> updatedPlayers = currentRoom!.players.map((player) {
          if (player.id == eliminatedPlayerId) {
            return player.copyWith(isAlive: false);
          }
          return player;
        }).toList();

        // Check if game is over (excluding host from count)
        bool gameOver = false;
        String? winner;

        final alivePlayers = updatedPlayers.where((p) => p.isAlive && p.role != 'مضيف').toList();
        final aliveMafioso = alivePlayers.where((p) => p.role == 'مافيوسو').length;
        final aliveCivilians = alivePlayers.where((p) => p.role == 'مدني').length;

        debugPrint('endVotingPhase: alive players - mafioso: $aliveMafioso, civilians: $aliveCivilians');

        // وضع المواجهة النهائية: لاعبان متبقيان، أحدهما مافيا
        if (alivePlayers.length == 2 && aliveMafioso == 1) {
          debugPrint('endVotingPhase: Final showdown triggered');
          await _database.child('rooms').child(currentRoom!.id).update({
            'currentPhase': 'voting',
            'timeLeft': 60,
            'players': updatedPlayers.map((p) => p.toJson()).toList(),
            'lastEliminatedPlayer': eliminatedPlayerId,
            'defensePlayers': alivePlayers.map((p) => p.id).toList(),
            'isFinalShowdown': true,
            'votes': {},
          });
          return;
        }
        
        if (aliveMafioso == 0) {
          gameOver = true;
          winner = 'مدنيين';
        } else if (aliveMafioso >= aliveCivilians) {
          gameOver = true;
          winner = 'مافيوسو';
        }

        // Count wrong votes by civilians for this round (excluding host)
        int wrongVotesCount = 0;
        currentRoom!.votes.forEach((voterId, voteData) {
          final voter = currentRoom!.players.firstWhere(
            (p) => p.id == voterId,
            orElse: () => Player(id: '', name: '', role: 'مدني', avatar: ''),
          );
          if (voter.role == 'مضيف') return;
          
          if (voteData is Map<String, dynamic>) {
            final isWrongVote = voteData['isWrongVote'] as bool? ?? false;
            final voterRole = voteData['voterRole'] as String? ?? 'مدني';
            if (isWrongVote && voterRole == 'مدني') {
              wrongVotesCount++;
            }
          }
        });

        debugPrint('endVotingPhase: updating to reveal phase, eliminated: $eliminatedPlayerId, gameOver: $gameOver, wrongVotes: $wrongVotesCount');
        
        final updateData = {
          'currentPhase': 'reveal',
          'timeLeft': 30, // 30 seconds to show elimination
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'lastEliminatedPlayer': eliminatedPlayerId,
          'isGameOver': gameOver,
          'winner': winner,
          'wrongVotesThisRound': wrongVotesCount,
        };
        
        debugPrint('endVotingPhase: update data: $updateData');
        await _database.child('rooms').child(currentRoom!.id).update(updateData);

        if (gameOver) {
          // حذف الغرفة بعد 10 ثوانٍ من انتهاء اللعبة
          Future.delayed(const Duration(seconds: 10), () async {
            await _database.child('rooms').child(currentRoom!.id).remove();
            // حذف معلومات اللاعب المحفوظة عند انتهاء اللعبة
            await clearSavedPlayer();
          });
        }
      } else {
        // إذا لم يكن هناك لاعبين للتصويت عليهم، انتقل للجولة التالية
        debugPrint('endVotingPhase: no players to eliminate, moving to next round');
        await startNextRound();
      }
    } catch (e) {
      debugPrint('endVotingPhase error: $e');
      emit(GameError('حدث خطأ أثناء حساب الأصوات: $e'));
      
      // Fallback: force move to next round if there's an error
      try {
        debugPrint('endVotingPhase: fallback - moving to next round due to error');
        await startNextRound();
      } catch (fallbackError) {
        debugPrint('endVotingPhase: fallback also failed: $fallbackError');
      }
    }
  }

  // إعادة التصويت بعد الدفاع
  Future<void> endDefensePhase() async {
    if (currentRoom == null) return;
    try {
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'voting',
        'timeLeft': 60, // 1 دقيقة للتصويت بين المتعادلين
        // votes will be reset by client logic
      });
    } catch (e) {
      emit(GameError('حدث خطأ أثناء إعادة التصويت'));
    }
  }

  Future<void> startNextRound() async {
    if (currentRoom == null) return;
    try {
      final int duration = currentRoom?.discussionDuration ?? 300;
      int nextClueIndex = (currentRoom!.currentClueIndex + 1);
      if (nextClueIndex >= currentRoom!.clues.length) nextClueIndex = currentRoom!.clues.length - 1;
      debugPrint('startNextRound: moving to next round, round: \\${currentRoom!.currentRound + 1}, clue: \\${nextClueIndex}');
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'discussion',
        'timeLeft': duration, // use chosen duration
        'currentRound': currentRoom!.currentRound + 1,
        'votes': {},
        'lastEliminatedPlayer': null,
        'currentClueIndex': nextClueIndex,
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
        .onValue.listen((event) async {
      if (!event.snapshot.exists) {
        emit(GameError('تم حذف الغرفة'));
        return;
      }
      try {
        currentRoom = GameRoom.fromJson(
          Map<String, dynamic>.from(event.snapshot.value as Map)
        );
        // اجلب playerId المحفوظ
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getString('mafioso_player_id');
        Player? foundPlayer;
        if (savedId != null) {
          try {
            foundPlayer = currentRoom!.players.firstWhere(
              (p) => p.id == savedId,
              orElse: () => currentRoom!.players.isNotEmpty ? currentRoom!.players.first : throw Exception('no players'),
            );
            if (foundPlayer.id != savedId) foundPlayer = null;
          } catch (_) {
            foundPlayer = null;
          }
        }
        currentPlayer = foundPlayer;
        emit(GameRoomLoaded(currentRoom!, currentPlayer));
      } catch (e) {
        emit(GameError('حدث خطأ أثناء تحديث حالة الغرفة'));
      }
    });
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // فقط المضيف يشغل التايمر
      if (currentRoom == null || currentPlayer?.id != currentRoom?.hostId) {
        debugPrint('_startGameTimer: not host, canceling timer');
        timer.cancel();
        return;
      }

      try {
        // احصل على آخر نسخة من الغرفة من Firebase
        final snapshot = await _database.child('rooms').child(currentRoom!.id).get();
        if (!snapshot.exists) {
          debugPrint('_startGameTimer: room no longer exists, canceling timer');
          timer.cancel();
          return;
        }
        currentRoom = GameRoom.fromJson(Map<String, dynamic>.from(snapshot.value as Map));

        debugPrint('_startGameTimer: current phase: ${currentRoom!.currentPhase}, timeLeft: ${currentRoom!.timeLeft}');

        if (currentRoom!.timeLeft > 0) {
          await _database.child('rooms').child(currentRoom!.id).update({
            'timeLeft': currentRoom!.timeLeft - 1,
          });
        } else {
          timer.cancel();
          debugPrint('Timer finished. Current phase: ${currentRoom!.currentPhase}');
          // Auto-advance phase based on current phase
          if (currentRoom!.isDiscussionPhase) {
            debugPrint('Calling endDiscussionPhase');
            await endDiscussionPhase();
          } else if (currentRoom!.isVotingPhase) {
            debugPrint('Calling endVotingPhase');
            await endVotingPhase();
          } else if (currentRoom!.isDefensePhase) {
            debugPrint('Calling endDefensePhase');
            await endDefensePhase();
          } else if (currentRoom!.isRevealPhase && !currentRoom!.isGameOver) {
            debugPrint('Calling startNextRound');
            await startNextRound();
          }
        }
      } catch (e) {
        debugPrint('_startGameTimer error: $e');
        // Don't cancel timer on error, just log it
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

  Future<void> sendChatMessage(String text) async {
    if (currentRoom == null || currentPlayer == null) return;
    final message = {
      'senderId': currentPlayer!.id,
      'senderName': currentPlayer!.name,
      'avatar': currentPlayer!.avatar,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final ref = _database.child('rooms').child(currentRoom!.id).child('chatMessages');
    await ref.push().set(message);
  }

  // دالة لاسترجاع playerId المخزن
  static Future<String?> getSavedPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mafioso_player_id');
  }

  // دالة للتحقق من وجود غرفة للاعب المحفوظ
  static Future<bool> hasSavedRoom() async {
    try {
      final savedPlayerId = await getSavedPlayerId();
      if (savedPlayerId == null) return false;

      final roomsRef = FirebaseDatabase.instance.ref().child('rooms');
      final roomsSnapshot = await roomsRef.get();
      
      if (!roomsSnapshot.exists) return false;

      final roomsData = roomsSnapshot.value as Map<dynamic, dynamic>;
      
      for (final roomEntry in roomsData.entries) {
        final roomData = roomEntry.value as Map<dynamic, dynamic>;
        final playersData = roomData['players'] as List<dynamic>? ?? [];
        
        for (final playerData in playersData) {
          final player = Player.fromJson(Map<String, dynamic>.from(playerData));
          if (player.id == savedPlayerId) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('hasSavedRoom error: $e');
      return false;
    }
  }

  // دالة لحذف معلومات اللاعب المحفوظة
  static Future<void> clearSavedPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mafioso_player_id');
  }

  // دالة تخطي المرحلة للمضيف فقط
  Future<void> skipPhase() async {
    if (currentRoom == null || currentPlayer?.id != currentRoom?.hostId) {
      debugPrint('skipPhase: not host or no room');
      return;
    }
    
    try {
      debugPrint('skipPhase: current phase is ${currentRoom!.currentPhase}');
      
      if (currentRoom!.currentPhase == 'discussion') {
        debugPrint('skipPhase: skipping discussion phase');
        await endDiscussionPhase();
      } else if (currentRoom!.currentPhase == 'voting') {
        debugPrint('skipPhase: skipping voting phase');
        await endVotingPhase();
      } else if (currentRoom!.currentPhase == 'defense') {
        debugPrint('skipPhase: skipping defense phase');
        await endDefensePhase();
      } else if (currentRoom!.currentPhase == 'reveal' && !currentRoom!.isGameOver) {
        debugPrint('skipPhase: skipping reveal phase');
        await startNextRound();
      } else {
        debugPrint('skipPhase: cannot skip current phase: ${currentRoom!.currentPhase}');
      }
    } catch (e) {
      debugPrint('skipPhase error: $e');
      emit(GameError('حدث خطأ أثناء تخطي المرحلة: $e'));
    }
  }

  Future<void> rejoinRoom() async {
    try {
      final savedPlayerId = await getSavedPlayerId();
      if (savedPlayerId == null) {
        emit(GameError('لم يتم العثور على معلومات اللاعب المحفوظة'));
        return;
      }

      // Search for rooms where this player was a member
      final roomsRef = _database.child('rooms');
      final roomsSnapshot = await roomsRef.get();
      
      if (!roomsSnapshot.exists) {
        emit(GameError('لا توجد غرف متاحة'));
        return;
      }

      final roomsData = roomsSnapshot.value as Map<dynamic, dynamic>;
      GameRoom? foundRoom;
      Player? foundPlayer;

      for (final roomEntry in roomsData.entries) {
        final roomData = roomEntry.value as Map<dynamic, dynamic>;
        final playersData = roomData['players'] as List<dynamic>? ?? [];
        
        for (final playerData in playersData) {
          final player = Player.fromJson(Map<String, dynamic>.from(playerData));
          if (player.id == savedPlayerId) {
            foundRoom = GameRoom.fromJson(Map<String, dynamic>.from(roomData));
            foundPlayer = player;
            break;
          }
        }
        if (foundRoom != null) break;
      }

      if (foundRoom != null && foundPlayer != null) {
        currentRoom = foundRoom;
        currentPlayer = foundPlayer;
        _listenToRoomUpdates(foundRoom.id);
        emit(GameRoomLoaded(foundRoom, foundPlayer));
      } else {
        emit(GameError('لم يتم العثور على غرفة للانضمام إليها'));
      }
    } catch (e) {
      emit(GameError('حدث خطأ أثناء إعادة الانضمام للغرفة'));
    }
  }

  // دالة للخروج من الغرفة
  Future<void> leaveRoom() async {
    if (currentRoom == null || currentPlayer == null) return;
    
    try {
      // حذف اللاعب من الغرفة
      List<Player> updatedPlayers = currentRoom!.players
          .where((p) => p.id != currentPlayer!.id)
          .toList();
      
      await _database.child('rooms').child(currentRoom!.id).update({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
      });
      
      // حذف معلومات اللاعب المحفوظة
      await clearSavedPlayer();
      
      // إعادة تعيين الحالة
      currentRoom = null;
      currentPlayer = null;
      _roomSubscription?.cancel();
      _gameTimer?.cancel();
      
      emit(GameInitial());
    } catch (e) {
      emit(GameError('حدث خطأ أثناء الخروج من الغرفة'));
    }
  }
}