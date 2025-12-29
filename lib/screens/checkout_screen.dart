// lib/screens/checkout_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Android debug için
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'account_screen.dart';
import '../services/api_service.dart';

class CheckoutScreen extends StatefulWidget {
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

  static const double _freeShippingThreshold = 350.0;
  static const double _shippingFeeUnderThreshold = 100.0;

  /// ✅ MOBİL success/fail (webden bağımsız)
  static const String _mobileSuccessUrl = 'ermoneyt://payment-success';
  static const String _mobileFailUrl = 'ermoneyt://payment-failed';

  static const String _apiBase = 'https://api.ermoneyt.com';

  // WebView state
  bool _showIyzico = false;
  String? _currentOrderId;
  WebViewController? _iyzicoController;
  bool _iyzicoLoading = false;

  // “URL ile açmayı dene, olmazsa HTML göm” fallback kontrolü
  bool _usingUrlMode = true;

  Future<void> _clearRemoteCart(String uid) async {
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart');
      final snap = await col.get();
      if (snap.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('clearRemoteCart error: $e');
    }
  }

  String _normalizeHtml(String inner) {
    final s = inner.trim().toLowerCase();
    final alreadyFullDoc =
        s.contains('<html') || s.contains('<head') || s.contains('<body');
    if (alreadyFullDoc) return inner;

    return '''
<!doctype html>
<html lang="tr">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
<title>İyzico Ödeme</title>
<style>
  body { margin:0; background:#0b0f17; color:#fff; font-family: system-ui, -apple-system, Segoe UI, sans-serif; }
</style>
</head>
<body>
$inner
</body>
</html>
''';
  }

  void _closeIyzico() {
    if (!mounted) return;
    setState(() {
      _showIyzico = false;
      _currentOrderId = null;
      _iyzicoController = null;
      _iyzicoLoading = false;
      _usingUrlMode = true;
    });
  }

  bool _isMobileSuccessUrl(String url) => url.startsWith(_mobileSuccessUrl);
  bool _isMobileFailUrl(String url) => url.startsWith(_mobileFailUrl);

