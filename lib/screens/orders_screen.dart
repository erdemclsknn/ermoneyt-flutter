// lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
      case 'pending':
        return Colors.orangeAccent;
      case 'preparing':
        return Colors.blueAccent;
      case 'shipped':
        return Colors.lightBlueAccent;
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
      case 'pending':
        return 'Yeni';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'shipped':
        return 'Kargolandı';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  String _formatMoney(dynamic v) {
    if (v == null) return '0,00 ₺';
    if (v is num) return '${v.toStringAsFixed(2)} ₺';
    try {
      final d = double.parse(v.toString());
      return '${d.toStringAsFixed(2)} ₺';
    } catch (_) {
      return '0,00 ₺';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        appBar: AppBar(
          title: const Text('Siparişlerim'),
          backgroundColor: const Color(0xFF0B0F17),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Siparişlerini görebilmek için giriş yapmalısın.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Siparişlerim'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFD166),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Siparişler yüklenirken bir hata oluştu.',
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Henüz hiç siparişin yok.\nİlk siparişini şimdi oluşturabilirsin 🚀',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final id = (data['id'] ?? doc.id).toString();
              final status = (data['status'] ?? 'new').toString();
              final total = data['total'];
              final subtotal = data['subtotal'];
              final shipping = data['shipping'];
              final createdAt = data['createdAt'];
              final items = (data['items'] as List<dynamic>? ?? []);
              final address = (data['address'] as Map<String, dynamic>? ?? {});

              // Ürün sayısı
              int itemCount = 0;
              for (var it in items) {
                if (it is Map) {
                  final q = it['qty'] ?? it['quantity'] ?? 1;
                  itemCount += (q is num) ? q.toInt() : 1;
                } else {
                  itemCount += 1;
                }
              }

              final fullName = (address['fullName'] ?? '').toString();
              final line = (address['line'] ?? '').toString();
              final city = (address['city'] ?? '').toString();
              final district = (address['district'] ?? '').toString();
              final phone = (address['phone'] ?? '').toString();

              final addressLines = [
                if (fullName.isNotEmpty) fullName,
                if (line.isNotEmpty) line,
                if (district.isNotEmpty || city.isNotEmpty)
                  '$district / $city',
                if (phone.isNotEmpty) phone,
              ];

              return Card(
                color: const Color(0xFF131822),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 14),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sipariş #$id',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatMoney(total),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatDate(createdAt),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    const SizedBox(height: 8),

                    // Ürün sayısı – ödeme
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$itemCount ürün',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Ara toplam – kargo – genel toplam
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ürünler: ${_formatMoney(subtotal)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Kargo: ${_formatMoney(shipping)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Genel Toplam: ${_formatMoney(total)}',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Adres
                    if (addressLines.isNotEmpty) ...[
                      const Text(
                        'Teslimat adresi',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addressLines.join('\n'),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Ürünler listesi
                    const Text(
                      'Ürünler',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...items.map((it) {
                      if (it is! Map) return const SizedBox.shrink();

                      final name = it['name'] ?? '';
                      final qty = it['qty'] ?? it['quantity'] ?? 1;
                      final price = it['price'];
                      final image = (it['image'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // --- BOZUK RESİM ENGELLEYEN KISIM ---
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                image,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F2937),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Adet: $qty',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              _formatMoney(price),
                              style: const TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
