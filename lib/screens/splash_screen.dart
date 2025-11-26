// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart'; // MobileShell burada

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;

  static const String _slogan = 'Sen ne istersen burada';

  @override
  void initState() {
    super.initState();

    // Logo için scale animasyonu
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoController.forward();

    // 2.3 sn sonra ana shell’e geç
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MobileShell()),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _logoScale,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Slogan – typewriter efekti
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1300),
              builder: (context, value, child) {
                final int count =
                    (_slogan.length * value).clamp(0, _slogan.length).toInt();
                final String text = _slogan.substring(0, count);
                return Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Color(0xFFFFD166)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
