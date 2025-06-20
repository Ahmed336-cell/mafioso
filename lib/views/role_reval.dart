import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoleRevealScreen extends StatefulWidget {
  final String role;
  final String description;

  const RoleRevealScreen({
    super.key,
    required this.role,
    required this.description,
  });

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.elasticOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: widget.role == 'مافيوسو' ? Colors.red : Colors.green,
    ).animate(_controller);

    _controller.forward();
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
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: _colorAnimation.value?.withValues(alpha: 0.1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _opacityAnimation.value,
                      child: Text(
                        'دورك هو',
                        style: TextStyle(
                          fontSize: 24,
                          color: _colorAnimation.value,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Transform.scale(
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
                                _colorAnimation.value?.withValues(alpha: 0.3) ?? Colors.transparent,
                                _colorAnimation.value?.withValues(alpha: 0.1) ?? Colors.transparent,
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
                    ),

                    const SizedBox(height: 50),

                    if (_controller.isCompleted)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          backgroundColor: _colorAnimation.value,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'استمر',
                          style: TextStyle(fontSize: 20),
                        ),
                      ).animate().fadeIn(delay: const Duration(milliseconds: 500)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}