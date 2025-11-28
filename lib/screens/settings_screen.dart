// lib/screens/settings_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _apiBase = 'http://51.20.206.19:3000';

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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$email adresine şifre sıfırlama maili gönderildi.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
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

  void _openSupportSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final defaultName = user?.displayName ??
        (email.isNotEmpty ? email.split('@').first : 'Mobil Kullanıcı');

    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isSending = false;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              Future<void> send() async {
                final subject = subjectController.text.trim();
                final message = messageController.text.trim();

                if (message.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen mesaj alanını doldur.'),
                    ),
                  );
                  return;
                }

                setState(() => isSending = true);

                try {
                  final uri =
                      Uri.parse('$_apiBase/api/contact-messages');

                  final payload = {
                    'name': defaultName,
                    'email': email,
                    'subject': subject.isEmpty
                        ? 'Mobil destek talebi'
                        : subject,
                    'message': message,
                  };

                  final res = await http.post(
                    uri,
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode(payload),
                  );

                  if (!ctx2.mounted) return;

                  if (res.statusCode >= 200 && res.statusCode < 300) {
                    Navigator.of(ctx2).pop();

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Mesajın alındı, en kısa sürede dönüş yapacağız.',
                        ),
                      ),
                    );
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mesaj gönderilemedi (kod: ${res.statusCode}).',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mesaj gönderilemedi: $e'),
                    ),
                  );
                } finally {
                  if (!ctx2.mounted) return;
                  setState(() => isSending = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin:
                        const EdgeInsets.only(bottom: 12, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text(
                    'Destek Mesajı Gönder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mesajın direkt olarak Ermoneyt admin panelindeki '
                    '“İletişim Mesajları” bölümüne düşecek.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (email.isNotEmpty)
                    Text(
                      'Hesap e-postası: $email',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (email.isNotEmpty) const SizedBox(height: 10),
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Konu (opsiyonel)',
                      labelStyle:
                          const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF0B0F17),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.white24,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFFD166),
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Mesajın',
                      labelStyle:
                          const TextStyle(color: Colors.white60),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFF0B0F17),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.white24,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFFD166),
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSending
                            ? null
                            : () => Navigator.of(ctx2).pop(),
                        child: const Text('Vazgeç'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFFD166),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                        onPressed: isSending ? null : send,
                        child: isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(
                                          Colors.black),
                                ),
                              )
                            : const Text(
                                'Gönder',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
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
          // HESAP
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

          // UYGULAMA
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

          // DESTEK
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
                  onTap: () => _openSupportSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
