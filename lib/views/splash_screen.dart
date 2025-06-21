import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/mafioso.png',
                width: 200,
              )
                  .animate()
                  .fadeIn(duration: 1200.ms)
                  .shimmer(delay: 500.ms, duration: 1800.ms)
                  .then(delay: 500.ms), // Pause before next animation
              const SizedBox(height: 24),
              const Text(
                'الليل يخفي الأسرار... فمن نصدق؟',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              )
                  .animate()
                  .fadeIn(delay: 1500.ms, duration: 800.ms)
                  .slideY(begin: 0.5, end: 0),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Colors.white,
              ).animate().fadeIn(delay: 2500.ms),
            ],
          ),
        ),
      ),
    );
  }
} 