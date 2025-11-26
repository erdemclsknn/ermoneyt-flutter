// lib/screens/category_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import 'category_products_screen.dart';

class CategoryScreen extends StatelessWidget {
  /// Home’dan hazır ürün listesi gelebilir; gelmezse API’den çeker.
  final List<Product>? initialProducts;
  final String? openTopCategory;

  const CategoryScreen({
    super.key,
    this.initialProducts,
    this.openTopCategory,
  });

  @override
  Widget build(BuildContext context) {
    final hasInitial = (initialProducts != null && initialProducts!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: const Text('Kategoriler'),
      ),
      body: hasInitial
          ? _CategoryGrid(
              products: initialProducts!,
              openTopCategory: openTopCategory,
            )
          : FutureBuilder<List<Product>>(
              future: ApiService.fetchProducts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _ShimmerGrid();
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Bir şeyler ters gitti: ${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Kategori bulunamadı',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return _CategoryGrid(
                  products: items,
                  openTopCategory: openTopCategory,
                );
              },
            ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Product> products;
  final String? openTopCategory;

  const _CategoryGrid({
    required this.products,
    this.openTopCategory,
  });

  String _topCat(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return 'Diğer';
    return c.split('>').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    // Üst kategoriye göre grupla
    final Map<String, List<Product>> grouped = {};
    for (final p in products) {
      final t = _topCat(p.category);
      grouped.putIfAbsent(t, () => []).add(p);
    }
    final topCats = grouped.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86, // overflow güvenli
      ),
      itemCount: topCats.length,
      itemBuilder: (_, i) {
        final top = topCats[i];
        final list = grouped[top]!;
        final count = list.length;

        // Kategoride kampanyalı ürün var mı?
        final hasCampaignInCat = list.any((p) => p.hasCampaign);

        // Kapak görseli: görseli olan ilk ürün
        final withImage = list.firstWhere(
          (p) => (p.image ?? '').isNotEmpty,
          orElse: () => list.first,
        );
        final thumb = withImage.image;
        final hasThumb = (thumb ?? '').isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            // Bu üst başlık altındaki TÜM ürünler
            final inTop = products.where((p) {
              final c = (p.category ?? '').trim();
              return c == top || c.startsWith('$top >');
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(
                  category: top,        // yalnız üst adı
                  allProducts: inTop,   // üst altındaki tüm ürünler
                  initialSub: 'Tümü',   // chip default: Tümü
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131822),
              borderRadius: BorderRadius.circular(18),
              border: top == openTopCategory
                  ? Border.all(color: const Color(0xFFFFD166), width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Üst görsel alanı
                SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumb)
                        Image.network(
                          thumb!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image,
                                color: Colors.white38, size: 36),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(Icons.category,
                              color: Colors.white38, size: 36),
                        ),

                      // yumuşak alt gradient
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color.fromARGB(160, 11, 15, 23)
                            ],
                          ),
                        ),
                      ),

                      // adet rozeti
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD166),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Kampanyalı ürün varsa rozet
                      if (hasCampaignInCat)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Kampanya',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Alt metin alanı
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎯  $top',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$count ürün',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131822),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(height: 118, color: Colors.white10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(height: 16, color: Colors.white10),
                    Container(height: 12, color: Colors.white10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
