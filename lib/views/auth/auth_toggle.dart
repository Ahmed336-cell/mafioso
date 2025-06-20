import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showLogin = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _toggleView() {
    setState(() {
      _showLogin = !_showLogin;
      _controller.reset();
      _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتحركة
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .blurXY(begin: 10, end: 0, duration: 1.seconds),
          ),

          // طبقة تدرج لوني
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          // محتوى المصادقة
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(_showLogin ? 1 : -1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _showLogin
                      ? LoginScreen(
                    key: const ValueKey('login'),
                    onSignUpTapped: _toggleView,
                  )
                      : SignUpScreen(
                    key: const ValueKey('signup'),
                    onLoginTapped: _toggleView,
                  ),
                ),
              ),
            ),
          ),

          // شعار اللعبة
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'مافيوسو',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                  Shadow(
                  blurRadius: 10,
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(2, 2),
                  )],
                ),
              )
                  .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
                  .scaleXY(
                begin: 0.9,
                end: 1.05,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}