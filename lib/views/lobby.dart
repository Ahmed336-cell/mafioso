import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../cubits/game_cubit.dart';
import '../models/player.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameRoomLoaded && state.room.status == 'playing') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(),
            ),
          );
        } else if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
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
              body: Center(child: Text('لا توجد غرفة محملة')),
            );
          }

          final room = state.room;
          final currentPlayer = state.currentPlayer;

          return Scaffold(
            appBar: AppBar(
              title: const Text('غرفة الانتظار'),
              centerTitle: true,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // رمز الغرفة مع Animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Card(
                        color: Colors.deepPurple.withValues(alpha: 0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'رمز الغرفة',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                              Text(
                                room.id,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white),
                                onPressed: () => _copyToClipboard(room.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // معلومات القضية
                    if (room.caseTitle.isNotEmpty)
                      Card(
                        color: Colors.orange.withValues(alpha: 0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                      ),

                    const SizedBox(height: 20),

                    // قائمة اللاعبين
                    Expanded(
                      child: Card(
                        color: Colors.white.withValues(alpha: 0.9),
                        child: ListView.builder(
                          itemCount: room.players.length,
                          itemBuilder: (context, index) {
                            return _buildPlayerCard(
                              room.players[index],
                              isHost: room.players[index].id == room.hostId,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // زر البدء (للمضيف فقط)
                    if (currentPlayer.id == room.hostId)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => context.read<GameCubit>().startGame(),
                        child: const Text('بدء اللعبة', style: TextStyle(fontSize: 20)),
                      ).animate().fadeIn().slideY(begin: 0.5, end: 0),

                    // زر إضافة لاعبين وهميين (للمضيف فقط)
                    if (currentPlayer.id == room.hostId && room.players.length < 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => context.read<GameCubit>().addDummyPlayers(1),
                          child: const Text('إضافة لاعب وهمي'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard(Player player, {bool isHost = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isHost ? Colors.amber : Colors.deepPurple,
          child: Text(
            player.avatar,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          player.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: isHost
            ? const Chip(
                label: Text('المضيف'),
                backgroundColor: Colors.amber,
                labelStyle: TextStyle(color: Colors.black),
              )
            : null,
      ),
    ).animate().fadeIn().slideX();
  }

  void _copyToClipboard(String text) {
    // In a real app, you would use Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الرمز: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }
}