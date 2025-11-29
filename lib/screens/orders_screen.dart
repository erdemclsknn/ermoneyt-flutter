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
    // yyyy-MM-dd HH:mm -> kullanıcıya yeterli
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  String _formatMoney(dynamic v) {
    if (v == null) return '0,00 ₺';
    if (v is num) {
      return '${v.toStringAsFixed(2)} ₺';
    }
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
              style: TextStyle(color: Colors.white70, fontSize: 14),
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
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Henüz hiç siparişin yok.\nİlk siparişini şimdi oluşturabilirsin 🚀',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
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
              final paymentMethod =
                  (data['paymentMethod'] ?? 'Bilinmiyor').toString();
              final createdAt = data['createdAt'];
              final shippedAt = data['shippedAt'];
              final items = (data['items'] as List<dynamic>? ?? []);
              final address =
                  (data['address'] as Map<String, dynamic>? ?? {});

              // ürün adedi
              int itemCount = 0;
              for (final it in items) {
                if (it is Map) {
                  final q = it['qty'] ?? it['quantity'] ?? 1;
                  if (q is num) {
                    itemCount += q.toInt();
                  } else {
                    itemCount += 1;
                  }
                } else {
                  itemCount += 1;
                }
              }

              final statusLabel = _statusLabel(status);
              final statusColor = _statusColor(status);
              final createdStr = _formatDate(createdAt);
              final shippedStr =
                  shippedAt != null ? _formatDate(shippedAt) : null;

              // Adres metni
              final fullName =
                  (address['fullName'] ?? address['adSoyad'] ?? '').toString();
              final line =
                  (address['line'] ?? address['line1'] ?? '').toString();
              final city = (address['city'] ?? '').toString();
              final district = (address['district'] ?? '').toString();
              final phone = (address['phone'] ?? '').toString();

              final addressLines = <String>[];
              if (fullName.isNotEmpty) addressLines.add(fullName);
              if (line.isNotEmpty) addressLines.add(line);
              if (city.isNotEmpty || district.isNotEmpty) {
                addressLines.add('$district / $city'.trim());
              }
              if (phone.isNotEmpty) addressLines.add(phone);

              return Card(
                color: const Color(0xFF131822),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.white10,
                    listTileTheme: const ListTileThemeData(
                      iconColor: Colors.white70,
                    ),
                  ),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sipariş #$id',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMoney(total),
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              createdStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      const SizedBox(height: 8),
                      // Ürün sayısı, ödeme yöntemi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$itemCount ürün',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Ödeme: $paymentMethod',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Toplamlar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ürünler: ${_formatMoney(subtotal)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Kargo: ${_formatMoney(shipping)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Genel Toplam: ${_formatMoney(total)}',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

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
                        const SizedBox(height: 10),
                      ],

                      // Ürün listesi
                      const Text(
                        'Ürünler',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...items.map((it) {
                        if (it is! Map) return const SizedBox.shrink();
                        final name = (it['name'] ?? '').toString();
                        final qty = (it['qty'] ?? it['quantity'] ?? 1);
                        final price = it['price'];
                        final image = (it['image'] ?? '').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              if (image.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    image,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFF1F2937),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
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
                              const SizedBox(width: 8),
                              Text(
                                _formatMoney(price),
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      if (shippedStr != null &&
                          shippedStr.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Kargoya verildi: $shippedStr',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
