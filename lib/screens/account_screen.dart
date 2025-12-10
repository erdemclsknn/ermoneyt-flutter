// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../providers/cart_provider.dart';
import 'favorites_screen.dart';
import 'address_list_screen.dart';
import 'cart_screen.dart';
import 'settings_screen.dart';
import 'orders_screen.dart';
import 'returns_screen.dart'; // 🆕 İadelerim ekranı

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService();

  bool _isLoginMode = true;
  bool _loading = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ----------------- GİRİŞ & ÜYELİK -----------------

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLoginMode) {
        await _authService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await _authService.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Bir hata oluştu, tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Google ile giriş başarısız oldu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
  }

  // ----------------- FORM WIDGET -----------------

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF131822),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD166)),
        ),
      ),
      validator: validator,
    );
  }

  // ----------------- ALTINKAP PROMO -----------------

  Widget _altinkapPromoCard() {
    return Card(
      color: const Color(0xFF171C27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.videogame_asset_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AltınKap Oyunları',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Oyna, taş kazan, çekilişlere katıl!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Hemen Dene',
              style: TextStyle(
                color: Color(0xFFFFD166),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //                          BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // =====================================================
        //                 GİRİŞ YAPILMAMIŞ
        // =====================================================
        if (user == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B0F17),
            appBar: AppBar(
              title: const Text('Hesabım'),
              backgroundColor: const Color(0xFF0B0F17),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Color(0xFFFFD166),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ermoneyt’e hoş geldin 👋',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sipariş verebilmek, sepetini ve favorilerini kaydedebilmek için giriş yap veya yeni hesap oluştur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // LOGIN/REGISTER TOGGLE
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF171C27),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLoginMode = true),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: _isLoginMode
                                    ? const Color(0xFFFFD166)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                'Giriş yap',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isLoginMode
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLoginMode = false),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: !_isLoginMode
                                    ? const Color(0xFFFFD166)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                'Üye ol',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !_isLoginMode
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLoginMode) ...[
                          _field(
                            controller: _nameCtrl,
                            label: 'Ad Soyad',
                            validator: (v) {
                              if (!_isLoginMode &&
                                  (v == null || v.isEmpty)) {
                                return 'Ad soyad girin';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        _field(
                          controller: _emailCtrl,
                          label: 'E-posta',
                          type: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'E-posta girin';
                            }
                            if (!v.contains('@')) {
                              return 'Geçerli bir e-posta girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _passwordCtrl,
                          label: 'Şifre',
                          obscure: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Şifre girin';
                            }
                            if (v.length < 6) {
                              return 'En az 6 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submitEmailForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD166),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    _isLoginMode ? 'Giriş yap' : 'Üye ol',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      SizedBox(width: 8),
                      Text('veya', style: TextStyle(color: Colors.white70)),
                      SizedBox(width: 8),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _googleLogin,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFFD166)),
                        foregroundColor: const Color(0xFFFFD166),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text(
                        'Google ile devam et',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  _altinkapPromoCard(),
                ],
              ),
            ),
          );
        }

        // =====================================================
        //                 GİRİŞ YAPILMIŞ
        // =====================================================

        final cart = context.watch<CartProvider>();
        final itemCount = cart.items.length;
        final cartTotal = cart.totalAmount;

        final displayName = user.displayName ?? (user.email ?? 'Kullanıcı');
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          appBar: AppBar(
            title: const Text('Hesabım'),
            backgroundColor: const Color(0xFF0B0F17),
          ),
          body: Column(
            children: [
              // ÜST PROFİL BLOĞU
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1C2535),
                      Color(0xFF0B0F17),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFFFD166),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Hesap',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Card(
                      color: const Color(0xFF131822),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // SEPETİM
                          ListTile(
                            leading: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('Sepetim'),
                            subtitle: Text(
                              itemCount == 0
                                  ? 'Sepetinde ürün yok'
                                  : '$itemCount ürün • ${cartTotal.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.white10),

                          // SİPARİŞLERİM
                          ListTile(
                            leading: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('Siparişlerim'),
                            subtitle: const Text(
                              'Geçmiş ve güncel siparişlerin',
                              style: TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OrdersScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.white10),

                          // 🆕 İADELERİM
                          ListTile(
                            leading: const Icon(
                              Icons.undo_rounded,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('İadelerim'),
                            subtitle: const Text(
                              'İade ve değişim taleplerini görüntüle',
                              style: TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReturnsScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.white10),

                          // FAVORİLER
                          ListTile(
                            leading: const Icon(
                              Icons.favorite_border,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('Favorilerim'),
                            subtitle: const Text(
                              'Beğendiğin ürünleri burada gör',
                              style: TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.white10),

                          // ADRESLER
                          ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('Adreslerim'),
                            subtitle: const Text(
                              'Teslimat adreslerini yönet',
                              style: TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddressListScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Diğer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Card(
                      color: const Color(0xFF131822),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.settings_outlined,
                              color: Color(0xFFFFD166),
                            ),
                            title: const Text('Ayarlar'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.white10),

                          ListTile(
                            leading: const Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                            ),
                            title: const Text(
                              'Çıkış yap',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    _altinkapPromoCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
