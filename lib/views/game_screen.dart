import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/game_cubit.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import 'countdown_timer.dart';
import 'main_menu.dart';
import 'player_card.dart';
import 'story_reveal_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _timerController;
  late AnimationController _pulseController;
  final PageController _clueController = PageController();
  int? _lastTimeLeft;
  String? _lastPhase;
  String? _lastStatus;
  bool _showPhaseDialog = false;
  String _currentPhaseForDialog = '';
  bool _showStartCountdown = false;
  int _countdownNumber = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Initialize last known status and phase to correctly detect changes.
    final state = context.read<GameCubit>().state;
    if (state is GameRoomLoaded) {
      _lastStatus = state.room.status;
      _lastPhase = state.room.currentPhase;
      // If we are entering the game screen and the game is already in 'playing' state,
      // which means we just transitioned from the lobby after the game started.
      if (state.room.status == 'playing') {
        _showStartGameCountdown();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timerController.dispose();
    _pulseController.dispose();
    _clueController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showStartGameCountdown() {
    setState(() {
      _showStartCountdown = true;
      _countdownNumber = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1, milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownNumber--;
      });
      if (_countdownNumber < 0) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _showStartCountdown = false;
            });
          }
        });
      }
    });
  }

  void _updateTimerController(int seconds, String phase) {
    final duration = Duration(seconds: seconds);
    if (_timerController.duration != duration) {
      _timerController.duration = duration;
    }
    _timerController.reset();
    _timerController.forward();
    _lastTimeLeft = seconds;
    _lastPhase = phase;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameRoomLoaded) {
          // This logic is now moved to initState to only trigger on screen load.
          // if (_lastStatus == 'waiting' && state.room.status == 'playing') {
          //   _showStartGameCountdown();
          // }
          _lastStatus = state.room.status;

          if (state.room.isGameOver) {
            _showGameResultDialog(context, state.room);
          }

          final phase = state.room.currentPhase;
          final timeLeft = state.room.timeLeft;
          if (_lastTimeLeft != timeLeft || _lastPhase != phase) {
            _updateTimerController(timeLeft, phase);
            
            // Show phase dialog when phase changes
            if (_lastPhase != null && _lastPhase != phase) {
              _showPhaseAnnouncementDialog(phase);
            }
            _lastPhase = phase;
          }
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (context, state) {
          if (state is GameLoading) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('جاري تحميل اللعبة...', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 20),
                    CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple[400]!),
                    ).animate(
                      onPlay: (controller) => controller.repeat(),
                    ).rotate(duration: 1500.ms)
                  ],
                ),
              ),
            );
          }

          if (state is! GameRoomLoaded) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
                    const SizedBox(height: 20),
                    const Text('لا توجد لعبة محملة', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            );
          }

          final room = state.room;
          final currentPlayer = state.currentPlayer;
          final isSpectator = currentPlayer?.isAlive == false;
          final isHost = currentPlayer?.id == room.hostId;

          final hostPlayer = room.players.firstWhere((p) => p.role == 'مضيف', orElse: () => room.players.first);

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text('الجولة ${room.currentRound} - ${_getPhaseTitle(room.currentPhase)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple[800]!, Colors.deepPurple[600]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[400],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people, size: 18),
                          const SizedBox(width: 4),
                          Text('${room.alivePlayers.length}/${room.players.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ).animate(controller: _pulseController)
                        .scale(end: Offset(1.05, 1.05), curve: Curves.easeInOut),
                  ),
                ),

              ],
            ),
            body: Stack(
              children: [
                Container(
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
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isSpectator)
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red[900]!, Colors.red[700]!],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.visibility_off, color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'وضع المشاهدة فقط',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().shakeX(),

                            const SizedBox(height: 16),

                            // Case Card
                            _CaseCard(
                              title: room.caseTitle,
                              description: room.caseDescription,
                            ),

                            // Phase Timer Card
                            Card(
                              elevation: 8,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.deepPurple[800],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getPhaseIcon(room.currentPhase),
                                          color: Colors.amber,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _getPhaseTitle(room.currentPhase),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    CountdownTimer(
                                      duration: Duration(seconds: room.timeLeft),
                                      textStyle: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      onTimeUp: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Phase-specific content
                            if (room.currentPhase == 'reveal') ...[
                              const SizedBox(height: 24),
                              _buildRevealPhase(room),
                            ],

                            // Players Section
                            _buildSectionHeader(
                              icon: Icons.people,
                              title: 'اللاعبون',
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 8),
                            
                            // Host/Manager Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hostPlayer.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                        const Text(
                                          'مدير اللعبة',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Playing Players
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: room.players.where((p) => p.role != 'مضيف').length,
                              itemBuilder: (context, index) {
                                final playingPlayers = room.players.where((p) => p.role != 'مضيف').toList();
                                final player = playingPlayers[index];
                                return PlayerCard(
                                  player: player,
                                  isEliminated: !player.isAlive,
                                  onTap: () => _showPlayerDetails(context, player, currentPlayer!), myId: '',
                                ).animate(delay: (100 * index).ms).slideX(
                                  begin: 0.5,
                                  curve: Curves.easeOut,
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Clues Section
                            _buildSectionHeader(
                              icon: Icons.search,
                              title: 'الأدلة',
                              color: Colors.purpleAccent,
                            ),
                            const SizedBox(height: 12),
                            _buildCluesTab(room),

                            const SizedBox(height: 24),

                            // My Info Section
                            _buildSectionHeader(
                              icon: Icons.person,
                              title: 'معلوماتي',
                              color: Colors.tealAccent,
                            ),
                            const SizedBox(height: 12),
                            _buildMyInfoTab(currentPlayer!, room),

                            // Action Buttons
                            if (!isSpectator && currentPlayer!.role != 'مضيف') ...[
                              const SizedBox(height: 24),
                              _buildActionButtons(context, room, currentPlayer),
                            ],

                            // Host Controls
                            if (currentPlayer!.role == 'مضيف') ...[
                              const SizedBox(height: 24),
                              _buildHostControls(context, room, currentPlayer),
                            ],

                            // Skip Button
                            if (isHost) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'أدوات المدير',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.skip_next),
                                      label: Text('تخطي ${_getPhaseTitle(room.currentPhase)}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      onPressed: () {
                                        // Show confirmation dialog
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: Colors.blueGrey[900],
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              side: BorderSide(color: Colors.orange[300]!, width: 2),
                                            ),
                                            title: Row(
                                              children: [
                                                Icon(Icons.warning, color: Colors.orange[300]),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'تأكيد التخطي',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              'هل تريد تخطي ${_getPhaseTitle(room.currentPhase)}؟',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  context.read<GameCubit>().skipPhase();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('تم تخطي ${_getPhaseTitle(room.currentPhase)}'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('تأكيد'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildPhaseAnnouncementDialog(),
                _buildStartCountdownOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase) {
      case 'discussion':
        return Icons.forum;
      case 'voting':
        return Icons.how_to_vote;
      case 'reveal':
        return Icons.visibility;
      case 'defense':
        return Icons.gavel;
      default:
        return Icons.timer;
    }
  }

  String _getPhaseTitle(String phase) {
    switch (phase) {
      case 'discussion':
        return 'مرحلة النقاش';
      case 'voting':
        return 'مرحلة التصويت';
      case 'reveal':
        return 'كشف النتائج';
      case 'defense':
        return 'مرحلة الدفاع';
      default:
        return 'انتظار';
    }
  }

  Widget _buildCluesTab(GameRoom room) {
    if (room.clues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Text(
            'لا توجد أدلة متاحة بعد',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
      );
    }

    final clueIndex = room.currentClueIndex < room.clues.length ? room.currentClueIndex : room.clues.length - 1;
    final clueColors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.amberAccent,
    ];
    final color = clueColors[clueIndex % clueColors.length];

    return GestureDetector(
      onTap: () => _animateClueCard(),
      child: AnimatedContainer(
        duration: 500.ms,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tips_and_updates, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  'دليل الجولة ${room.currentRound}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                room.clues[clueIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ).animate().flipH(delay: 300.ms),
    );
  }

  void _animateClueCard() {
    setState(() {
      // Trigger animation by rebuilding with a key change
    });
  }

  Widget _buildMyInfoTab(Player currentPlayer, GameRoom room) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player Avatar and Basic Info
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentPlayer.role == 'مافيوسو' ? Colors.red : Colors.green,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.deepPurple[800],
                  child: Text(
                    currentPlayer.avatar,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPlayer.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentPlayer.role == 'مافيوسو'
                            ? Colors.red[900]
                            : Colors.green[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentPlayer.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Character Info
          if (currentPlayer.characterName.isNotEmpty) ...[
            const Text(
              'معلومات الشخصية:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الاسم: ${currentPlayer.characterName}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الوصف: ${currentPlayer.characterDescription}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'علاقتك بالضحية: ${currentPlayer.relationshipToVictim}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'دفاعك: ${currentPlayer.alibi}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GameRoom room, Player currentPlayer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (room.currentPhase == 'voting')
          _buildVoteButton(room),

        if (room.currentPhase == 'discussion')
          _buildChatButton(context, room, currentPlayer),
      ],
    );
  }

  Widget _buildVoteButton(GameRoom room) {
    final currentPlayer = room.players.firstWhere((p) => p.id == context.read<GameCubit>().currentPlayer!.id);
    final canVote = (currentPlayer.isAlive && !room.defensePlayers.contains(currentPlayer.id)) || room.isFinalShowdown;
    
    // Check if current player is civilian and show warning if they're about to vote for wrong person
    bool showWarning = false;
    if (currentPlayer.role == 'مدني' && room.currentPhase == 'voting') {
      showWarning = true;
    }
    
    // Get wrong votes count for this round
    int wrongVotesCount = room.wrongVotesByCivilians.length;
    
    return Column(
      children: [
        if (showWarning)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'تأكد من اختيارك!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ).animate().shakeX(duration: 600.ms).then().shakeX(duration: 600.ms),
        
        // Show wrong votes count if any
        if (wrongVotesCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$wrongVotesCount تصويت خاطئ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ).animate().scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms).then().scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), duration: 800.ms),
        
        ElevatedButton.icon(
          icon: Icon(room.isFinalShowdown ? Icons.gavel : Icons.how_to_vote),
          label: Text(room.isFinalShowdown ? 'تصويت نهائي' : 'صوّت الآن'),
          style: ElevatedButton.styleFrom(
            backgroundColor: canVote ? (room.isFinalShowdown ? Colors.red[700] : Colors.deepPurple) : Colors.grey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: canVote ? () => _showVoteDialog(room) : null,
        ),
      ],
    );
  }

  void _showVoteDialog(GameRoom room) {
    final currentPlayer = room.players.firstWhere((p) => p.id == context.read<GameCubit>().currentPlayer!.id);
    final canVote = currentPlayer.isAlive || room.isFinalShowdown;

    if (!canVote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن للموتى التصويت')),
      );
      return;
    }

    List<Player> voteTargets;
    if (room.isFinalShowdown) {
      voteTargets = room.players.where((p) => room.defensePlayers.contains(p.id)).toList();
    } else if (room.defensePlayers.isNotEmpty) {
      voteTargets = room.players.where((p) => room.defensePlayers.contains(p.id)).toList();
    } else {
      voteTargets = room.alivePlayers.where((p) => p.id != currentPlayer.id).toList();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: room.isFinalShowdown ? Colors.red[700]! : Colors.deepPurple[300]!, width: 2),
        ),
        title: Column(
          children: [
            Text(
              room.isFinalShowdown ? 'المواجهة النهائية' : 'اختر لاعبًا للتصويت عليه',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (currentPlayer.role == 'مدني')
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  '⚠️ فكر جيداً قبل التصويت',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Show wrong votes statistics
            if (room.wrongVotesByCivilians.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  '❌ ${room.wrongVotesByCivilians.length} تصويت خاطئ في هذه الجولة',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: voteTargets.length,
            itemBuilder: (context, index) {
              final player = voteTargets[index];
              final isWrongVote = currentPlayer.role == 'مدني' && room.wrongVotesByCivilians.any((vote) => vote.targetId == player.id);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isWrongVote ? Colors.red : Colors.deepPurple,
                  child: Text(player.avatar, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(
                  player.name, 
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isWrongVote ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: player.characterName.isNotEmpty
                    ? Text(
                        player.characterName, 
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: isWrongVote ? FontWeight.bold : FontWeight.normal,
                        ),
                      )
                    : null,
                trailing: currentPlayer.role == 'مدني' 
                    ? Icon(
                        isWrongVote ? Icons.error : Icons.help_outline, 
                        color: isWrongVote ? Colors.red : Colors.orange,
                      )
                    : null,
                onTap: () {
                  context.read<GameCubit>().vote(player.id);
                  Navigator.pop(context);
                  
                  // Show feedback for civilian voting
                  if (currentPlayer.role == 'مدني') {
                    _showVoteFeedback(context, player, isWrongVote);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showVoteFeedback(BuildContext context, Player votedPlayer, bool isWrongVote) {
    // Show a brief feedback message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWrongVote ? Icons.error : Icons.info_outline, 
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isWrongVote 
                ? '❌ تصويت خاطئ على ${votedPlayer.name}'
                : 'تم التصويت على ${votedPlayer.name}',
            ),
          ],
        ),
        backgroundColor: isWrongVote ? Colors.red[700] : Colors.blue[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: isWrongVote ? SnackBarAction(
          label: 'تأكد',
          textColor: Colors.white,
          onPressed: () {
            // Could show more detailed feedback here
          },
        ) : null,
      ),
    );
  }

  Widget _buildChatButton(BuildContext context, GameRoom room, Player currentPlayer) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.chat),
      label: const Text('فتح الدردشة'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 8,
        shadowColor: Colors.deepPurple.withOpacity(0.5),
      ),
      onPressed: () => _showChatBottomSheet(context, room, currentPlayer),
    );
  }

  void _showPlayerDetails(BuildContext context, Player player, Player currentPlayer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: player.isAlive ? Colors.deepPurple[300]! : Colors.grey[700]!, width: 2),
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: currentPlayer.id == player.id
                      ? (player.role == 'مافيوسو' ? Colors.red : Colors.green)
                      : Colors.deepPurple,
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.deepPurple[800],
                child: Text(player.avatar, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            if (!player.isAlive)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.do_not_disturb_sharp, color: Colors.red, size: 22),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (player.characterDescription.isNotEmpty) ...[
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              const Text('وصف الشخصية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(player.characterDescription, style: const TextStyle(color: Colors.white70)),
            ],
            if (currentPlayer.id == player.id) ...[
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              const Text('دورك الحقيقي:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(
                player.role,
                style: TextStyle(
                  color: player.role == 'مافيوسو' ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showGameResultDialog(BuildContext context, GameRoom room) {
    // Find the mafioso player
    final mafiosoPlayer = room.players.firstWhere(
      (p) => p.role == 'مافيوسو',
      orElse: () => Player(id: '', name: 'المافيوسو', role: 'مافيوسو', avatar: '🎭'),
    );

    // Navigate to story reveal screen instead of showing dialog
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => StoryRevealScreen(
          room: room,
          mafiosoPlayer: mafiosoPlayer,
        ),
      ),
      (route) => false,
    );
  }

  void _showChatBottomSheet(BuildContext context, GameRoom room, Player currentPlayer) {
    final chatRef = FirebaseDatabase.instance.ref().child('rooms').child(room.id).child('chatMessages');
    final scrollController = ScrollController();
    final isDiscussion = room.currentPhase == 'discussion';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        TextEditingController msgController = TextEditingController();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, _) {
            return Column(
              children: [
                Container(
                  width: 60,
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Text(
                  'محادثة النقاش',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<DatabaseEvent>(
                    stream: chatRef.orderByChild('timestamp').onValue,
                    builder: (context, snapshot) {
                      List<Map<String, dynamic>> messages = [];
                      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        messages = data.entries.map((e) => Map<String, dynamic>.from(e.value)).toList();
                        messages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['senderId'] == currentPlayer.id;
                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 400),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      backgroundColor: Colors.deepPurple[100],
                                      child: Text(msg['avatar'] ?? '', style: const TextStyle(fontSize: 20)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg['senderName'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMe ? Colors.blue[700] : Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: isMe ? Colors.blue[400] : Colors.grey[300],
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 18),
                                            ),
                                          ),
                                          child: Text(
                                            msg['text'] ?? '',
                                            style: TextStyle(
                                              color: isMe ? Colors.white : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now()),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(msg['avatar'] ?? '', style: const TextStyle(fontSize: 20)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: msgController,
                              enabled: isDiscussion,
                              decoration: InputDecoration(
                                hintText: isDiscussion ? 'اكتب رسالتك...' : 'الدردشة متاحة فقط أثناء النقاش',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.deepPurple),
                            onPressed: isDiscussion
                                ? () {
                                    final text = msgController.text.trim();
                                    if (text.isNotEmpty) {
                                      context.read<GameCubit>().sendChatMessage(
                                        text,
                                        senderId: currentPlayer.id,
                                        senderName: currentPlayer.name,
                                        avatar: currentPlayer.avatar,
                                      );
                                      msgController.clear();
                                    }
                                  }
                                : null,
                          )
                        ],
                      ),
                      if (!isDiscussion)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'الدردشة متاحة فقط أثناء مرحلة النقاش',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRevealPhase(GameRoom room) {
    final eliminatedPlayer = room.lastEliminatedPlayer != null
        ? room.players.firstWhere((p) => p.id == room.lastEliminatedPlayer)
        : null;

    if (eliminatedPlayer == null) return const SizedBox.shrink();

    // Check if this was a wrong vote (eliminated player was civilian)
    bool wasWrongVote = eliminatedPlayer.role == 'مدني';
    int wrongVotesCount = room.wrongVotesByCivilians.length;

    return Column(
      children: [
        // Wrong vote warning
        if (wasWrongVote)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'تصويت خاطئ!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تم إقصاء مدني بريء',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 14,
                  ),
                ),
                if (wrongVotesCount > 0)
                  Text(
                    '$wrongVotesCount تصويت خاطئ في هذه الجولة',
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ).animate().shakeX(duration: 600.ms).then().shakeX(duration: 600.ms),
        
        // Eliminated player card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: wasWrongVote ? Colors.red.withOpacity(0.1) : Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: wasWrongVote ? Colors.red : Colors.grey[600]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                wasWrongVote ? '❌ تم إقصاء مدني بريء' : 'تم إقصاء لاعب',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: wasWrongVote ? Colors.red : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 40,
                backgroundColor: wasWrongVote ? Colors.red[900] : Colors.grey[700],
                child: Text(
                  eliminatedPlayer.avatar,
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                eliminatedPlayer.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (eliminatedPlayer.characterName.isNotEmpty)
                Text(
                  eliminatedPlayer.characterName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: wasWrongVote ? Colors.red[900] : Colors.grey[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  eliminatedPlayer.role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Game status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'اللاعبون المتبقون: ${room.alivePlayers.length}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPlayerCount('مدنيين', room.alivePlayers.where((p) => p.role == 'مدني').length, Colors.green),
                  _buildPlayerCount('مافيوسو', room.alivePlayers.where((p) => p.role == 'مافيوسو').length, Colors.red),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDefensePhase(GameRoom room, Player currentPlayer) {
    final isDefender = room.defensePlayers.contains(currentPlayer.id);
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: isDefender
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'دورك للدفاع! لديك 30 ثانية لكتابة دفاعك.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CountdownTimer(
                    duration: const Duration(seconds: 30),
                    onTimeUp: () {}, textStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                  ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'اكتب دفاعك هنا... (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'اللاعبون المتعادلون يدافعون الآن... الرجاء  الانتظار',
                    style: TextStyle(fontSize: 20, color: Colors.deepPurple),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CountdownTimer(
                    duration: const Duration(seconds: 30),
                    onTimeUp: () {}, textStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                  ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHostControls(BuildContext context, GameRoom room, Player currentPlayer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'أدوات المدير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.info),
            label: const Text('معلومات اللعبة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _showGameInfo(context, room);
            },
          ),
          if (room.currentPhase == 'discussion') ...[
            const SizedBox(height: 12),
            _buildChatButton(context, room, currentPlayer),
          ],
        ],
      ),
    );
  }

  void _showGameInfo(BuildContext context, GameRoom room) {
    final playingPlayers = room.players.where((p) => p.role != 'مضيف').toList();
    final alivePlayers = playingPlayers.where((p) => p.isAlive).toList();
    final mafiosoCount = playingPlayers.where((p) => p.role == 'مافيوسو').length;
    final civilianCount = playingPlayers.where((p) => p.role == 'مدني').length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber[300]!, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.amber[300]),
            const SizedBox(width: 8),
            const Text(
              'معلومات اللعبة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي اللاعبين: ${playingPlayers.length}', style: const TextStyle(color: Colors.white)),
            Text('اللاعبون الأحياء: ${alivePlayers.length}', style: const TextStyle(color: Colors.white)),
            Text('عدد المافيا: $mafiosoCount', style: const TextStyle(color: Colors.red)),
            Text('عدد المدنيين: $civilianCount', style: const TextStyle(color: Colors.blue)),
            Text('الجولة الحالية: ${room.currentRound}', style: const TextStyle(color: Colors.white)),
            Text('المرحلة: ${_getPhaseTitle(room.currentPhase)}', style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showPhaseAnnouncementDialog(String phase) {
    setState(() {
      _showPhaseDialog = true;
      _currentPhaseForDialog = phase;
    });

    // Auto-hide dialog after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showPhaseDialog = false;
        });
      }
    });
  }

  Widget _buildPhaseAnnouncementDialog() {
    if (!_showPhaseDialog) return const SizedBox.shrink();

    final phaseInfo = _getPhaseInfo(_currentPhaseForDialog);
    
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                phaseInfo['color'].withOpacity(0.9),
                phaseInfo['color'].withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: phaseInfo['color'].withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with pulse animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  phaseInfo['icon'],
                  size: 48,
                  color: Colors.white,
                ),
              ).animate()
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 600.ms)
                .then()
                .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
              
              const SizedBox(height: 20),
              
              // Phase title
              Text(
                phaseInfo['title'],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(duration: 800.ms, delay: 300.ms)
                .slideY(begin: 0.5, end: 0, duration: 800.ms, delay: 300.ms),
              
              const SizedBox(height: 12),
              
              // Phase description
              Text(
                phaseInfo['description'],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(duration: 800.ms, delay: 600.ms)
                .slideY(begin: 0.5, end: 0, duration: 800.ms, delay: 600.ms),
              
              const SizedBox(height: 20),
              
              // Progress indicator
              SizedBox(
                width: 100,
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ).animate()
                .fadeIn(duration: 500.ms, delay: 900.ms)
                .scaleX(begin: 0, end: 1, duration: 2000.ms, delay: 900.ms),
            ],
          ),
        ),
      ).animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms),
    );
  }

  Map<String, dynamic> _getPhaseInfo(String phase) {
    switch (phase) {
      case 'discussion':
        return {
          'title': 'مرحلة النقاش',
          'description': 'حان وقت النقاش والتحليل\nاستخدم الدردشة لمناقشة الأدلة والشكوك',
          'icon': Icons.forum,
          'color': Colors.blue,
        };
      case 'voting':
        return {
          'title': 'مرحلة التصويت',
          'description': 'صوّت على اللاعب الذي تعتقد أنه المافيا\nفكر جيداً قبل اختيارك',
          'icon': Icons.how_to_vote,
          'color': Colors.red,
        };
      case 'reveal':
        return {
          'title': 'كشف النتائج',
          'description': 'سيتم كشف هوية اللاعب المُقصى\nوشاهد نتيجة التصويت',
          'icon': Icons.visibility,
          'color': Colors.purple,
        };
      case 'defense':
        return {
          'title': 'مرحلة الدفاع',
          'description': 'اللاعبون المتعادلون يدافعون عن أنفسهم\nاستمع جيداً لدفاعهم',
          'icon': Icons.gavel,
          'color': Colors.orange,
        };
      default:
        return {
          'title': 'انتظار',
          'description': 'في انتظار بدء المرحلة التالية',
          'icon': Icons.timer,
          'color': Colors.grey,
        };
    }
  }

  void _showLeaveGameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red[300]!, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red[300]),
            const SizedBox(width: 8),
            const Text(
              'تأكيد الخروج',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد أنك تريد الخروج من اللعبة؟\nسيتم حذف معلوماتك من الغرفة.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<GameCubit>().leaveRoom();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCountdownOverlay() {
    if (!_showStartCountdown) return const SizedBox.shrink();

    String text;
    if (_countdownNumber > 0) {
      text = _countdownNumber.toString();
    } else {
      text = 'انطلق!';
    }
    
    if (_countdownNumber < 0) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Text(
            text,
            key: ValueKey<String>(text),
            style: TextStyle(
              fontSize: 150,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              shadows: [
                Shadow(
                  blurRadius: 30,
                  color: Colors.amber.withOpacity(0.8),
                  offset: const Offset(0, 0),
                ),
                const Shadow(
                  blurRadius: 10,
                  color: Colors.black,
                  offset: Offset(4, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _CaseCard extends StatefulWidget {
  final String title;
  final String description;

  const _CaseCard({required this.title, required this.description});

  @override
  State<_CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<_CaseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey[800],
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.book_outlined, color: Colors.amber[600]),
                      const SizedBox(width: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.2,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

class _CountdownPainter extends CustomPainter {
  final Animation<double> animation;
  final Color backgroundColor;
  final Color color;

  _CountdownPainter({
    required this.animation,
    required this.backgroundColor,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(size.center(Offset.zero), size.width / 2.0, paint);
    paint.color = color;
    double progress = (1.0 - animation.value) * 2 * 3.1415926535;
    canvas.drawArc(Offset.zero & size, 3.1415926535 * 1.5, -progress, false, paint);
  }

  @override
  bool shouldRepaint(_CountdownPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value ||
        color != oldDelegate.color ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}