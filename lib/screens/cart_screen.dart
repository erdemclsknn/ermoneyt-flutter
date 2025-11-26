// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/cart_provider.dart';
import 'account_screen.dart';
import 'mobile_home_screen.dart'; // ANASAYFA
import 'checkout_screen.dart';    // ÖDEME EKRANI EKLENDİ

class CartScreen extends StatelessWidget {
  static const routeName = '/cart';

  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartItems = cart.items.values.toList();

    // KAMPANYALI TOPLAM: her ürün için displayPrice * adet
    final discountedTotal = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.product.displayPrice * item.quantity,
    );

    final user = FirebaseAuth.instance.currentUser;

    // Kullanıcı giriş yaptıysa Firestore'daki sepeti çek (CartProvider içinde 1 kez çalışır)
    if (user != null) {
      cart.syncFromRemote();
    }

    // --------- GİRİŞ YOKSA: HESAP EKRANINA YÖNLENDİRMEK İÇİN BİLGİ ---------
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        appBar: AppBar(
          title: const Text('Sepetim'),
          centerTitle: true,
          backgroundColor: const Color(0xFF0B0F17),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sepetini görmek için giriş yapmalısın',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ermoneyt’te sepetin, favorilerin ve adreslerin hesabına bağlı olarak saklanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD166),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Giriş yap / Üye ol',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    // --------- GİRİŞ YAPILMIŞ: NORMAL SEPET ---------
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Sepetim'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: cart.loading && cartItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  itemCount: cartItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final p = item.product;
                    final q = item.quantity;

                    // Kampanyalı birim fiyat
                    final unitPrice = p.displayPrice;
                    final originalPrice = p.salePrice;
                    final lineTotal = unitPrice * q;

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131822),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          // ürün görseli
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (p.image ?? '').isNotEmpty
                                ? Image.network(
                                    p.image!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white38,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image,
                                    color: Colors.white38,
                                  ),
                          ),

                          // isim + adet + fiyatlar
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  right: 10, top: 12, bottom: 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Birim fiyat alanı
                                  if (p.hasCampaign) ...[
                                    Row(
                                      children: [
                                        Text(
                                          'Birim: ${unitPrice.toStringAsFixed(2)} ₺',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${originalPrice.toStringAsFixed(2)} ₺',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Text(
                                      'Birim: ${unitPrice.toStringAsFixed(2)} ₺',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _QtyChip(
                                        value: q,
                                        onChanged: (newQ) {
                                          if (newQ <= 0) {
                                            cart.remove(p.id);
                                          } else {
                                            cart.setQuantity(p.id, newQ);
                                          }
                                        },
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${lineTotal.toStringAsFixed(2)} ₺',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD166),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => cart.remove(p.id),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.white60,
                                      ),
                                      label: const Text(
                                        'Kaldır',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: cartItems.isEmpty
          ? const SizedBox.shrink()
          : _CartSummary(
              total: discountedTotal,
              onCheckout: () {
                // Burada artık ÖDEME EKRANI açılıyor
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CheckoutScreen(),
                  ),
                );
              },
            ),
    );
  }
}

/* ---------------------- BOŞ SEPET ---------------------- */

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sepetin boş',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Beğendiğin ürünleri sepete ekleyerek buradan görebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // BOŞ SEPETTE "ALIŞVERİŞE BAŞLA" -> ANASAYFA
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const MobileHomeScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                'Alışverişe başla',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* ---------------------- ADET BUTONU ---------------------- */

class _QtyChip extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QtyChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, () {
            if (value > 1) {
              onChanged(value - 1);
            } else {
              onChanged(0);
            }
          }),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$value',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _btn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 16),
        ),
      );
}

/* ---------------------- ALT ÖZET ---------------------- */

class _CartSummary extends StatelessWidget {
  final double total;
  final VoidCallback onCheckout;

  const _CartSummary({
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Toplam',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${total.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD166),
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
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onCheckout,
              child: const Text(
                'Alışverişi tamamla',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
