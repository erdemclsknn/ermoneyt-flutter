// lib/screens/returns_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  bool _loading = true;
  String? _error;
  final List<_ReturnOrder> _orders = [];
  final Map<String, TextEditingController> _cargoControllers = {};

  // Web returns.js'teki API_BASE mantığına benzer:
  static const String _apiBase = kDebugMode
      ? 'http://localhost:3000' // local geliştirme için
      : 'https://ermoneyt.com'; // canlı

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  @override
  void dispose() {
    for (final c in _cargoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReturns() async {
    setState(() {
      _loading = true;
      _error = null;
      _orders.clear();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Giriş yapmamışsın.';
      });
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders');

      final snap =
          await ref.orderBy('createdAt', descending: true).get();

      for (final doc in snap.docs) {
        final data = doc.data();

        final returnStatus = data['returnRequestStatus'] as String?;
        if (returnStatus == null || returnStatus.isEmpty) {
          continue; // sadece iade talebi olan siparişler
        }

        DateTime? created;
        final createdRaw = data['createdAt'];
        if (createdRaw is Timestamp) {
          created = createdRaw.toDate();
        } else if (createdRaw is String) {
          created = DateTime.tryParse(createdRaw);
        }

        final total = (data['total'] is num)
            ? (data['total'] as num).toDouble()
            : 0.0;

        final itemsRaw = data['items'];
        final List<_ReturnOrderItem> items = [];
        if (itemsRaw is List) {
          for (final it in itemsRaw) {
            if (it is Map<String, dynamic>) {
              items.add(
                _ReturnOrderItem(
                  name: (it['name'] ?? 'Ürün').toString(),
                  qty: (it['qty'] is num) ? (it['qty'] as num).toInt() : 1,
                ),
              );
            }
          }
        }

        final id = (data['id'] ?? doc.id).toString();
        final returnCargoCode =
            (data['returnCargoCode'] ?? '').toString();

        final order = _ReturnOrder(
          id: id,
          createdAt: created,
          total: total,
          items: items,
          returnStatus: returnStatus,
          returnCargoCode: returnCargoCode,
        );

        _orders.add(order);

        _cargoControllers[id]?.dispose();
        _cargoControllers[id] =
            TextEditingController(text: returnCargoCode);
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'İade talepleri alınamadı: $e';
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      default:
        return status;
    }
  }

  String _infoText(String status, String cargoCode) {
    if (status == 'pending' && cargoCode.isEmpty) {
      return 'İade talebin oluşturuldu. Ürünü kargoya verdikten sonra aşağıya kargo takip kodunu gir.';
    } else if (status == 'pending' && cargoCode.isNotEmpty) {
      return 'Kargo kodun alındı. İade talebin inceleniyor.';
    } else if (status == 'approved') {
      return 'İade talebin onaylandı.';
    } else if (status == 'rejected') {
      return 'İade talebin reddedildi.';
    }
    return '';
  }

  String _formatPrice(double v) {
    return '${v.toStringAsFixed(2)} ₺';
  }

  Future<void> _saveCargoCode(_ReturnOrder order) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kargo kodu kaydetmek için giriş yapmalısın.'),
        ),
      );
      return;
    }

    final ctrl = _cargoControllers[order.id];
    final code = ctrl?.text.trim() ?? '';

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir kargo takip kodu gir.'),
        ),
      );
      return;
    }

    setState(() {
      order.savingCargo = true;
    });

    try {
      final url = Uri.parse(
          '$_apiBase/api/orders/${order.id}/return-cargo');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.uid,
          'cargoCode': code,
        }),
      );

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      if (res.statusCode >= 400 || json['ok'] == false) {
        throw Exception(json['error'] ?? 'API hata');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kargo kodun kaydedildi.'),
        ),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(order.id)
          .update({
        'returnCargoCode': code,
      });

      await _loadReturns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kargo kodu kaydedilemedi: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          order.savingCargo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _orders.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('İadelerim'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD166),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : !hasData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Henüz bir iade talebin yok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReturns,
                      color: const Color(0xFFFFD166),
                      backgroundColor: const Color(0xFF131822),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, index) {
                          final o = _orders[index];
                          final cargoCtrl =
                              _cargoControllers[o.id] ?? TextEditingController();
                          _cargoControllers[o.id] = cargoCtrl;

                          final statusLabel =
                              _statusLabel(o.returnStatus);
                          final info =
                              _infoText(o.returnStatus, o.returnCargoCode);

                          return Card(
                            color: const Color(0xFF131822),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // HEADER
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sipariş No: ${o.id}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            o.createdAt != null
                                                ? o.createdAt!
                                                    .toLocal()
                                                    .toString()
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatPrice(o.total),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // STATUS
                                  Row(
                                    children: [
                                      const Text(
                                        'İade durumu: ',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color:
                                              _statusChipColor(o.returnStatus),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // ITEMS
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: o.items.isNotEmpty
                                        ? o.items
                                            .map(
                                              (it) => Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 2),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        it.name,
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'x ${it.qty}',
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.white60,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList()
                                        : const [
                                            Text(
                                              'Ürün bilgisi yok.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                  ),
                                  const SizedBox(height: 8),

                                  if (info.isNotEmpty)
                                    Text(
                                      info,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),

                                  const SizedBox(height: 10),

                                  if (o.returnStatus == 'pending')
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Kargo Takip Kodu',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: cargoCtrl,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Örn: Sürat Kargo takip kodu',
                                            hintStyle: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                            filled: true,
                                            fillColor:
                                                const Color(0xFF171C27),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                  color: Colors.white10),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                  color: Colors.white10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: o.savingCargo
                                                ? null
                                                : () =>
                                                    _saveCargoCode(o),
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFFD166),
                                              foregroundColor:
                                                  Colors.black,
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                vertical: 10,
                                              ), // 🔧 BURASI DÜZELDİ
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                            ),
                                            child: o.savingCargo
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.black,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Kargo kodunu kaydet',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _statusChipColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF1D4ED8); // mavi
      case 'approved':
        return const Color(0xFF047857); // yeşil
      case 'rejected':
        return const Color(0xFFB91C1C); // kırmızı
      default:
        return const Color(0xFF374151); // gri
    }
  }
}

class _ReturnOrder {
  final String id;
  final DateTime? createdAt;
  final double total;
  final List<_ReturnOrderItem> items;
  final String returnStatus;
  final String returnCargoCode;
  bool savingCargo;

  _ReturnOrder({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.items,
    required this.returnStatus,
    required this.returnCargoCode,
    this.savingCargo = false,
  });
}

class _ReturnOrderItem {
  final String name;
  final int qty;

  _ReturnOrderItem({
    required this.name,
    required this.qty,
  });
}
