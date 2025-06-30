import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import 'main_menu.dart';
import '../cubits/game_cubit.dart';

class StoryRevealScreen extends StatefulWidget {
  final GameRoom room;
  final Player mafiosoPlayer;

  const StoryRevealScreen({
    super.key,
    required this.room,
    required this.mafiosoPlayer,
  });

  @override
  State<StoryRevealScreen> createState() => _StoryRevealScreenState();
}

class _StoryRevealScreenState extends State<StoryRevealScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _textController;
  late AnimationController _imageController;
  late AnimationController _pulseController;
  
  bool _showStory = false;
  bool _showConfession = false;
  int _currentTextIndex = 0;
  
  final List<String> _storyParts = [
    'في ذلك المساء المظلم...',
    'كان الجميع يعتقدون أنهم يعرفون الحقيقة...',
    'لكن الحقيقة كانت مختبئة خلف قناع البراءة...',
    'المافيوسو كان بينهم طوال الوقت...',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _imageController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _startStorySequence();
  }

  void _startStorySequence() async {
    _fadeController.forward();
    
    for (int i = 0; i < _storyParts.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _currentTextIndex = i;
      });
      _textController.reset();
      _textController.forward();
    }
    
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _showStory = true;
    });
    _imageController.forward();
    
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _showConfession = true;
    });
    
    // Start pulse animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    _imageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Player get _mafiosoPlayer {
    // Try to get mafioso from current room, else from snapshot
    final players = widget.room.players.isNotEmpty
        ? widget.room.players
        : (GameCubit.getLastRoomSnapshot()?.players ?? []);
    return players.firstWhere(
      (p) => p.role == 'مافيوسو',
      orElse: () => Player(id: '', name: 'غير معروف', role: 'مافيوسو', avatar: '🎭'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _showStory ? _buildStoryContent() : _buildIntroSequence(),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainMenuScreen()),
              (route) => false,
            ),
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
          ),
          const Text(
            'كشف الحقيقة',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIntroSequence() {
    return Center(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentTextIndex < _storyParts.length)
              FadeTransition(
                opacity: _textController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _storyParts[_currentTextIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWinnerCard(),
          const SizedBox(height: 24),
          _buildMafiosoReveal(),
          const SizedBox(height: 32),
          if (_showConfession) _buildConfession(),
          const SizedBox(height: 32),
          _buildGameStats(),
          const SizedBox(height: 32),
          _buildFinalRolesList(),
        ],
      ),
    );
  }
  Widget _buildWinnerCard() {
    bool isCivilianWin = widget.room.winner == 'مدنيين';
    final mafioso = _mafiosoPlayer;
    String mafiosoName = mafioso.characterName.isNotEmpty
        ? mafioso.characterName
        : mafioso.name;
    String title = isCivilianWin ? 'المدنيون انتصروا!' : 'المافيوسو انتصر!';
    String subtitle = isCivilianWin
        ? 'لقد نجحتم في كشف المافيوسو وتحقيق العدالة.'
        : 'لقد نجح المافيوسو $mafiosoName في تنفيذ مهمته وخداعكم.';
    IconData icon = isCivilianWin ? Icons.shield : Icons.gavel;
    Color color = isCivilianWin ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 500.ms).slideY(begin: 0.5);
  }

  Widget _buildMafiosoReveal() {
    final mafioso = _mafiosoPlayer;
    return ScaleTransition(
      scale: _imageController,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.2),
              Colors.red.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.7), width: 3),
        ),
        child: Column(
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.1).animate(_pulseController),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mafioso.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.red[900],
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              mafioso.characterName.isNotEmpty ? mafioso.characterName : mafioso.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (mafioso.characterJob.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                mafioso.characterJob,
                style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'المافيوسو الحقيق',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (mafioso.characterDescription.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                mafioso.characterDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfession() {
    return FadeTransition(
      opacity: _textController,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'اعترافات المافيوسو',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.room.mafiosoStory.isNotEmpty 
                  ? widget.room.mafiosoStory 
                  : 'لم يتم الكشف عن الاعترافات...',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'إحصائيات اللعبة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('الناجون', widget.room.alivePlayers.length.toString(), Colors.green),
              _buildStatItem('المقصيون', widget.room.deadPlayers.length.toString(), Colors.red),
              _buildStatItem('الجولة', widget.room.currentRound.toString(), Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
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
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFinalRolesList() {
    // Use local snapshot if players list is empty
    final players = widget.room.players.isNotEmpty
        ? widget.room.players
        : (GameCubit.getLastRoomSnapshot()?.players ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'كشف الأدوار النهائية لجميع اللاعبين',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 16),
        ...players.map((player) {
          Color roleColor;
          switch (player.role) {
            case 'مافيوسو':
              roleColor = Colors.red;
              break;
            case 'مدني':
              roleColor = Colors.green;
              break;
            case 'محقق':
              roleColor = Colors.blue;
              break;
            case 'مضيف':
              roleColor = Colors.amber;
              break;
            default:
              roleColor = Colors.deepPurple;
          }
          return Card(
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: roleColor.withOpacity(0.2),
                child: Text(player.avatar, style: const TextStyle(fontSize: 24)),
              ),
              title: Text(
                player.characterName.isNotEmpty ? player.characterName : player.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                player.role,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: player.isAlive
                  ? const Icon(Icons.favorite, color: Colors.green, size: 20)
                  : const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainMenuScreen()),
              (route) => false,
            ),
            icon: const Icon(Icons.home),
            label: const Text('القائمة الرئيسية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          // ElevatedButton.icon(
          //   onPressed: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //         content: Text('تم حفظ القصة'),
          //         backgroundColor: Colors.green,
          //       ),
          //     );
          //   },
          //   icon: const Icon(Icons.share),
          //   label: const Text('مشاركة'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.teal,
          //     foregroundColor: Colors.white,
          //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //   ),
          // ),
        ],
      ),
    );
  }
} 