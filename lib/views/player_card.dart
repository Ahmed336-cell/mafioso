import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player.dart';

class PlayerCard extends StatelessWidget {
  final Player player;
  final bool isEliminated;
  final VoidCallback onTap;
  final double sizeMultiplier;
  final String myId;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isEliminated,
    required this.onTap,
    required this.myId,
    this.sizeMultiplier = 1.0, // Default multiplier
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 10,
        margin: EdgeInsets.all(8 * sizeMultiplier),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15 * sizeMultiplier),
        ),
        child: Stack(
          children: [
            _buildPlayerContent(),
            if (isEliminated) _buildEliminatedOverlay(),
          ],
        ),
      ).animate().scale(duration: 300.ms),
    );
  }

  Widget _buildPlayerContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPlayerAvatar(),
                const SizedBox(width: 12),
              ],
            ),
            _buildPlayerName(),

            if (player.characterName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                player.characterName,
                style: const TextStyle(fontSize: 13, color: Colors.deepPurple, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
            if (player.characterDescription.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                player.characterDescription,
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (player.role.isNotEmpty) ...[
              const SizedBox(height: 6),
              player.id == myId
                  ? Text(
                      player.role == 'مافيوسو' ? 'مافيوسو' : 'مدني',
                      style: TextStyle(
                        fontSize: 12,
                        color: player.role == 'مافيوسو' ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      '?',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return CircleAvatar(
      radius: 30 * sizeMultiplier,
      backgroundColor: isEliminated ? Colors.grey : _getRoleColor(),
      child: Text(
        player.avatar,
        style: TextStyle(
          fontSize: 30 * sizeMultiplier,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPlayerName() {
    return Text(
      player.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16 * sizeMultiplier,
        color: isEliminated ? Colors.grey : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEliminatedOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15 * sizeMultiplier),
        ),
        child: Center(
          child: Icon(
            Icons.block,
            color: Colors.white,
            size: 40 * sizeMultiplier,
          ),
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (player.role.toLowerCase()) {
      case 'مافيوسو':
        return Colors.red;
      case 'مضيف':
        return Colors.amber;
      case 'محقق':
        return Colors.blue;
      default:
        return Colors.deepPurple;
    }
  }
}