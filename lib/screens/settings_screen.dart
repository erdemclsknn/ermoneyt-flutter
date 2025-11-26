// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre sıfırlama için e-posta adresi bulunamadı.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$email adresine şifre sıfırlama maili gönderildi.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre sıfırlama maili gönderilemedi.'),
        ),
      );
    }
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131822),
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HESAP BÖLÜMÜ
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
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFFFFD166),
                  ),
                  title: const Text('Hesap bilgileri'),
                  subtitle: Text(
                    user?.email ?? 'E-posta bulunamadı',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.lock_reset,
                    color: Color(0xFFFFD166),
                  ),
                  title: const Text('Şifre sıfırlama maili gönder'),
                  subtitle: const Text(
                    'Şifreni unuttuysan e-posta adresine link gönderelim',
                    style: TextStyle(color: Colors.white60),
                  ),
                  onTap: () => _sendPasswordResetEmail(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // UYGULAMA BÖLÜMÜ
          const Text(
            'Uygulama',
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
                    Icons.description_outlined,
                    color: Color(0xFFFFD166),
                  ),
                  title: const Text('Kullanım şartları'),
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Kullanım şartları',
                      message:
                          'Ermoneyt uygulamasını kullanarak temel e-ticaret kurallarını, '
                          'KVKK kapsamında kişisel verilerin işlenmesini ve platform '
                          'kurallarını kabul etmiş olursun.\n\n'
                          'Detaylı metin daha sonra buraya eklenecek.',
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFFFFD166),
                  ),
                  title: const Text('Gizlilik politikası'),
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Gizlilik politikası',
                      message:
                          'Kişisel verilerin, yalnızca sipariş süreçlerini yürütmek, '
                          'müşteri desteği sağlamak ve kampanya bilgilendirmeleri için '
                          'işlenir.\n\nGüncel gizlilik metni ileride detaylı şekilde eklenecek.',
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                const ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Color(0xFFFFD166),
                  ),
                  title: Text('Uygulama sürümü'),
                  subtitle: Text(
                    'v1.0.0 (örnek)',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // DESTEK BÖLÜMÜ
          const Text(
            'Destek',
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
                    Icons.support_agent_outlined,
                    color: Color(0xFFFFD166),
                  ),
                  title: const Text('Destek ile iletişim'),
                  subtitle: const Text(
                    'Sorun ve önerilerin için bize yaz',
                    style: TextStyle(color: Colors.white60),
                  ),
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Destek',
                      message:
                          'Destek e-posta adresi:\n\n'
                          'support@ermoneyt.com\n\n'
                          'Uygulama ile ilgili yaşadığın hataları ekran görüntüsü ile birlikte '
                          'bu adrese gönderebilirsin.',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
