import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoleRevealScreen extends StatefulWidget {
  final String role;
  final String description;
  final VoidCallback? onContinue;

  const RoleRevealScreen({
    super.key,
    required this.role,
    required this.description,
    this.onContinue,
  });

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Color?> _colorAnimation;
  late final Color _roleColor;

  @override
  void initState() {
    super.initState();
    _roleColor = widget.role == 'مافيوسو' ? Colors.red : Colors.green;
    _initializeAnimations();
    _controller.forward();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: 1500.ms,
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.5, curve: Curves.easeIn),
        )
    );

        _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.elasticOut),
      )
      );

      _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: _roleColor,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: _colorAnimation.value?.withOpacity(0.1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRoleTitle(),
                    const SizedBox(height: 30),
                    _buildRoleCard(),
                    const SizedBox(height: 50),
                    if (_controller.isCompleted) _buildContinueButton(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleTitle() {
    return Opacity(
      opacity: _opacityAnimation.value,
      child: Text(
        'دورك هو',
        style: TextStyle(
          fontSize: 24,
          color: _colorAnimation.value,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    return Transform.scale(
      scale: _scaleAnimation.value,
      child: Card(
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _colorAnimation.value?.withOpacity(0.3) ?? Colors.transparent,
                _colorAnimation.value?.withOpacity(0.1) ?? Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.role,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _colorAnimation.value,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        backgroundColor: _roleColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 8,
        shadowColor: _roleColor.withOpacity(0.5),
      ),
      onPressed: () {
        widget.onContinue?.call();
        Navigator.pop(context);
      },
      child: const Text(
        'استمر',
        style: TextStyle(fontSize: 20),
      ),
    ).animate()
        .fadeIn(delay: 500.ms)
        .slideY(begin: 0.5, duration: 500.ms);
  }
}