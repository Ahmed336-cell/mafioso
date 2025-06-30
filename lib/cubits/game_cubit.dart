import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../models/game_room.dart';
import '../models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'settings_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final SettingsCubit settingsCubit;
  GameRoom? currentRoom;
  Player? currentPlayer;
  StreamSubscription? _roomSubscription;
  Timer? _gameTimer;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- NEW: Local snapshot for story reveal ---
  static GameRoom? lastRoomSnapshot;
  static GameRoom? getLastRoomSnapshot() => lastRoomSnapshot;
  static void clearLastRoomSnapshot() => lastRoomSnapshot = null;

  GameCubit({required this.settingsCubit}) : super(GameInitial());

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

    print('Starting game with case: ${selectedCase['title']}');
    
    try {
      final List<dynamic> suspectsFromCase = List<dynamic>.from(selectedCase['suspects'] ?? []);
      List<Player> playingPlayers = currentRoom!.players.where((p) => p.id != currentRoom!.hostId).toList();
      print('Found ${playingPlayers.length} playing players.');

      if (playingPlayers.isEmpty) {
        emit(GameError('لا يمكن بدء اللعبة بدون لاعبين.'));
        return;
      }

      final mafiosoSuspects = suspectsFromCase.where((s) => s['in_game_role'] == 'مافيوسو').toList();
      final civilianSuspects = suspectsFromCase.where((s) => s['in_game_role'] == 'المدني').toList();
      print('Case has ${mafiosoSuspects.length} mafioso and ${civilianSuspects.length} civilians.');

      if (mafiosoSuspects.isEmpty) {
        emit(GameError('القصة المختارة يجب أن تحتوي على شخصية مافيوسو واحدة على الأقل.'));
        return;
      }

      if (playingPlayers.length < mafiosoSuspects.length) {
        emit(GameError('عدد اللاعبين (${playingPlayers.length}) أقل من عدد شخصيات المافيا المحددة في القصة (${mafiosoSuspects.length}).'));
        return;
      }
      
      playingPlayers.shuffle();
      List<Player> assignedPlayers = [];

      print('Assigning ${mafiosoSuspects.length} mafioso roles...');
      for (int i = 0; i < mafiosoSuspects.length; i++) {
        final player = playingPlayers[i];
        final suspect = mafiosoSuspects[i];
        assignedPlayers.add(player.copyWith(
          role: 'مافيوسو',
          characterName: suspect['name'],
          characterJob: suspect['job'],
          characterDescription: suspect['description'],
        ));
      }
      print('Mafioso roles assigned.');

      List<Player> remainingPlayers = playingPlayers.sublist(mafiosoSuspects.length);
      if (remainingPlayers.isNotEmpty) {
        print('Assigning civilian roles to ${remainingPlayers.length} players...');
        List<Map<String, dynamic>> civilianPool = List<Map<String, dynamic>>.from(civilianSuspects);
        
        int neededFillers = remainingPlayers.length - civilianPool.length;
        if (neededFillers > 0) {
          print('Not enough civilians in case, adding $neededFillers generic characters.');
          civilianPool.addAll(_getGenericCharacters(neededFillers));
        }
        civilianPool.shuffle();

        for (int i = 0; i < remainingPlayers.length; i++) {
          final player = remainingPlayers[i];
          final civilianCharacter = civilianPool[i];
          assignedPlayers.add(player.copyWith(
            role: 'مدني',
            characterName: civilianCharacter['name'],
            characterJob: civilianCharacter['job'],
            characterDescription: civilianCharacter['description'],
          ));
        }
        print('Civilian roles assigned.');
      }
      
      List<Player> finalPlayers = [];
      final hostPlayer = currentRoom!.players.firstWhere((p) => p.id == currentRoom!.hostId);
      finalPlayers.add(hostPlayer.copyWith(
        role: 'مضيف',
        isAlive: false,
        characterName: 'مدير اللعبة',
        characterDescription: 'مدير اللعبة والمضيف',
      ));
      
      assignedPlayers.shuffle();
      finalPlayers.addAll(assignedPlayers);

      print('Updating game room in Firebase...');
      await _database.child('rooms').child(currentRoom!.id).update({
        'status': 'playing',
        'currentPhase': 'discussion',
        'timeLeft': discussionDuration,
        'discussionDuration': discussionDuration,
        'players': finalPlayers.map((p) => p.toJson()).toList(),
        'currentRound': 1,
        'caseTitle': selectedCase['title'],
        'caseDescription': selectedCase['description'],
        'clues': List<String>.from(selectedCase['hints'] ?? []),
        'mafiosoStory': selectedCase['confession'] ?? 'لم يتم الكشف عن القصة...',
        'currentClueIndex': 0,
      });

      print('Game started successfully, starting timer.');
      _startGameTimer();
    } catch (e, s) {
      print('Error in startGame: $e');
      print('Stacktrace: $s');
      emit(GameError('حدث خطأ فني أثناء بدء اللعبة: $e'));
    }
  }

  List<Map<String, dynamic>> _getGenericCharacters(int count) {
    final List<Map<String, dynamic>> allCharacters = [
      {'name': 'شاهد عيان', 'job': 'متفرّج', 'description': 'شخص كان متواجدًا بالصدفة بالقرب من مكان الحادث ورأى شيئًا قد يكون مهمًا.'},
      {'name': 'جار الضحية', 'job': 'جار', 'description': 'يسكن بالقرب من الضحية، وقد يكون سمع أو رأى تحركات غريبة.'},
      {'name': 'المحقق المناوب', 'job': 'محقق', 'description': 'محقق شاب وصل أولاً إلى مسرح الجريمة ويحاول إثبات نفسه.'},
      {'name': 'طبيب شرعي', 'job': 'طبيب', 'description': 'الطبيب المسؤول عن فحص الجثة وتحديد سبب الوفاة.'},
      {'name': 'صحفي فضولي', 'job': 'صحفي', 'description': 'صحفي يسعى للحصول على سبق صحفي حول القضية، وقد يكشف أسرارًا لا يعرفها أحد.'},
      {'name': 'عامل النظافة', 'job': 'عامل', 'description': 'كان يقوم بعمله كالمعتاد، لكنه لاحظ تفاصيل لم يلاحظها الآخرون.'},
      {'name': 'ساعي البريد', 'job': 'موظف بريد', 'description': 'شخصية روتينية، لكنه يعرف حركة الناس في المنطقة جيدًا.'},
      {'name': 'صديق قديم', 'job': 'صديق', 'description': 'صديق لم يرَ الضحية منذ فترة طويلة، وعاد للظهور بشكل مفاجئ.'},
      {'name': 'رجل أعمال منافس', 'job': 'رجل أعمال', 'description': 'منافس للضحية في العمل، وقد يكون لديه دافع للتخلص منه.'},
      {'name': 'خبير أمني', 'job': 'خبير', 'description': 'تم استدعاؤه لتحليل الجانب التقني للجريمة، مثل الكاميرات أو الأقفال.'},
      {'name': 'موظف أرشيف', 'job': 'موظف', 'description': 'لديه إمكانية الوصول إلى سجلات قديمة قد تكشف عن دوافع خفية.'},
      {'name': 'سائق أجرة', 'job': 'سائق', 'description': 'أوصل أحد المشتبه بهم من أو إلى مكان قريب من مسرح الجريمة.'},
      {'name': 'نادل في مقهى قريب', 'job': 'نادل', 'description': 'سمع محادثة جانبية بين بعض المشتبه بهم قبل وقوع الجريمة.'},
      {'name': 'متدرب جديد', 'job': 'متدرب', 'description': 'شخصية جديدة في مكان العمل، متحمسة ولكنها قد تكون ساذجة أو تخفي شيئًا ما.'},
      {'name': 'حارس أمن المبنى المجاور', 'job': 'حارس أمن', 'description': 'لم يكن في الخدمة المباشرة، لكن كاميراته قد تكون التقطت شيئًا مفيدًا.'},
      {'name': 'متسوق في المتجر القريب', 'job': 'متسوق', 'description': 'رأى أحد المشتبه بهم يشتري أداة يمكن استخدامها في الجريمة.'},
      {'name': 'فني صيانة', 'job': 'فني', 'description': 'قام بإصلاحات في مكان الجريمة مؤخرًا ولديه معرفة بالمكان.'},
      {'name': 'مرشد سياحي', 'job': 'مرشد', 'description': 'كان مع مجموعة سياحية بالقرب من المكان ولاحظ شيئًا خارجًا عن المألوف.'},
      {'name': 'بائع متجول', 'job': 'بائع', 'description': 'يتواجد في نفس الشارع يوميًا ويعرف كل الوجوه المألوفة والغريبة.'},
      {'name': 'أحد أقارب الضحية', 'job': 'قريب', 'description': 'لم يتم ذكره في التحقيقات الأولية ولكن لديه دافع قوي متعلق بالميراث.'},
    ];

    allCharacters.shuffle();
    return allCharacters.take(count).toList();
  }

  Future<void> vote(String targetPlayerId) async {
    if (currentRoom == null || currentPlayer == null) return;
    
    final currentPhase = currentRoom!.currentPhase;
    final isFinalVote = currentPhase == 'final_voting';

    // Check general conditions
    if (currentRoom!.status != 'playing' || (currentPhase != 'voting' && !isFinalVote)) {
      return;
    }

    // Check player-specific conditions
    if (currentPlayer!.role == 'مضيف') {
      emit(GameError('المضيف لا يمكنه التصويت'));
      return;
    }
    // Allow dead players to vote ONLY in the final voting phase
    if (!currentPlayer!.isAlive && !isFinalVote) {
      emit(GameError('لا يمكن للاعبين الموتى التصويت'));
      return;
    }
    if (currentPlayer!.hasVoted) {
      emit(GameError('لقد قمت بالتصويت بالفعل'));
      return;
    }

    try {
      final playerRef = _database.child('rooms').child(currentRoom!.id).child('players');
      
      // Find the index of the player who is voting and the target player
      final voterIndex = currentRoom!.players.indexWhere((p) => p.id == currentPlayer!.id);
      final targetIndex = currentRoom!.players.indexWhere((p) => p.id == targetPlayerId);

      if (voterIndex == -1 || targetIndex == -1) {
        emit(GameError('لم يتم العثور على اللاعب'));
        return;
      }

      // Atomically update both players' data using a transaction
      await playerRef.runTransaction((Object? players) {
        // Firebase returns the data as a List<dynamic>
        var playersList = (players as List?)?.map((p) => Map<String, dynamic>.from(p as Map)).toList();

        if (playersList != null) {
          // Ensure we don't process a stale vote
          if (playersList[voterIndex]['hasVoted'] == true) {
            // This user has already voted, abort the transaction.
            return Transaction.abort();
          }

          // Increment votes for the target player
          int currentVotes = (playersList[targetIndex]['votes'] as int?) ?? 0;
          playersList[targetIndex]['votes'] = currentVotes + 1;

          // Mark the current player as having voted
          playersList[voterIndex]['hasVoted'] = true;
          
          return Transaction.success(playersList);
        }
        
        // If players list is null, abort.
        return Transaction.abort();
      });
      
      debugPrint('Vote cast by ${currentPlayer!.name} for player ID $targetPlayerId');

    } catch (e) {
      debugPrint('vote error: $e');
      emit(GameError('حدث خطأ أثناء التصويت: $e'));
    }
  }

  Future<void> endDiscussionPhase() async {
    if (currentRoom == null) return;
    try {
      // Reset votes and hasVoted status for all players before moving to the voting phase
      List<Map<String, dynamic>> updatedPlayers = currentRoom!.players.map((p) {
        var playerJson = p.toJson();
        playerJson['votes'] = 0;
        playerJson['hasVoted'] = false;
        return playerJson;
      }).toList();

      debugPrint('endDiscussionPhase: setting phase to voting and resetting votes');
      await _database.child('rooms').child(currentRoom!.id).update({
        'players': updatedPlayers,
        'currentPhase': 'voting',
        'timeLeft': 60, // 1 minute for voting
      });
    } catch (e) {
      emit(GameError('حدث خطأ أثناء الانتقال لمرحلة التصويت'));
    }
  }

  Future<void> endVotingPhase() async {
    if (currentRoom == null) return;
    _gameTimer?.cancel();

    try {
      final roomSnapshot = await _database.child('rooms').child(currentRoom!.id).get();
      if (!roomSnapshot.exists) return;
      final latestRoom = GameRoom.fromJson(Map<String, dynamic>.from(roomSnapshot.value as Map));

      Player? playerToEliminate;
      int maxVotes = 0;
      
      List<Player> livingPlayers = latestRoom.players.where((p) => p.isAlive && p.id != latestRoom.hostId).toList();

      for (var player in livingPlayers) {
        if (player.votes > maxVotes) {
          maxVotes = player.votes;
          playerToEliminate = player;
        } else if (player.votes == maxVotes && player.votes > 0) {
          playerToEliminate = null; // Tie, nobody gets eliminated
        }
      }

      String message;
      String? eliminatedPlayerId;

      if (playerToEliminate != null) {
        eliminatedPlayerId = playerToEliminate.id;
        message = 'تم إعدام ${playerToEliminate.characterName} بناءً على تصويت الأغلبية!';
        final updatedPlayers = latestRoom.players.map((p) {
          if (p.id == playerToEliminate!.id) {
            return p.copyWith(isAlive: false);
          }
          return p;
        }).toList();
        
        await _database.child('rooms').child(currentRoom!.id).update({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
        });
        
        livingPlayers = updatedPlayers.where((p) => p.isAlive && p.id != latestRoom.hostId).toList();

      } else {
        message = 'لم يتم التوصل إلى قرار حاسم. لا أحد سيُعدم اليوم.';
      }
      
      // Check for win/end conditions immediately after elimination
      bool gameHasEnded = await _checkWinConditions(livingPlayers, message);
      if (gameHasEnded) return;

      // If game hasn't ended, move to the reveal phase
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'reveal',
        'timeLeft': 15, // 15 seconds for reveal phase
        'phaseMessage': message,
        'lastEliminatedPlayerId': eliminatedPlayerId,
      });

      _startGameTimer();

    } catch (e) {
      emit(GameError('حدث خطأ في نهاية مرحلة التصويت: $e'));
    }
  }

  Future<bool> _checkWinConditions(List<Player> livingPlayers, String lastMessage) async {
    final mafiosoCount = livingPlayers.where((p) => p.role == 'مافيوسو').length;
    final civilianCount = livingPlayers.length - mafiosoCount;

    String? winner;
    String message;

    if (mafiosoCount == 0) {
      winner = 'المدنيون';
      message = '$lastMessage\n\nانتهت اللعبة! لقد نجح المدنيون في القضاء على كل المافيا.';
    } else if (mafiosoCount >= civilianCount) {
      winner = 'المافيا';
      message = '$lastMessage\n\nانتهت اللعبة! لقد سيطرت المافيا على المدينة.';
    } else {
      return false; // No winner yet
    }

    await _cleanupAndResetRoom(winner, message);
    return true;
  }

  Future<void> endDefensePhase() async {
    if (currentRoom == null) return;
    _gameTimer?.cancel();
    
    // Reset votes one last time for the final vote
    final playersWithResetVotes = currentRoom!.players.map((p) {
      return p.copyWith(votes: 0, hasVoted: false);
    }).toList();

    await _database.child('rooms').child(currentRoom!.id).update({
      'currentPhase': 'final_voting', // New phase for final vote
      'timeLeft': 60, // 60 seconds for the final vote
      'players': playersWithResetVotes.map((p) => p.toJson()).toList(),
      'phaseMessage': 'وقت التصويت الأخير! كل اللاعبين (بما فيهم من خرجوا) يصوتون الآن لتحديد الفائز.',
    });
    _startGameTimer();
  }

  Future<void> endFinalVotingPhase() async {
    if (currentRoom == null) return;
    _gameTimer?.cancel();

    try {
      final roomSnapshot = await _database.child('rooms').child(currentRoom!.id).get();
      if (!roomSnapshot.exists) return;
      final latestRoom = GameRoom.fromJson(Map<String, dynamic>.from(roomSnapshot.value as Map));

      Player? playerToEliminate;
      int maxVotes = -1;
      
      // Only the two defenders are eligible for elimination
      List<Player> defenders = latestRoom.players.where((p) => p.isAlive && p.id != latestRoom.hostId).toList();
      
      if (defenders.length == 2) {
        if (defenders[0].votes > defenders[1].votes) {
          playerToEliminate = defenders[0];
        } else if (defenders[1].votes > defenders[0].votes) {
          playerToEliminate = defenders[1];
        } else {
          // Tie, Mafioso wins by default in a 1v1 showdown tie.
          playerToEliminate = defenders.firstWhere((p) => p.role == 'مدني');
        }
      } else {
         // Should not happen, but as a fallback, Mafia wins
        await _checkWinConditions(defenders, "حدث خطأ غير متوقع في التصويت النهائي.");
        return;
      }
      
      final winnerPlayer = defenders.firstWhere((p) => p.id != playerToEliminate!.id);
      final winner = winnerPlayer.role == 'مافيوسو' ? 'المافيا' : 'المدنيون';
      final message = 'بعد المواجهة النهائية، تم إعدام ${playerToEliminate.characterName}. الفائز هو ${winnerPlayer.characterName}!';
      
      await _cleanupAndResetRoom(winner, message);

    } catch (e) {
      emit(GameError('حدث خطأ في نهاية التصويت النهائي: $e'));
    }
  }

  Future<void> _cleanupAndResetRoom(String winner, String message) async {
    if (currentRoom == null) return;
    _gameTimer?.cancel();
    final roomId = currentRoom!.id;

    try {
      // 1. Identify dummy players
      List<String> dummyPlayerIds = [];
      for (final player in currentRoom!.players) {
        if (player.id.startsWith('dummy_')) {
           dummyPlayerIds.add(player.id);
        } else {
          // Check the /users node for real players just in case
          final userSnap = await _database.child('users').child(player.id).get();
          if (userSnap.exists) {
            final userData = Map<String, dynamic>.from(userSnap.value as Map);
            if (userData['isDummy'] == true) {
              dummyPlayerIds.add(player.id);
            }
          }
        }
      }

      // تحديث إحصائيات كل لاعب حقيقي
      for (final player in currentRoom!.players) {
        if (!dummyPlayerIds.contains(player.id)) {
          final didWin = (winner == 'المافيا' && player.role == 'مافيوسو') || (winner == 'المدنيون' && player.role == 'مدني');
          await settingsCubit.incrementGameStats(userId: player.id, didWin: didWin);
        }
      }

      // 2. Delete dummy players from /users
      if (dummyPlayerIds.isNotEmpty) {
        print('Cleaning up ${dummyPlayerIds.length} dummy players...');
        Map<String, dynamic> updates = {};
        for (final id in dummyPlayerIds) {
          updates['/users/$id'] = null; // This is how you delete a node
        }
        await _database.update(updates);
        print('Cleanup complete.');
      }
      
      // 3. Update the room to ended state
      await _database.child('rooms').child(roomId).update({
        'status': 'ended',
        'currentPhase': 'ended',
        'isGameOver': true,
        'winner': winner,
        'phaseMessage': message,
        'players': currentRoom!.players.where((p) => !dummyPlayerIds.contains(p.id)).map((p) => p.toJson()).toList(),
      });

      // --- NEW: Save local snapshot before deletion ---
      lastRoomSnapshot = currentRoom!.copyWith(
        players: currentRoom!.players.where((p) => !dummyPlayerIds.contains(p.id)).toList(),
        status: 'ended',
        currentPhase: 'ended',
        isGameOver: true,
        winner: winner,
        phaseMessage: message,
      );

      // 4. After a delay, delete the entire room.
      // This will trigger the listener on all clients to clean up their state.
      Future.delayed(const Duration(seconds: 30), () {
        _database.child('rooms').child(roomId).remove();
      });

    } catch(e) {
      print("Error during cleanup: $e");
      // Fallback to just ending the game
      await _database.child('rooms').child(roomId).update({
        'status': 'ended',
        'currentPhase': 'ended',
        'isGameOver': true,
        'winner': winner,
        'phaseMessage': message,
      });
    }
  }

  Future<void> startNextRound() async {
    if (currentRoom == null) return;
    try {
      // تحقق أولاً: إذا انتهت الدلائل، فوز المافيا
      if (currentRoom!.currentRound >= currentRoom!.clues.length) {
        await _cleanupAndResetRoom('المافيا', 'نفدت الأدلة! لقد تمكنت المافيا من الإفلات بجرائمهم وفازوا باللعبة.');
        return;
      }
      final int duration = currentRoom?.discussionDuration ?? 300;
      int nextClueIndex = (currentRoom!.currentClueIndex + 1);
      if (nextClueIndex >= currentRoom!.clues.length) nextClueIndex = currentRoom!.clues.length - 1;
      debugPrint('startNextRound: moving to next round, round: \\${currentRoom!.currentRound + 1}, clue: \\${nextClueIndex}');
      await _database.child('rooms').child(currentRoom!.id).update({
        'currentPhase': 'discussion',
        'timeLeft': duration, // use chosen duration
        'currentRound': currentRoom!.currentRound + 1,
        'lastEliminatedPlayer': null,
        'currentClueIndex': nextClueIndex,
        'isFinalShowdown': false, // إعادة تعيين حالة المواجهة النهائية
      });
    } catch (e) {
      emit(GameError('حدث خطأ أثناء بدء الجولة التالية'));
    }
  }

  Future<void> addDummyPlayers(int count) async {
    if (currentRoom == null) return;
    for (int i = 0; i < count; i++) {
      try {
        String randomId = _database.push().key!;
        String dummyEmail = 'dummy_$randomId@mafioso.game';
        String dummyPassword = 'password'; // Simple password for dummy accounts

        // We don't need to create an auth user for dummies if they don't need to sign in.
        // We can just add them to the /users node and the room.
        
        final dummyUserId = 'dummy_$randomId';
        final dummyPlayer = Player(
          id: dummyUserId,
          name: 'لاعب وهمي ${randomId.substring(0, 4)}',
          avatar: _getRandomAvatar(),
          isAlive: true,
          role: 'TBD',
          hasVoted: false,
          votes: 0,
        );

        // Add to /users node with the isDummy flag
        await _database.child('users').child(dummyUserId).set({
          'uid': dummyUserId,
          'name': dummyPlayer.name,
          'email': dummyEmail,
          'avatar': dummyPlayer.avatar,
          'isDummy': true, // The important flag!
        });

        // Add to the room
        final updatedPlayers = List<Player>.from(currentRoom!.players)..add(dummyPlayer);
        await _database.child('rooms').child(currentRoom!.id).update({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
        });

      } catch (e) {
        print("Error adding dummy player: $e");
        // Handle error, maybe show a message to the user
      }
    }
  }

  void _listenToRoomUpdates(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _database.child('rooms').child(roomId)
        .onValue.listen((event) async {
      if (!event.snapshot.exists) {
        // If the room is deleted, clean up the user's state and go back to the initial state.
        await GameCubit.clearSavedPlayer();
        currentRoom = null;
        currentPlayer = null;
        _roomSubscription?.cancel();
        _gameTimer?.cancel();
        emit(GameInitial());
        return;
      }
      try {
        final newRoom = GameRoom.fromJson(
          Map<String, dynamic>.from(event.snapshot.value as Map)
        );
        currentRoom = newRoom; // Always update the current room

        // Try to find the current player in the updated player list.
        // This is important to get the latest state (e.g., isAlive).
        if (currentPlayer != null) {
          try {
            currentPlayer = newRoom.players.firstWhere((p) => p.id == currentPlayer!.id);
          } catch (e) {
            // Player is no longer in the room (e.g., kicked or left).
            // In this case, we might want to reset the player state.
            // For now, we'll keep the old player object to avoid nulling it out
            // during minor sync issues, but if the player is truly gone,
            // this could lead to stale data. A better approach might be needed
            // if players being removed is a regular occurrence.
            debugPrint('Could not find current player in updated room, player might have been removed.');
          }
        }
        
        // If currentPlayer is still null (e.g., after joining), try to find it again.
        if (currentPlayer == null) {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString('mafioso_player_id');
          if (savedId != null) {
            try {
              currentPlayer = newRoom.players.firstWhere((p) => p.id == savedId);
            } catch (e) {
              // Saved player not in the room.
              debugPrint('Saved player ID not found in the room.');
            }
          }
        }

        emit(GameRoomLoaded(newRoom, currentPlayer));
      } catch (e) {
        emit(GameError('حدث خطأ أثناء تحديث حالة الغرفة: $e'));
      }
    });
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (currentRoom == null || currentPlayer?.id != currentRoom?.hostId) {
        // Only the host updates the timer to prevent race conditions.
        // Other clients will simply listen for updates from Firebase.
        return;
      }

      try {
        // It's crucial for the host to work with the latest room data.
        final roomSnapshot = await _database.child('rooms').child(currentRoom!.id).get();
        if (!roomSnapshot.exists) {
          timer.cancel();
          return;
        }
        
        final latestRoom = GameRoom.fromJson(Map<String, dynamic>.from(roomSnapshot.value as Map));
        final timeLeft = latestRoom.timeLeft;
        final currentPhase = latestRoom.currentPhase;

        if (timeLeft > 0) {
          // If time is left, the host decrements it in Firebase.
          await _database.child('rooms').child(currentRoom!.id).update({'timeLeft': timeLeft - 1});
        } else {
          // If time is up, the host cancels the timer and triggers the next phase.
          timer.cancel();
          switch (currentPhase) {
            case 'discussion':
              await endDiscussionPhase();
              break;
            case 'voting':
              await endVotingPhase();
              break;
            case 'reveal':
              await endRevealPhase();
              break;
            case 'defense':
              await endDefensePhase();
              break;
            case 'final_voting':
              await endFinalVotingPhase();
              break;
          }
        }
      } catch (e) {
        print("Error in _startGameTimer: $e");
        // We don't cancel the timer on error, to allow it to recover on the next tick.
      }
    });
  }

  void stopGameTimer() {
    _gameTimer?.cancel();
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

  Future<void> sendChatMessage(String text, {required String senderId, required String senderName, required String avatar}) async {
    if (currentRoom == null) return;
    final message = {
      'senderId': senderId,
      'senderName': senderName,
      'avatar': avatar,
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

  Future<void> removePlayer(String playerId) async {
    if (currentRoom == null) return;
    // ... existing code ...
  }

  Future<void> endRevealPhase() async {
    if (currentRoom == null) return;
    _gameTimer?.cancel();
    
    // Fetch the latest room state
    final roomSnapshot = await _database.child('rooms').child(currentRoom!.id).get();
    if (!roomSnapshot.exists) return;
    final latestRoom = GameRoom.fromJson(Map<String, dynamic>.from(roomSnapshot.value as Map));
    
    final livingPlayers = latestRoom.players.where((p) => p.isAlive && p.id != latestRoom.hostId).toList();

    // Special Case: Final Showdown (2 players left, 1 mafioso, 1 civilian)
    if (livingPlayers.length == 2) {
      final mafiosoCount = livingPlayers.where((p) => p.role == 'مافيوسو').length;
      if (mafiosoCount == 1) {
        await _database.child('rooms').child(currentRoom!.id).update({
          'currentPhase': 'defense',
          'timeLeft': 60, // 60 seconds for defense phase
          'phaseMessage': 'المواجهة الأخيرة! كل لاعب لديه دقيقة للدفاع عن نفسه قبل التصويت النهائي من الجميع.',
          'lastEliminatedPlayerId': null, // Clear the eliminated player
        });
        _startGameTimer();
        return;
      }
    }

    // New Win Condition: Clues have run out
    if (latestRoom.currentRound >= latestRoom.clues.length) {
      await _cleanupAndResetRoom('المافيا', 'نفدت الأدلة! لقد تمكنت المافيا من الإفلات بجرائمهم وفازوا باللعبة.');
      return;
    }

    // Move to the next discussion round
    final playersWithResetVotes = latestRoom.players.map((p) {
      return p.copyWith(votes: 0, hasVoted: false);
    }).toList();

    await _database.child('rooms').child(currentRoom!.id).update({
      'currentPhase': 'discussion',
      'timeLeft': latestRoom.discussionDuration,
      'players': playersWithResetVotes.map((p) => p.toJson()).toList(),
      'phaseMessage': 'بدأت جولة جديدة من النقاش.',
      'lastEliminatedPlayerId': null, // Clear the eliminated player
      'currentRound': latestRoom.currentRound + 1,
      'currentClueIndex': latestRoom.currentRound, // Reveal next clue
    });

    _startGameTimer();
  }
}