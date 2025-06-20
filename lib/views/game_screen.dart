import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/game_cubit.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import 'countdown_timer.dart';
import 'player_card.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _timerController;
  final PageController _clueController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timerController.dispose();
    _clueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameRoomLoaded && state.room.isGameOver) {
          _showGameResultDialog(context, state.room);
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (context, state) {
          if (state is GameLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is! GameRoomLoaded) {
            return const Scaffold(
              body: Center(child: Text('لا توجد لعبة محملة')),
            );
          }

          final room = state.room;
          final currentPlayer = state.currentPlayer;

          return Scaffold(
            appBar: AppBar(
              title: Text('الجولة ${room.currentRound} - ${_getPhaseTitle(room.currentPhase)}'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'اللاعبين', icon: Icon(Icons.people)),
                  Tab(text: 'الأدلة', icon: Icon(Icons.search)),
                  Tab(text: 'معلوماتي', icon: Icon(Icons.person)),
                ],
              ),
            ),
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // تبويب اللاعبين
                  _buildPlayersTab(room, currentPlayer),

                  // تبويب الأدلة
                  _buildCluesTab(room),

                  // تبويب معلوماتي
                  _buildMyInfoTab(currentPlayer, room),
                ],
              ),
            ),
            floatingActionButton: room.currentPhase == 'voting' ? _buildVoteButton(room) : null,
          );
        },
      ),
    );
  }

  String _getPhaseTitle(String phase) {
    switch (phase) {
      case 'discussion':
        return 'النقاش';
      case 'voting':
        return 'التصويت';
      case 'reveal':
        return 'كشف النتيجة';
      case 'defense':
        return 'الدفاع';
      default:
        return 'انتظار';
    }
  }

  Widget _buildPlayersTab(GameRoom room, Player currentPlayer) {
    return Column(
      children: [
        // مؤقت العد التنازلي
        Container(
          padding: const EdgeInsets.all(16),
          child: CountdownTimer(
            duration: Duration(seconds: room.timeLeft),
            onTimeUp: () {
              // Handle time up
            },
          ),
        ),

        // معلومات القضية
        if (room.currentPhase == 'discussion')
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'القضية: ${room.caseTitle}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  room.caseDescription,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

        // قائمة اللاعبين
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: room.players.length,
            itemBuilder: (context, index) {
              final player = room.players[index];
              return PlayerCard(
                player: player,
                isEliminated: !player.isAlive,
                onTap: () => _showPlayerDetails(context, player, currentPlayer),
              );
            },
          ),
        ),

        // أزرار التحكم
        if (room.currentPhase == 'discussion' && currentPlayer.id == room.hostId)
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => context.read<GameCubit>().endDiscussionPhase(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('إنهاء النقاش والانتقال للتصويت'),
            ),
          ),
      ],
    );
  }

  Widget _buildCluesTab(GameRoom room) {
    if (room.clues.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أدلة متاحة',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return PageView.builder(
      controller: _clueController,
      itemCount: room.clues.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(20),
          color: Colors.white.withValues(alpha: 0.9),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'دليل ${index + 1}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    room.clues[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
        ).animate().flipH(delay: Duration(milliseconds: index * 200));
      },
    );
  }

  Widget _buildMyInfoTab(Player currentPlayer, GameRoom room) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات اللاعب
          Card(
            color: Colors.white.withValues(alpha: 0.9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      currentPlayer.avatar,
                      style: const TextStyle(fontSize: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentPlayer.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'دورك: ${currentPlayer.role}',
                    style: TextStyle(
                      fontSize: 18,
                      color: currentPlayer.role == 'مافيوسو' ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // معلومات الشخصية
          if (currentPlayer.characterName.isNotEmpty)
            Card(
              color: Colors.white.withValues(alpha: 0.9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'شخصيتك: ${currentPlayer.characterName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentPlayer.characterDescription,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'علاقتك بالضحية:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(currentPlayer.relationshipToVictim),
                    const SizedBox(height: 16),
                    Text(
                      'دفاعك:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(currentPlayer.alibi),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // إحصائيات اللعبة
          Card(
            color: Colors.white.withValues(alpha: 0.9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إحصائيات اللعبة',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('الجولة: ${room.currentRound}'),
                  Text('المرحلة: ${_getPhaseTitle(room.currentPhase)}'),
                  Text('اللاعبين الأحياء: ${room.alivePlayers.length}'),
                  Text('اللاعبين الموتى: ${room.deadPlayers.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteButton(GameRoom room) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _timerController,
        curve: const Interval(0.8, 1, curve: Curves.easeInOut),
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showVotingDialog(context, room),
        icon: const Icon(Icons.how_to_vote),
        label: const Text('التصويت الآن'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPlayerDetails(BuildContext context, Player player, Player currentPlayer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(player.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple,
              child: Text(
                player.avatar,
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text('الحالة: ${player.isAlive ? "حي" : "ميت"}'),
            if (player.characterName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('الشخصية: ${player.characterName}'),
              Text(player.characterDescription),
            ],
            if (currentPlayer.id == player.id)
              Text('دورك: ${player.role}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showVotingDialog(BuildContext context, GameRoom room) {
    final List<Player> alivePlayers = room.players.where((p) => p.isAlive).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لاعب للتصويت عليه'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alivePlayers.length,
            itemBuilder: (context, index) {
              final player = alivePlayers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(player.avatar),
                ),
                title: Text(player.name),
                subtitle: player.characterName.isNotEmpty ? Text(player.characterName) : null,
                onTap: () {
                  context.read<GameCubit>().vote(player.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showGameResultDialog(BuildContext context, GameRoom room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          room.winner == 'مافيوسو' ? 'فوز المافيوسو!' : 'فوز المدنيين!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: room.winner == 'مافيوسو' ? Colors.red : Colors.green,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              room.winner == 'مافيوسو' 
                ? 'تمكن المافيوسو من البقاء مخفياً حتى النهاية!'
                : 'تمكن المدنيون من اكتشاف المافيوسو!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'اللاعبين الأحياء:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...room.alivePlayers.map((player) => ListTile(
              leading: CircleAvatar(
                backgroundColor: player.role == 'مافيوسو' ? Colors.red : Colors.green,
                child: Text(player.avatar),
              ),
              title: Text(player.name),
              subtitle: Text('${player.role} - ${player.characterName}'),
            )),
            const SizedBox(height: 10),
            Text(
              'اللاعبين الموتى:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...room.deadPlayers.map((player) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey,
                child: Text(player.avatar),
              ),
              title: Text(player.name),
              subtitle: Text('${player.role} - ${player.characterName}'),
            )),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to main menu
            },
            child: const Text('العودة للقائمة الرئيسية'),
          ),
        ],
      ),
    );
  }
}