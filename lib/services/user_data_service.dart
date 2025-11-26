import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';

class FavoriteItem {
  final String id;          // doc id (productId)
  final String name;
  final String? image;
  final double price;

  FavoriteItem({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
  });

  factory FavoriteItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FavoriteItem(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      image: data['image'] as String?,
      price: (data['price'] ?? 0).toDouble(),
    );
  }
}

class UserDataService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _favCol(String uid) {
    return _db.collection('users').doc(uid).collection('favorites');
  }

  /// Ürün şu an favoride mi?
  Future<bool> isFavorite(String productId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _favCol(uid).doc(productId).get();
    return doc.exists;
  }

  /// Favori durumunu tersine çevirir.
  /// true dönerse artık favoridir, false dönerse favoriden çıkmıştır.
  Future<bool> toggleFavorite(Product p) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Kullanıcı giriş yapmamış');
    }

    final ref = _favCol(uid).doc(p.id);
    final snap = await ref.get();

    if (snap.exists) {
      // zaten favoriydi, kaldır
      await ref.delete();
      return false;
    } else {
      await ref.set({
        'productId': p.id,
        'name': p.name,
        'image': p.image,
        'price': p.salePrice,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  /// Kullanıcının favorilerini dinler.
  Stream<List<FavoriteItem>> favoritesStream() {
    final uid = _uid;
    if (uid == null) {
      // login yoksa boş liste stream
      return const Stream<List<FavoriteItem>>.empty();
    }

    return _favCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FavoriteItem.fromDoc(d)).toList());
  }
}