  Future<void> _goSuccess({
    required String orderId,
    required bool isSingleProduct,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _clearRemoteCart(uid);
    }
    if (!mounted) return;

    if (!isSingleProduct) {
      context.read<CartProvider>().clear();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(success: true, orderId: orderId),
      ),
    );
  }

  Future<void> _goFail({required String orderId}) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(success: false, orderId: orderId),
      ),
    );
  }

  WebViewController _buildController({
    required String orderId,
    required bool isSingleProduct,
  }) {
    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(true);
    }

    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0F17))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final url = request.url;
            debugPrint('🔎 WebView nav: $url');

            if (_isMobileSuccessUrl(url)) {
              await _goSuccess(
                orderId: orderId,
                isSingleProduct: isSingleProduct,
              );
              return NavigationDecision.prevent;
            }

            if (_isMobileFailUrl(url)) {
              await _goFail(orderId: orderId);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _iyzicoLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _iyzicoLoading = false);
          },
          onWebResourceError: (err) async {
            debugPrint('❌ WebView error: ${err.errorCode} ${err.description}');
            if (mounted) setState(() => _iyzicoLoading = false);

            // ✅ URL mode patlarsa HTML fallback’e geç
            if (_usingUrlMode) {
              debugPrint('⚠️ URL mode failed -> switching to HTML embed fallback...');
              await _fallbackToHtml(
                orderId: orderId,
                isSingleProduct: isSingleProduct,
              );
            }
          },
        ),
      );
  }

  void _openIyzicoByUrl({
    required String orderId,
    required bool isSingleProduct,
  }) {
    final controller =
        _buildController(orderId: orderId, isSingleProduct: isSingleProduct);

    if (!mounted) return;
    setState(() {
      _currentOrderId = orderId;
      _iyzicoController = controller;
      _showIyzico = true;
      _iyzicoLoading = true;
      _usingUrlMode = true;
    });

    controller.loadRequest(Uri.parse('$_apiBase/pay/mobile/$orderId'));
  }

  Future<void> _fallbackToHtml({
    required String orderId,
    required bool isSingleProduct,
  }) async {
    try {
      _usingUrlMode = false;

      final init = await ApiService.initIyzicoCheckoutForm(orderId);
      final ok = init['ok'] == true;
      final String html =
          (init['html'] ?? init['checkoutFormContent'] ?? '').toString();

      if (!ok || html.isEmpty) {
        throw Exception(init['error'] ?? 'IYZICO_INIT_FAILED');
      }

      final controller =
          _buildController(orderId: orderId, isSingleProduct: isSingleProduct);

      if (!mounted) return;
      setState(() {
        _iyzicoController = controller;
        _showIyzico = true;
        _iyzicoLoading = true;
      });

      controller.loadHtmlString(
        _normalizeHtml(html),
        baseUrl: _apiBase,
      );
    } catch (e) {
      debugPrint('❌ HTML fallback failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Ödeme ekranı açılamadı (SSL/bağlantı). Sunucu SSL/Proxy ayarlarını kontrol et.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AccountScreen();

    final uid = user.uid;
    final cart = context.watch<CartProvider>();

    final isSingleProduct = widget.product != null;
    final q = widget.qty ?? 1;

    final double subtotal = isSingleProduct
        ? (widget.product!.displayPrice * q)
        : cart.items.values.fold<double>(
            0,
            (acc, item) => acc + item.product.displayPrice * item.quantity,
          );

    final double shipping =
        subtotal >= _freeShippingThreshold ? 0.0 : _shippingFeeUnderThreshold;
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
                    style: TextStyle(color: Colors.white60, fontSize: 11),
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
                    _cartSummary(cart, subtotal, shipping),

                  const SizedBox(height: 24),

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

                          final title = (data['title'] ?? 'Adres').toString();
                          final fullName =
                              (data['fullName'] ?? data['name'] ?? '')
                                  .toString();
                          final phone = (data['phone'] ??
                                  data['phoneNumber'] ??
                                  '')
                              .toString();

                          final line1 = (data['line1'] ??
                                  data['addressLine'] ??
                                  data['line'] ??
                                  '')
                              .toString();
                          final line2 = (data['line2'] ??
                                  data['addressLine2'] ??
                                  '')
                              .toString();
                          final city =
                              (data['city'] ?? data['cityName'] ?? '')
                                  .toString();
                          final district = (data['district'] ??
                                  data['districtName'] ??
                                  '')
                              .toString();

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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (fullName.isNotEmpty)
                                    Text(fullName,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  if (line1.isNotEmpty)
                                    Text(line1,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  if (line2.isNotEmpty)
                                    Text(line2,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  if (city.isNotEmpty || district.isNotEmpty)
                                    Text(
                                      '$district / $city',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                  if (phone.isNotEmpty)
                                    Text(phone,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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

                  if (_showIyzico && _iyzicoController != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131822),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Kart ile Ödeme (İyzico)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _closeIyzico,
                                child: const Text(
                                  'Kapat',
                                  style: TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_currentOrderId != null)
                            Text(
                              'Sipariş No: $_currentOrderId',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 520,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  WebViewWidget(controller: _iyzicoController!),
                                  if (_iyzicoLoading)
                                    const LinearProgressIndicator(
                                      minHeight: 2,
                                      color: Color(0xFFFFD166),
                                      backgroundColor: Colors.transparent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _usingUrlMode
                                ? 'Ödeme sayfası açılıyor... (URL mode)'
                                : 'Ödeme sayfası açılıyor... (HTML fallback)',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            decoration: const BoxDecoration(
              color: Color(0xFF0B0F17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                )
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
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_showIyzico) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Ödeme ekranı zaten açık. Kart bilgilerini gir.'),
                                  ),
                                );
                                return;
                              }

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

                              if (!isSingleProduct && cart.items.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Sepetinizde ürün bulunmuyor.'),
                                  ),
                                );
                                return;
                              }

                              await _createOrderAndStartIyzico(
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
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
                  Text('Adet: $q',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
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
              const Text('Kargo',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                shipping == 0 ? 'Ücretsiz' : '${shipping.toStringAsFixed(2)} ₺',
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

  Widget _cartSummary(CartProvider cart, double subtotal, double shipping) {
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
          for (final item in cartItems) ...[
            Builder(builder: (_) {
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
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('x${item.quantity}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12)),
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
            }),
          ],
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ürünler Toplamı',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '${subtotal.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kargo',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                shipping == 0 ? 'Ücretsiz' : '${shipping.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createOrderAndStartIyzico({
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

      final cleanedAddress = Map<String, dynamic>.from(addressData);
      cleanedAddress.remove('createdAt');
      cleanedAddress.remove('updatedAt');

      late final List<Map<String, dynamic>> itemsList;

      if (isSingleProduct && product != null) {
        itemsList = [
          {
            'productId': product.id,
            'name': product.name,
            'price': product.displayPrice,
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
        'addressId': _selectedAddressId,
        'address': cleanedAddress,
        'items': itemsList,
        'subtotal': subtotal,
        'shipping': shipping,
        'total': total,
        'paymentMethod': 'card_online',
        'paymentProvider': 'iyzico',
        'channel': 'mobile',
        'mobileSuccessUrl': _mobileSuccessUrl,
        'mobileFailUrl': _mobileFailUrl,
      };

      final resp = await ApiService.createOrder(payload);

      if (resp['ok'] != true ||
          resp['order'] == null ||
          resp['order']['id'] == null) {
        throw Exception(resp['error'] ?? 'ORDER_FAILED');
      }

      final String orderId = resp['order']['id'].toString();

      if (!mounted) return;

      // ✅ 1) Önce URL ile dene
      _openIyzicoByUrl(orderId: orderId, isSingleProduct: isSingleProduct);

      // SSL patlarsa onWebResourceError otomatik HTML fallback’e geçer.
    } catch (e) {
      debugPrint("createOrder/iyzico error: $e");
      if (!mounted) return;
      setState(() {
        _error = 'Sipariş/Ödeme başlatılamadı. Lütfen tekrar deneyin.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String orderId;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: const Text('Ödeme Sonucu'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle : Icons.cancel,
                size: 72,
                color: success
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(height: 14),
              Text(
                success ? 'Ödeme Başarılı' : 'Ödeme Başarısız',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sipariş No: $orderId',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text(
                    'Ana Sayfaya Dön',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
