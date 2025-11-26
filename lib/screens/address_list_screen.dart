// lib/screens/address_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'address_add_screen.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  /// Adres silme
  Future<void> _deleteAddress(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .doc(docId)
        .delete();
  }

  /// Silmeden önce onay popup’ı
  Future<void> _confirmDelete(String docId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Adresi sil',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Bu adresi silmek istediğine emin misin?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Sil',
                style: TextStyle(color: Color(0xFFFF6B6B)),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteAddress(docId);
      // StreamBuilder otomatik güncelleyecek, setState gerek yok
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Giriş yapılmamışsa
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        appBar: AppBar(
          title: const Text('Adreslerim'),
          backgroundColor: const Color(0xFF0B0F17),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Adresleri görmek için önce giriş yapmalısın.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Adreslerim'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD166),
        foregroundColor: Colors.black,
        onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const AddressAddScreen(),
            ),
          );
          if (!mounted) return;
          if (changed == true) {
            setState(() {}); // Stream zaten yenilenecek, yine de tetikliyoruz
          }
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFFD166)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Adresler yüklenemedi: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Henüz kayıtlı bir adresin yok.\nSağ alttan yeni adres ekleyebilirsin.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final fullName = (data['fullName'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final city = (data['city'] ?? '').toString();
              final district = (data['district'] ?? '').toString();
              final neighborhood = (data['neighborhood'] ?? '').toString();
              final street = (data['street'] ?? '').toString();
              final zip = (data['zipCode'] ?? '').toString();
              final line1 = (data['line1'] ?? '').toString();

              final summary =
                  '$neighborhood, $street\n$district / $city ${zip.isNotEmpty ? "($zip)" : ""}\n$line1';

              return Card(
                color: const Color(0xFF131822),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(
                    fullName.isEmpty ? 'Adres ${index + 1}' : fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  // sağ tarafa hem sil hem ok ikonu
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Adresi sil',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFFF6B6B),
                        ),
                        onPressed: () => _confirmDelete(doc.id),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  onTap: () {
                    // ileride: düzenleme / seçim ekranı
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
