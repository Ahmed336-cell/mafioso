import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/game_cubit.dart';
import 'lobby.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameRoomLoaded) {
          if (state.room.status == 'waiting') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LobbyScreen(),
              ),
            );
          } else if (state.room.status == 'playing') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(),
              ),
            );
          }
        } else if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // العنوان مع Animation
                Text(
                  'مافيوسو',
                  style: const TextStyle(
                    fontSize: 64,
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
                ).animate().slide(),

                const SizedBox(height: 50),

                // أزرار القائمة مع Animations متتالية
                _buildMenuButton(
                  context,
                  'إنشاء غرفة',
                  Icons.add,
                  Colors.deepPurple,
                  () => _showCreateRoomDialog(context),
                  delay: 200,
                ),

                _buildMenuButton(
                  context,
                  'الدخول إلى غرفة',
                  Icons.login,
                  Colors.blue,
                  () => _showJoinRoomDialog(context),
                  delay: 400,
                ),

                _buildMenuButton(
                  context,
                  'تسجيل الخروج',
                  Icons.logout,
                  Colors.red,
                  () => context.read<AuthCubit>().signOut(),
                  delay: 600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String text, IconData icon,
      Color color, VoidCallback onPressed, {int delay = 0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(text, style: const TextStyle(fontSize: 20)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
        ),
        onPressed: onPressed,
      ).animate().fadeIn(delay: Duration(milliseconds: delay)),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء غرفة جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم اللاعب',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                context.read<GameCubit>().createRoom(nameController.text);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final TextEditingController roomIdController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الدخول إلى غرفة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomIdController,
              decoration: const InputDecoration(
                labelText: 'رمز الغرفة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم اللاعب',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (roomIdController.text.isNotEmpty && nameController.text.isNotEmpty) {
                Navigator.pop(context);
                context.read<GameCubit>().joinRoom(roomIdController.text, nameController.text);
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }
}