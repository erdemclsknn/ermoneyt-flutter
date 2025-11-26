// lib/screens/category_products_screen.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

/// Ürün liste ekranı (üstte alt-kategori chip'leri var)
class CategoryProductsScreen extends StatefulWidget {
  /// Kategori; "Üst" veya "Üst > Alt" biçiminde gelebilir.
  final String category;

  /// Ürünlerin tamamı (en azından bu üst kategori altındaki ürünler)
  final List<Product> allProducts;

  /// Opsiyonel: ilk açılışta seçili olacak alt kategori.
  /// (category "Üst > Alt" gelirse bu parametreye gerek yok)
  final String? initialSub;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.allProducts,
    this.initialSub,
  });

  @override
  State<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late String _topCategory;
  late List<String> _subCats; // ["Tümü", "Mutfak", "Banyo", ...]
  late String _selectedSub; // o an seçili chip

  @override
  void initState() {
    super.initState();

    // category parse
    final raw = widget.category.trim();
    if (raw.contains('>')) {
      final parts = raw.split('>').map((e) => e.trim()).toList();
      _topCategory = parts.first;
      _selectedSub = widget.initialSub ?? parts.sublist(1).join(' > ');
    } else {
      _topCategory = raw;
      _selectedSub = widget.initialSub ?? 'Tümü';
    }

    _subCats = _extractSubcats(widget.allProducts, _topCategory);

    // listede yoksa "Tümü"ye düş
    if (_selectedSub != 'Tümü' && !_subCats.contains(_selectedSub)) {
      _selectedSub = 'Tümü';
    }
  }

  /// Verilen üst kategori altındaki alt kategorileri çıkar.
  List<String> _extractSubcats(List<Product> all, String top) {
    final set = <String>{};
    for (final p in all) {
      final c = (p.category ?? '').trim();
      if (c.isEmpty) continue;

      if (!c.startsWith(top)) continue;

      // "Üst > Alt" veya "Üst > Alt > Alt2"...
      if (c.contains('>')) {
        final parts = c.split('>').map((e) => e.trim()).toList();
        if (parts.length >= 2) {
          // biz 2. parçayı alt kategori olarak alalım
          set.add(parts[1]);
        }
      }
    }

    final list = set.toList()..sort();
    return ['Tümü', ...list];
  }

  List<Product> _filtered() {
    // önce top kategoriye indir
    final inTop = widget.allProducts.where((p) {
      final c = (p.category ?? '').trim();
      return c == _topCategory || c.startsWith('$_topCategory >');
    }).toList();

    if (_selectedSub == 'Tümü') return inTop;

    return inTop.where((p) {
      final c = (p.category ?? '').trim();
      // "Üst > Alt" eşleşsin
      final wantedPrefix = '$_topCategory > $_selectedSub';
      return c == wantedPrefix || c.startsWith('$wantedPrefix >');
    }).toList();
  }

  /// Kartın alt kısmındaki fiyat widget'ı
  /// Kampanya varsa: sarı yeni fiyat + üstü çizili eski fiyat
  /// Kampanya adı gösterilmiyor.
  Widget _buildCardPrice(Product p) {
    if (p.hasCampaign) {
      return Row(
        children: [
          Text(
            '${p.displayPrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${p.salePrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    // Kampanya yoksa normal fiyat
    return Text(
      '${p.salePrice.toStringAsFixed(2)} ₺',
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filtered();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: Text(_topCategory),
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),

          // Chip şeridi (Tümü + alt kategoriler)
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final label = _subCats[i];
                final selected = label == _selectedSub;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSub = label),
                  selectedColor: const Color(0xFFFFD166),
                  backgroundColor: const Color(0xFF1A2230),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFFFD166)
                          : Colors.white12,
                      width: selected ? 1.4 : 1,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: _subCats.length,
            ),
          ),

          const SizedBox(height: 10),

          // Ürün sayısı info bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.filter_list,
                    size: 18, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  _selectedSub == 'Tümü'
                      ? '${products.length} ürün'
                      : '"$_selectedSub" için ${products.length} ürün',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Ürün grid
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'Bu filtre için ürün yok',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final hasImage = (p.image ?? '').isNotEmpty;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(product: p),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF131822),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Üst görsel (yükseklik sabit değil, Expanded)
                              Expanded(
                                flex: 6,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: Colors.white10,
                                      child: hasImage
                                          ? Image.network(
                                              p.image!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.image,
                                                color: Colors.white38,
                                                size: 40,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.image,
                                              color: Colors.white38,
                                              size: 40,
                                            ),
                                    ),
                                    // hafif alttan gradient
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black
                                                    .withOpacity(0.35),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // ufak rozet (displayPrice)
                                    Positioned(
                                      left: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withOpacity(0.55),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${p.displayPrice.toStringAsFixed(0)} ₺',
                                          style: const TextStyle(
                                            color: Color(0xFFFFD166),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Alt alan
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 10, 12, 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Kampanya destekli fiyat alanı
                                      _buildCardPrice(p),
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
          ),
        ],
      ),
    );
  }
}
