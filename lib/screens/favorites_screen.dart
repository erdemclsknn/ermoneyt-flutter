// lib/screens/favorites_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorilerim')),
        body: const Center(
          child: Text('Favorileri görmek için önce giriş yapmalısın.'),
        ),
      );
    }

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites');

    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: favRef.snapshots(),
        builder: (context, favSnap) {
          if (favSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (favSnap.hasError) {
            return Center(
              child: Text('Favoriler yüklenemedi: ${favSnap.error}'),
            );
          }

          final docs = favSnap.data?.docs ?? [];
          final favoriteProducts = docs
              .map((d) => Product.fromMap(d.data()))
              .toList(growable: false);

          // Hiç favori yoksa sadece info göster
          if (favoriteProducts.isEmpty) {
            return const Center(
              child: Text(
                'Henüz favori ürün eklemedin.\n'
                'Ürün detayından kalp ikonuna basarak\n'
                'favorilerine ekleyebilirsin.',
                textAlign: TextAlign.center,
              ),
            );
          }

          // Öneriler için tüm ürünleri API'den çek
          return FutureBuilder<List<Product>>(
            future: ApiService.fetchProducts(),
            builder: (context, prodSnap) {
              // Öneriler hata verse bile favorileri gösterelim,
              // o yüzden önce favori listesi hazırlanıyor.
              final favList = _buildFavoritesList(
                context,
                favRef,
                favoriteProducts,
              );

              if (prodSnap.connectionState == ConnectionState.waiting) {
                // Favoriler + altta loader
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ...favList,
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                );
              }

              List<Widget> suggestionSection = [];

              if (prodSnap.hasData && prodSnap.data!.isNotEmpty) {
                final allProducts = prodSnap.data!;
                final favIds = favoriteProducts.map((p) => p.id).toSet();

                // Favoride olmayan ürünlerden havuz oluştur
                final pool = allProducts
                    .where((p) => !favIds.contains(p.id))
                    .toList();

                if (pool.isNotEmpty) {
                  pool.shuffle(Random());
                  final suggestions = pool.take(10).toList();

                  suggestionSection = [
                    const SizedBox(height: 24),
                    const Text(
                      'Beğenebileceğiniz ürünler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 210,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final p = suggestions[index];
                          return _SuggestionCard(product: p);
                        },
                      ),
                    ),
                  ];
                }
              }

              // Ana scroll: favoriler + (varsa) öneriler
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ...favList,
                  ...suggestionSection,
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildFavoritesList(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> favRef,
    List<Product> products,
  ) {
    return [
      ...List.generate(products.length, (index) {
        final p = products[index];
        final img = p.image;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: p,
                    allProducts: const [],
                  ),
                ),
              );
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: (img != null && img.isNotEmpty)
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                        ),
                      )
                    : const Icon(Icons.image_outlined),
              ),
            ),
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${p.salePrice.toStringAsFixed(2)} ₺',
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await favRef.doc(p.id).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Favorilerden kaldırıldı')),
                );
              },
            ),
          ),
        );
      }),
    ];
  }
}

class _SuggestionCard extends StatelessWidget {
  final Product product;

  const _SuggestionCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final img = product.image;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              allProducts: const [],
            ),
          ),
        );
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F17),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2933)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (img != null && img.isNotEmpty)
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined),
                      )
                    : const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${product.salePrice.toStringAsFixed(2)} ₺',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFFD166),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
