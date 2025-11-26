// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';

import 'providers/cart_provider.dart';
import 'screens/mobile_home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/category_screen.dart';
import 'screens/account_screen.dart'; // ⬅️ YENİ HESAP EKRANI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google-services.json zaten var, bu kadarı yeterli
  await Firebase.initializeApp();

  runApp(const ErmoneytApp());
}

class ErmoneytApp extends StatelessWidget {
  const ErmoneytApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Ermoneyt',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: false).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B0F17),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFD166),
            secondary: Color(0xFFFFD166),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0F17),
            elevation: 0,
          ),
          cardColor: const Color(0xFF131822),
        ),
        home: const SplashScreen(), // ⬅️ Splash yapısı aynen duruyor
        routes: {
          CartScreen.routeName: (_) => const CartScreen(),
        },
      ),
    );
  }
}

/// Alt menülü kabuk
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;

  // Sekmeler (Ana = index 0)
  final _pages = const [
    MobileHomeScreen(), // Ana
    CategoryScreen(),   // Kategori
    CartScreen(),       // Sepet
    AccountScreen(),    // ⬅️ HESAP (artık Placeholder değil)
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFF0B0F17),
          selectedItemColor: const Color(0xFFFFD166),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Ana',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              label: 'Kategori',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              label: 'Sepet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Hesap',
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------- SPLASH SCREEN ----------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;

  // Slogan
  static const String _slogan = 'Sen ne istersen burada';

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoController.forward();

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
