// lib/screens/mobile_home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../models/product.dart';
import '../models/banner_model.dart';

import 'product_detail_screen.dart';
import 'category_screen.dart';
import 'category_products_screen.dart';
import 'cart_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  late Future<_HomeData> _future;
  String _search = '';

  /// Kampanya popup’ını sadece 1 kere göstermek için flag
  bool _campaignPopupShown = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final products = await ApiService.fetchProducts();
    final banners = await ApiService.fetchBanners();
    return _HomeData(products: products, banners: banners);
  }

  Future<void> _refresh() async {
    final data = await _load();
    setState(() => _future = Future.value(data));
  }

  // ---- helpers ----
  List<T> _dailyShuffle<T>(List<T> list) {
    if (list.isEmpty) return list;
    final daySeed =
        DateTime.now().toUtc().difference(DateTime(2020, 1, 1)).inDays;
    final rnd = _SimpleRandom(daySeed);
    final items = List<T>.from(list);
    for (int i = items.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
    return items;
  }

  String _topCat(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return '';
    return c.split('>').first.trim();
  }

  Map<String, List<Product>> _groupByTopCategory(List<Product> products) {
    final map = <String, List<Product>>{};
    for (final p in products) {
      final key = _topCat(p.category);
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  /// Banner listesinde popup olarak kullanılacak banner’ı bul
  /// Admin panelde işaretlediğin `isPopup == true` + place=mobile/both olan ilk banner
BannerModel? _findCampaignPopup(List<BannerModel> banners) {
  for (final b in banners) {
    if (b.isPopup == true) {
      // place zaten String, null olamaz; ?? gerek yok
      final place = b.place.toLowerCase();
      if (place.isEmpty || place == 'mobile' || place == 'both') {
        return b;
      }
    }
  }
  return null;
}

  /// Kampanya popup dialog (tüm kampanyalı ürünler için)
  void _showCampaignPopup(
    BuildContext context, {
    required BannerModel banner,
    required List<Product> campaignProducts,
  }) {
    if (campaignProducts.isEmpty) {
      // Kampanyalı ürün yoksa bilgi popup’ı
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF131822),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (banner.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      banner.imageUrl,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  banner.title.isNotEmpty
                      ? banner.title
                      : 'Kampanya fırsatı!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bu kampanyaya ait ürün bulunamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(color: Color(0xFFFFD166)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF131822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (banner.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    banner.imageUrl,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                banner.title.isNotEmpty ? banner.title : 'Kampanya fırsatı!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '% indirimli ürünleri görmek için aşağıdaki butona tıkla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD166),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryProductsScreen(
                            category: banner.title.isNotEmpty
                                ? banner.title
                                : 'Kampanyalı Ürünler',
                            allProducts: campaignProducts,
                          ),
                        ),
                      );
                    },
                    child: const Text('Ürünlere Git'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.pushNamed(context, CartScreen.routeName);
            },
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null || data.products.isEmpty) {
            return const Center(child: Text('Şu an yayınlanmış ürün yok'));
          }

          // Tüm kampanyalı ürünler
          final campaignProducts =
              data.products.where((p) => p.hasCampaign).toList();

          // Açılışta kampanya popup’ını bir kere göster (isPopup == true olan banner)
          final popupBanner = _findCampaignPopup(data.banners);
          if (!_campaignPopupShown &&
              popupBanner != null &&
              campaignProducts.isNotEmpty) {
            _campaignPopupShown = true;
            // instance null değil, bu yüzden ! veya ? gereksiz, direkt kullan
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCampaignPopup(
                context,
                banner: popupBanner,
                campaignProducts: campaignProducts,
              );
            });
          }

          final grouped = _groupByTopCategory(data.products);
          final allTopCats = grouped.keys.toList()..sort();

          final filteredProducts = _search.isEmpty
              ? data.products
              : data.products
                  .where((p) =>
                      p.name.toLowerCase().contains(_search.toLowerCase()) ||
                      (p.category ?? '')
                          .toLowerCase()
                          .contains(_search.toLowerCase()))
                  .toList();

          final dailyPopular = _dailyShuffle(data.products).take(12).toList();

          final dailyPerCat = <Product>[];
          for (final cat in allTopCats) {
            final list = _dailyShuffle(grouped[cat]!);
            if (list.isNotEmpty) dailyPerCat.add(list.first);
          }
          final todays = dailyPerCat.take(6).toList();

          final topBannerList = data.banners;
          final secondBanner =
              data.banners.length > 1 ? data.banners[1] : null;

          // Anasayfada, kampanyaların ALTINDA gösterilecek kategori bölümleri
          // (örnek: ilk 3 ana kategori, her biri yatay kaydırmalı)
          final categorySections = <Widget>[];
          const maxCategorySections = 3;
          int addedSections = 0;

          for (final cat in allTopCats) {
            if (addedSections >= maxCategorySections) break;
            final catProducts = grouped[cat] ?? [];
            if (catProducts.isEmpty) continue;

            final sample = _dailyShuffle(catProducts).take(10).toList();
            if (sample.isEmpty) continue;

            categorySections.add(
              _CategoryProductsSection(
                category: cat,
                products: sample,
                onMore: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryProductsScreen(
                        category: cat,
                        allProducts: catProducts,
                      ),
                    ),
                  );
                },
              ),
            );
            categorySections.add(const SizedBox(height: 16));
            addedSections++;
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopSearchBar(
                    value: _search,
                    onChanged: (v) => setState(() => _search = v),
                    onClear: () => setState(() => _search = ''),
                  ),
                  if (topBannerList.isNotEmpty)
                    _BannerSlider(
                      banners: topBannerList,
                      allProducts: data.products,
                    ),
                  const SizedBox(height: 12),

                  _CategoryStrip(
                    categories: allTopCats,
                    allProducts: data.products,
                    grouped: grouped,
                  ),
                  const SizedBox(height: 16),

                  _HorizontalProducts(
                    title:
                        _search.isEmpty ? 'Popüler Ürünler' : 'Arama Sonuçları',
                    products: (_search.isNotEmpty
                            ? filteredProducts
                            : dailyPopular)
                        .take(8)
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  if (secondBanner != null)
                    _WideBanner(
                      banner: secondBanner,
                      allProducts: data.products,
                    ),
                  const SizedBox(height: 16),

                  _FlashGrid(
                    title: 'Günün Ürünleri',
                    products: todays,
                    onMore: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryScreen(
                            initialProducts: data.products,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Kampanyalı ürünler bölümü
                  if (campaignProducts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _HorizontalProducts(
                      title: 'Kampanyalı Ürünler',
                      products: campaignProducts.take(12).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Kampanyaların ALTINDA: birkaç kategoriden ürünler (kaydırmalı + sonda "Daha fazlası")
                  ...categorySections,

                  const SizedBox(height: 12),
                  const _AltinkapFooter(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ================= components ================= */

class _TopSearchBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _TopSearchBar({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131822),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            const Icon(Icons.search, size: 20, color: Colors.white54),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ürün veya kategori ara...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (value.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

/* ----------- OTOMATİK KAYAN BANNER SLIDER ----------- */

class _BannerSlider extends StatefulWidget {
  final List<BannerModel> banners;
  final List<Product> allProducts;
  const _BannerSlider({required this.banners, required this.allProducts});

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.banners.length <= 1) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
      _index = next;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTap(BannerModel b) {
    final context = this.context;

    if (b.targetType == 'category') {
      final target = b.targetValue.trim().toLowerCase();
      final matched = widget.allProducts.where((p) {
        final cat = (p.category ?? '').toLowerCase();
        return cat.contains(target);
      }).toList();

      if (matched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori bulunamadı: ${b.targetValue}')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryProductsScreen(
            category: matched.first.category ?? b.targetValue,
            allProducts: matched,
          ),
        ),
      );
      return;
    }

    if (b.targetType == 'product') {
      final p = widget.allProducts.firstWhere(
        (e) => e.id == b.targetValue,
        orElse: () => widget.allProducts.first,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
      );
      return;
    }

    // URL hedefi
    if (b.targetType == 'url' && b.targetValue.isNotEmpty) {
      final uri = Uri.tryParse(b.targetValue);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;

    return SizedBox(
      height: 170,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final b = banners[index];
                return GestureDetector(
                  onTap: () => _onTap(b),
                  child: Container(
                    margin:
                        const EdgeInsets.only(left: 10, right: 10, top: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.grey[800],
                            child: b.imageUrl.isNotEmpty
                                ? Image.network(
                                    b.imageUrl,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.10),
                                    Colors.black.withValues(alpha: 0.65),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Text(
                              b.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) {
              final selected = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD166)
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/* ----------- WIDE BANNER ----------- */

class _WideBanner extends StatelessWidget {
  final BannerModel banner;
  final List<Product> allProducts;
  const _WideBanner({required this.banner, required this.allProducts});

  void _onTap(BuildContext context) {
    if (banner.targetType == 'category') {
      final target = banner.targetValue.trim().toLowerCase();
      final matched = allProducts.where((p) {
        final cat = (p.category ?? '').toLowerCase();
        return cat.contains(target);
      }).toList();

      if (matched.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryProductsScreen(
            category: matched.first.category ?? banner.targetValue,
            allProducts: matched,
          ),
        ),
      );
      return;
    }

    if (banner.targetType == 'product') {
      final p = allProducts.firstWhere(
        (e) => e.id == banner.targetValue,
        orElse: () => allProducts.first,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
      );
      return;
    }

    if (banner.targetType == 'url' && banner.targetValue.isNotEmpty) {
      final uri = Uri.tryParse(banner.targetValue);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: Colors.deepOrange[400],
                child: banner.imageUrl.isNotEmpty
                    ? Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
              if (banner.title.isNotEmpty)
                Positioned(
                  left: 18,
                  right: 40,
                  top: 24,
                  child: Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
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

/* ----------- KATEGORİ STRIP ----------- */

class _CategoryStrip extends StatelessWidget {
  final List<String> categories;
  final List<Product> allProducts;
  final Map<String, List<Product>> grouped;
  const _CategoryStrip({
    required this.categories,
    required this.allProducts,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    final displayCats = ['Kategoriler', ...categories.take(12)];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: displayCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final label = displayCats[i];
          final isAll = i == 0;

          String? thumb;
          if (!isAll && grouped[label]?.isNotEmpty == true) {
            final first = grouped[label]!.firstWhere(
              (p) => (p.image ?? '').isNotEmpty,
              orElse: () => grouped[label]!.first,
            );
            thumb = first.image;
          }
          final hasThumb = thumb != null && thumb.isNotEmpty;

          return GestureDetector(
            onTap: () {
              if (isAll) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryScreen(
                      initialProducts: allProducts,
                    ),
                  ),
                );
              } else {
                final matched = allProducts.where((p) {
                  final cat = (p.category ?? '').toLowerCase();
                  return cat.startsWith(label.toLowerCase());
                }).toList();

                if (matched.isEmpty) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryProductsScreen(
                      category: label,
                      allProducts: matched,
                    ),
                  ),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF131822),
                  backgroundImage: hasThumb ? NetworkImage(thumb) : null,
                  child: hasThumb
                      ? null
                      : Icon(isAll ? Icons.apps : Icons.category,
                          color: Colors.white),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ----------- HORIZONTAL URUNLER ----------- */

class _HorizontalProducts extends StatelessWidget {
  final String title;
  final List<Product> products;

  const _HorizontalProducts({
    required this.title,
    required this.products,
  });

  Widget _buildPrice(Product p) {
    if (p.hasCampaign) {
      return Row(
        children: [
          Text(
            '${p.displayPrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${p.salePrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${p.salePrice.toStringAsFixed(2)} ₺',
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = products[index];
              final hasImage = (p.image ?? '').isNotEmpty;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: p),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131822),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasImage
                            ? Image.network(p.image ?? '', fit: BoxFit.cover)
                            : const Icon(Icons.image, color: Colors.white38),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      _buildPrice(p),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ----------- KATEGORİ BAZLI HORIZONTAL + "DAHA FAZLASI" ----------- */

class _CategoryProductsSection extends StatelessWidget {
  final String category;
  final List<Product> products;
  final VoidCallback onMore;

  const _CategoryProductsSection({
    required this.category,
    required this.products,
    required this.onMore,
  });

  Widget _buildPrice(Product p) {
    if (p.hasCampaign) {
      return Row(
        children: [
          Text(
            '${p.displayPrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${p.salePrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${p.salePrice.toStringAsFixed(2)} ₺',
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    // +1: en sonda "Daha fazlası" kartı
    final itemCount = products.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Son kart = Daha fazlası
              if (index == products.length) {
                return GestureDetector(
                  onTap: onMore,
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131822),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD166)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Daha Fazlası',
                            style: TextStyle(
                              color: Color(0xFFFFD166),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 13, color: Color(0xFFFFD166)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final p = products[index];
              final hasImage = (p.image ?? '').isNotEmpty;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: p),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131822),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasImage
                            ? Image.network(p.image ?? '', fit: BoxFit.cover)
                            : const Icon(Icons.image, color: Colors.white38),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      _buildPrice(p),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ----------- GUNUN URUNLERI GRID ----------- */

class _FlashGrid extends StatelessWidget {
  final String title;
  final List<Product> products;
  final VoidCallback onMore;
  const _FlashGrid({
    required this.title,
    required this.products,
    required this.onMore,
  });

  Widget _buildPrice(Product p) {
    if (p.hasCampaign) {
      return Row(
        children: [
          Text(
            '${p.displayPrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${p.salePrice.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${p.salePrice.toStringAsFixed(2)} ₺',
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              TextButton(
                onPressed: onMore,
                child: const Text(
                  'Daha Fazla',
                  style: TextStyle(color: Color(0xFFFFD166)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Text('Şu an ürün yok',
                style: TextStyle(color: Colors.white54))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final p = products[index];
                final hasImage = (p.image ?? '').isNotEmpty;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: p),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF131822),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasImage
                              ? Image.network(p.image ?? '', fit: BoxFit.cover)
                              : const Icon(Icons.image, color: Colors.white38),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildPrice(p),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/* ----------- FOOTER ----------- */

class _AltinkapFooter extends StatelessWidget {
  const _AltinkapFooter();

  static final Uri _storeUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.altinkap.kebirgame',
  );

  Future<void> _openStore() async {
    if (!await launchUrl(_storeUri, mode: LaunchMode.externalApplication)) {
      await launchUrl(_storeUri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.videogame_asset,
              size: 34, color: Color(0xFFFFD166)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AltınKap Oyunları • Oyna, taş kazan, çekilişlere katıl!',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _openStore,
            child: const Text(
              'Hemen Dene',
              style: TextStyle(color: Color(0xFFFFD166)),
            ),
          ),
        ],
      ),
    );
  }
}

/* dto */
class _HomeData {
  final List<Product> products;
  final List<BannerModel> banners;
  _HomeData({required this.products, required this.banners});
}

/* Basit deterministik RNG (seed’li) */
class _SimpleRandom {
  int _state;
  _SimpleRandom(int seed) : _state = seed ^ 0x5DEECE66D;

  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }
}