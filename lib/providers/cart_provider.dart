// lib/providers/cart_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productMap =
        Map<String, dynamic>.from(json['product'] as Map<String, dynamic>);
    return CartItem(
      product: Product.fromJson(productMap),
      quantity: (json['quantity'] ?? 1) as int,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  bool _loadedFromRemote = false;
  bool _loading = false;

  Map<String, CartItem> get items => _items;
  bool get loading => _loading;

  int get itemCount =>
      _items.values.fold(0, (previous, e) => previous + e.quantity);

  /// Toplamı kampanyalı birim fiyat (displayPrice) * adet ile hesapla
  double get totalAmount => _items.values.fold(
        0.0,
        (previous, item) =>
            previous + item.product.displayPrice * item.quantity,
      );

  /* ---------- Firestore ref ---------- */

  CollectionReference<Map<String, dynamic>>? _userCartRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart');
  }

  /* ---------- Local helper ---------- */

  void _addLocal(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product, quantity: 1);
    }
  }

  void _setLocalQuantity(String productId, int quantity) {
    final item = _items[productId];
    if (item == null) return;
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      item.quantity = quantity;
    }
  }

  void _removeLocal(String productId) {
    _items.remove(productId);
  }

  /* ---------- Public API (UI bunları kullanıyor) ---------- */

  Future<void> addToCart(Product product) async {
    _addLocal(product);
    notifyListeners();
    await _syncItemToFirestore(product.id);
  }

  Future<void> setQuantity(String productId, int quantity) async {
    _setLocalQuantity(productId, quantity);
    notifyListeners();
    await _syncItemToFirestore(productId);
  }

  Future<void> remove(String productId) async {
    _removeLocal(productId);
    notifyListeners();
    await _deleteItemFromFirestore(productId);
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _clearRemoteCart();
  }

  /* ---------- Firestore yazma ---------- */

  Future<void> _syncItemToFirestore(String productId) async {
    final ref = _userCartRef();
    if (ref == null) return;

    final item = _items[productId];
    if (item == null || item.quantity <= 0) {
      await ref.doc(productId).delete();
      return;
    }

    await ref.doc(productId).set(
      {
        'product': item.product.toJson(), // mobil tarafın kullandığı yapı
        'productId': item.product.id,
        'name': item.product.name,
        'image': item.product.image,
        'displayPrice': item.product.displayPrice,
        'price': item.product.displayPrice,
        'salePrice': item.product.salePrice,
        'hasCampaign': item.product.hasCampaign,
        'quantity': item.quantity, // mobil
        'qty': item.quantity, // web tarafı da bunu okuyabilsin
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _deleteItemFromFirestore(String productId) async {
    final ref = _userCartRef();
    if (ref == null) return;
    await ref.doc(productId).delete();
  }

  Future<void> _clearRemoteCart() async {
    final ref = _userCartRef();
    if (ref == null) return;
    final snap = await ref.get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }

  /* ---------- Firestore'dan okuma ---------- */

  /// Kullanıcı giriş yapmışsa Firestore'daki sepeti 1 kez çeker.
  /// Hem MOBİL'in yazdığı dokümanları (product + quantity),
  /// hem WEB'in yazdığı dokümanları (productId + name + displayPrice + qty)
  /// anlayacak şekilde parse ediyor.
  Future<void> syncFromRemote() async {
    final ref = _userCartRef();
    if (ref == null || _loadedFromRemote) return;

    _loading = true;
    notifyListeners();

    try {
      final snap = await ref.get();
      _items.clear();

      for (final doc in snap.docs) {
        final data = doc.data();

        // 1) Mobil yapısı: product: {...}, quantity
        Product? product;
        if (data['product'] is Map<String, dynamic>) {
          final productMap =
              Map<String, dynamic>.from(data['product'] as Map<String, dynamic>);
          product = Product.fromJson(productMap);
        }

        // 2) Eğer product map yoksa ya da boşsa, WEB'in flatten dokümanını ele
        if (product == null) {
          final String id =
              (data['productId'] ?? data['id'] ?? doc.id).toString();

          final String name = (data['name'] ??
                  data['title'] ??
                  data['productName'] ??
                  'Ürün')
              .toString();

          String? image =
              data['image'] as String? ?? data['imageUrl'] as String?;

          final num priceNum =
              (data['displayPrice'] ?? data['salePrice'] ?? data['price'] ?? 0)
                  as num;

          final num? salePriceNum = data['salePrice'] as num?;
          final bool hasCampaign = data['hasCampaign'] == true;

          // Product.fromJson'in anlayacağı şekilde bir json oluştur
          final Map<String, dynamic> productJson = {
            'id': id,
            'name': name,
            'image': image,
            'price': priceNum.toDouble(),
            'salePrice': salePriceNum?.toDouble(),
            'finalPrice': priceNum.toDouble(),
            'hasCampaign': hasCampaign,
            'campaign': hasCampaign ? {'title': 'Web Kampanya'} : null,
          };

          product = Product.fromJson(productJson);
        }

        // ---- ADET ----
        final int quantity =
            ((data['quantity'] ?? data['qty'] ?? 1) as num).toInt();

        // anlamsız kayıtları ele
        if (quantity <= 0) continue;

        _items[product.id] = CartItem(
          product: product,
          quantity: quantity,
        );
      }

      _loadedFromRemote = true;
    } catch (e, st) {
      if (kDebugMode) {
        print('syncFromRemote error: $e\n$st');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
