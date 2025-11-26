// lib/screens/subcategory_screen.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'category_products_screen.dart';

class SubcategoryScreen extends StatelessWidget {
  final String topCategory;
  final List<Product> allProducts;

  const SubcategoryScreen({
    super.key,
    required this.topCategory,
    required this.allProducts,
  });

  // ---- helpers ----
  String _topCat(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return '';
    return c.split('>').first.trim();
  }

  String? _subCat(String? raw) {
    final c = (raw ?? '').trim();
    if (!c.contains('>')) return null;
    final parts = c.split('>').map((e) => e.trim()).toList();
    return parts.length >= 2 ? parts[1] : null;
  }

  @override
  Widget build(BuildContext context) {
    // Bu üst kategorideki tüm ürünler
    final inTop = allProducts.where((p) => _topCat(p.category) == topCategory).toList();

    // Alt kategori -> ürün listesi
    final Map<String, List<Product>> grouped = {};
    for (final p in inTop) {
      final sub = _subCat(p.category) ?? 'Diğer';
      grouped.putIfAbsent(sub, () => []).add(p);
    }
    final subCats = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: Text(topCategory),
      ),
      body: subCats.isEmpty
          ? const Center(
              child: Text('Alt kategori yok', style: TextStyle(color: Colors.white70)),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86, // overflow güvenli
              ),
              itemCount: subCats.length,
              itemBuilder: (context, i) {
                final sub = subCats[i];
                final list = grouped[sub]!;
                final count = list.length;

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
                    // Ürün listesi ekranına git; chip seçili gelsin
                    final allUnderTop = allProducts.where((p) {
                      final c = (p.category ?? '').trim();
                      return c == topCategory || c.startsWith('$topCategory >');
                    }).toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(
                          category: topCategory,          // üst ad
                          allProducts: allUnderTop,       // üst altındaki tüm ürünler
                          initialSub: sub,                // seçili chip
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF131822),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
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
                                    child: Icon(Icons.image, color: Colors.white38, size: 36),
                                  ),
                                )
                              else
                                const Center(
                                  child: Icon(Icons.photo, color: Colors.white38, size: 36),
                                ),
                              // yumuşak alt gradient
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color.fromARGB(160, 11, 15, 23)],
                                  ),
                                ),
                              ),
                              // adet rozeti
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            ],
                          ),
                        ),
                        // Alt metin
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '🧩  $sub',
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
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
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
            ),
    );
  }
}
