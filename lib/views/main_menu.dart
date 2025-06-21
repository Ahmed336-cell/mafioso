import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mafioso/cubits/auth_state.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/game_cubit.dart';
import 'auth/login_screen.dart';
import 'lobby.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenuScreen> {
  bool _hasSavedRoom = false;

  @override
  void initState() {
    super.initState();
    _checkForSavedRoom();
  }

  Future<void> _checkForSavedRoom() async {
    final hasRoom = await GameCubit.hasSavedRoom();
    if (mounted) {
      setState(() {
        _hasSavedRoom = hasRoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: _handleGameStateChanges,
      child: Scaffold(
        body: Container(
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
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'مافيوسو',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3, end: 0),
                    const SizedBox(height: 60),
                    ..._buildMenuButtons(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleGameStateChanges(BuildContext context, GameState state) {
    if (state is GameRoomLoaded) {
      if (state.room.status == 'waiting') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LobbyScreen()),
          (route) => false,
        );
      } else if (state.room.status == 'playing') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
          (route) => false,
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
  }

  List<Widget> _buildMenuButtons(BuildContext context) {
    final buttons = [
      _buildMenuButton(
        context,
        'إنشاء غرفة',
        Icons.add_circle,
        Colors.green,
        () => _showCreateRoomDialog(context),
        delay: 300,
      ),
      _buildMenuButton(
        context,
        'الدخول إلى غرفة',
        Icons.login,
        Colors.blue,
        () => _showJoinRoomDialog(context),
        delay: 400,
      ),
    ];

    // إضافة زر إعادة الانضمام فقط إذا كان متاحاً
    if (_hasSavedRoom) {
      buttons.add(
        _buildMenuButton(
          context,
          'إعادة الانضمام',
          Icons.refresh,
          Colors.orange,
          () => _rejoinRoom(context),
          delay: 500,
        ),
      );
    }

    buttons.addAll([
      _buildMenuButton(
        context,
        'الإعدادات',
        Icons.settings,
        Colors.teal,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ),
        delay: _hasSavedRoom ? 600 : 500,
      ),
      _buildMenuButton(
        context,
        'تسجيل الخروج',
        Icons.logout,
        Colors.red,
        () => context.read<AuthCubit>().signOut(),
        delay: _hasSavedRoom ? 700 : 600,
      ),
    ]);

    return buttons;
  }

  Widget _buildMenuButton(
      BuildContext context,
      String text,
      IconData icon,
      Color color,
      VoidCallback onPressed, {
        int delay = 0,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(text, style: const TextStyle(fontSize: 20)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
        onPressed: () {
          //AudioService().playButtonClick();
          onPressed();
        },
      ).animate().fadeIn(delay: Duration(milliseconds: delay)),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    // Get the current user's name for room name
    final authState = context.read<AuthCubit>().state;
    String roomName = 'غرفة جديدة';
    
    if (authState is AuthSuccess) {
      final userName = authState.user.displayName ?? authState.user.email?.split('@')[0] ?? 'لاعب';
      roomName = 'غرفة $userName';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.deepPurple[300]!, width: 2),
        ),
        title: const Text(
          'إنشاء غرفة جديدة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سيتم إنشاء غرفة باسم:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              roomName,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GameCubit>().createRoom(roomName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final TextEditingController roomIdController = TextEditingController();
    final List<TextEditingController> pinControllers =
    List.generate(6, (_) => TextEditingController());

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => Container(
                width: 36,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: pinControllers[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (val.length == 1 && i < 5) {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              )),
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
              final pin = pinControllers.map((c) => c.text).join();
              if (roomIdController.text.trim().isNotEmpty && pin.length == 6) {
                Navigator.pop(context);
                context.read<GameCubit>().joinRoom(
                  roomIdController.text.trim(),
                  pin: pin,
                );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  void _rejoinRoom(BuildContext context) async {
    try {
      context.read<GameCubit>().rejoinRoom();
      await _checkForSavedRoom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إعادة الانضمام: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}