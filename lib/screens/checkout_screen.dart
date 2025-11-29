// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'account_screen.dart';
import '../services/api_service.dart';

class CheckoutScreen extends StatefulWidget {
  /// İstersen tek ürün için de kullanabilirsin:
  /// CheckoutScreen(product: p, qty: 2)
  final Product? product;
  final int? qty;

  const CheckoutScreen({
    super.key,
    this.product,
    this.qty,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _selectedAddressId;
  Map<String, dynamic>? _selectedAddressData;
  bool _saving = false;
  String? _error;

  // ödeme yöntemi (web tarafındaki gibi)
  // cod_cash   = kapıda nakit
  // cod_card   = kapıda POS ile kart
  // online_card = kredi/banka kartı (online)
  String _selectedPaymentMethod = 'cod_cash';

  // KARGO KURALI
  static const double _freeShippingThreshold = 350.0; // 350 TL ve üzeri ücretsiz
  static const double _shippingFeeUnderThreshold = 100.0; // altına 100 TL

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Her ihtimale karşı, user yoksa Hesap ekranına at
    if (user == null) {
      return const AccountScreen();
    }

    final uid = user.uid;
    final cart = context.watch<CartProvider>();

    final isSingleProduct = widget.product != null;
    final q = widget.qty ?? 1;

    // ---- TOPLAM HESABI (displayPrice üzerinden) ----
    final double subtotal = isSingleProduct
        ? (widget.product!.displayPrice * q)
        : cart.items.values.fold<double>(
            0,
            (acc, item) =>
                acc + item.product.displayPrice * item.quantity,
          );

    // ---- KARGO HESABI ----
    final double shipping = subtotal >= _freeShippingThreshold
        ? 0.0
        : _shippingFeeUnderThreshold;

    final double grandTotal = subtotal + shipping;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Ödeme'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- SİPARİŞ ÖZETİ ----------------
                  const Text(
                    'Sipariş Özeti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '350 TL ve üzeri siparişlerde kargo ücretsizdir.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (isSingleProduct)
                    _singleProductSummary(
                      widget.product!,
                      q,
                      subtotal,
                      shipping,
                    )
                  else
                    _cartSummary(
                      cart,
                      subtotal,
                      shipping,
                    ),

                  const SizedBox(height: 24),

                  // ---------------- TESLİMAT ADRESİ ----------------
                  const Text(
                    'Teslimat Adresi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('addresses')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFD166),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131822),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Text(
                            'Adresler yüklenirken bir hata oluştu.',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131822),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Text(
                            'Kayıtlı adresiniz bulunmuyor.\n'
                            'Hesap > Adreslerim ekranından en az bir teslimat adresi ekleyin.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final id = doc.id;

                          final title =
                              (data['title'] ?? 'Adres').toString();
                          final fullName =
                              (data['fullName'] ?? '').toString();
                          final phone =
                              (data['phone'] ?? '').toString();
                          final line =
                              (data['line'] ?? '').toString();
                          final city =
                              (data['city'] ?? '').toString();
                          final district =
                              (data['district'] ?? '').toString();

                          final isSelected = _selectedAddressId == id;

                          return Card(
                            color: const Color(0xFF131822),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFFFD166)
                                    : Colors.white10,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: RadioListTile<String>(
                              value: id,
                              groupValue: _selectedAddressId,
                              activeColor: const Color(0xFFFFD166),
                              onChanged: (val) {
                                setState(() {
                                  _selectedAddressId = val;
                                  _selectedAddressData = data;
                                });
                              },
                              title: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (fullName.isNotEmpty)
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (line.isNotEmpty)
                                    Text(
                                      line,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (city.isNotEmpty ||
                                      district.isNotEmpty)
                                    Text(
                                      '$district / $city',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (phone.isNotEmpty)
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------------- ÖDEME YÖNTEMİ ----------------
                  const Text(
                    'Ödeme Yöntemi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF131822),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'cod_cash',
                          groupValue: _selectedPaymentMethod,
                          activeColor: const Color(0xFFFFD166),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedPaymentMethod = val);
                          },
                          title: const Text(
                            'Kapıda Nakit Ödeme',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Teslimat sırasında nakit olarak öde.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        RadioListTile<String>(
                          value: 'cod_card',
                          groupValue: _selectedPaymentMethod,
                          activeColor: const Color(0xFFFFD166),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedPaymentMethod = val);
                          },
                          title: const Text(
                            'Kapıda Kart ile Ödeme',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Kurye POS cihazı ile karttan çekim yapar.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        RadioListTile<String>(
                          value: 'online_card',
                          groupValue: _selectedPaymentMethod,
                          activeColor: const Color(0xFFFFD166),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedPaymentMethod = val);
                          },
                          title: const Text(
                            'Kredi / Banka Kartı (Online)',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            '3D Secure ile güvenli online ödeme.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ---------------- ALT ÖZET + BUTON ----------------
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            decoration: const BoxDecoration(
              color: Color(0xFF0B0F17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Genel Toplam (kargo dahil)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${grandTotal.toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_selectedAddressId == null ||
                                  _selectedAddressData == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Lütfen bir teslimat adresi seçin.'),
                                  ),
                                );
                                return;
                              }

                              if (!isSingleProduct &&
                                  cart.items.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Sepetinizde ürün bulunmuyor.'),
                                  ),
                                );
                                return;
                              }

                              await _createOrder(
                                uid: uid,
                                isSingleProduct: isSingleProduct,
                                cart: cart,
                                product: widget.product,
                                qty: q,
                                subtotal: subtotal,
                                shipping: shipping,
                                total: grandTotal,
                                addressData: _selectedAddressData!,
                              );
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              isSingleProduct
                                  ? 'Siparişi Onayla (${grandTotal.toStringAsFixed(2)} ₺)'
                                  : 'Siparişi Onayla',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------- TEK ÜRÜN ÖZETİ -------------
  Widget _singleProductSummary(
      Product p, int q, double subtotal, double shipping) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Adet: $q',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subtotal.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kargo',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              Text(
                shipping == 0
                    ? 'Ücretsiz'
                    : '${shipping.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------- SEPET ÖZETİ -------------
  Widget _cartSummary(
      CartProvider cart, double subtotal, double shipping) {
    final cartItems = cart.items.values.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...cartItems.map((item) {
            final p = item.product;
            final lineTotal = p.displayPrice * item.quantity;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${lineTotal.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ürünler Toplamı',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              Text(
                '${subtotal.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kargo',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              Text(
                shipping == 0
                    ? 'Ücretsiz'
                    : '${shipping.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------- SİPARİŞ OLUŞTURMA -------------
  Future<void> _createOrder({
    required String uid,
    required bool isSingleProduct,
    required CartProvider cart,
    required Product? product,
    required int qty,
    required double subtotal,
    required double shipping,
    required double total,
    required Map<String, dynamic> addressData,
  }) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      final name = user?.displayName ?? '';

      // adres içinden timestamp vs çıkar
      final cleanedAddress = Map<String, dynamic>.from(addressData);
      cleanedAddress.remove('createdAt');
      cleanedAddress.remove('updatedAt');

      // Sipariş ürün listesi
      late final List<Map<String, dynamic>> itemsList;

      if (isSingleProduct && product != null) {
        itemsList = [
          {
            'productId': product.id,
            'name': product.name,
            'price': product.displayPrice, // ödenen fiyat
            'originalPrice': product.salePrice,
            'qty': qty,
            'image': product.image,
          },
        ];
      } else {
        itemsList = cart.items.values.map((item) {
          final p = item.product;
          return {
            'productId': p.id,
            'name': p.name,
            'price': p.displayPrice,
            'originalPrice': p.salePrice,
            'qty': item.quantity,
            'image': p.image,
          };
        }).toList();
      }

      final payload = {
        'userId': uid,
        'userEmail': email,
        'userName': name,
        'address': cleanedAddress,
        'items': itemsList,
        'subtotal': subtotal,
        'shipping': shipping,
        'total': total,
        'paymentMethod': _selectedPaymentMethod, // <<< BURASI ÖNEMLİ
      };

      // Önce backend API'ye gönder
      final resp = await ApiService.createOrder(payload);

      if (resp['ok'] != true) {
        throw Exception(resp['error'] ?? 'ORDER_FAILED');
      }

      // ---- Mobile tarafında Firestore'a users/{uid}/orders yaz ----
      final orderId =
          DateTime.now().millisecondsSinceEpoch.toString(); // web ile uyumlu

      final orderDoc = {
        'id': orderId,
        'userId': uid,
        'userEmail': email,
        'userName': name,
        'items': itemsList,
        'subtotal': subtotal,
        'shipping': shipping,
        'total': total,
        'paymentMethod': _selectedPaymentMethod,
        'addressId': _selectedAddressId,
        'address': cleanedAddress,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final userOrderRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('orders')
          .doc(orderId);

      await userOrderRef.set(orderDoc);

      // sadece sepetten geldiyse sepeti boşalt
      if (!isSingleProduct) {
        cart.clear();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Siparişin alındı, teşekkürler!'),
        ),
      );

      Navigator.of(context).pop(); // checkout ekranını kapat
    } catch (e) {
      setState(() {
        _error =
            'Sipariş oluşturulurken bir hata oluştu. Lütfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
