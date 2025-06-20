import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'مافيوسو',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ).animate()
              .fadeIn(duration: 600.ms)
              .scale(delay: 200.ms),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: Colors.red.shade700,
            ).animate()
              .fadeIn(delay: 500.ms),
            const SizedBox(height: 16),
            Text(
              'جاري التحميل...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ).animate()
              .fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
} 