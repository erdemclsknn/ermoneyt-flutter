// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/user_data_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  /// Öneri bölümünde kullanmak için isteğe bağlı tüm ürün listesi.
  final List<Product>? allProducts;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.allProducts,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  // FAVORİLER
  final _userData = UserDataService();
  bool _isFav = false;
  bool _favLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // login yoksa uğraşma
    final fav = await _userData.isFavorite(widget.product.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorilere eklemek için önce giriş yapmalısın.'),
        ),
      );
      return;
    }

    if (_favLoading) return;
    setState(() => _favLoading = true);

    try {
      final nowFav = await _userData.toggleFavorite(widget.product);
      if (mounted) setState(() => _isFav = nowFav);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favori işlemi başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  // ---- Görselleri topla (image + additionalImages + description içi) ----
  List<String> _images(Product p) {
    final urls = <String>{};

    Uri? base;

    // Ana görsel
    if (p.image != null && p.image!.trim().isNotEmpty) {
      final main = p.image!.trim();
      if (main.startsWith('http')) {
        urls.add(main);
        base = Uri.tryParse(main);
      }
    }

    // URL'leri normalize eden yardımcı fonksiyon
    void addOne(String? raw) {
      if (raw == null) return;
      var s = raw.trim();
      if (s.isEmpty) return;

      // XML tarafında &amp; vs. gelebilir, biraz toparlayalım
      s = s.replaceAll('&amp;', '&');

      if (s.startsWith('http')) {
        urls.add(s);
      } else if (base != null) {
        // Göreli path ise ana resmin domainine göre tamamla
        final resolved = base.resolve(s).toString();
        urls.add(resolved);
      }
    }

    // additionalImages -> bunlar zaten XML'den geliyor
    for (final img in p.additionalImages) {
      addOne(img);
    }

    // Description içindeki <img src="..."> leri yakala
    final desc = p.description ?? '';
    if (desc.isNotEmpty) {
      final exp =
          RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
      for (final m in exp.allMatches(desc)) {
        addOne(m.group(1));
      }

      // Ekstra garanti: description’da çıplak http linkleri de topla
      final reg = RegExp(r'https?://\S+');
      for (final m in reg.allMatches(desc)) {
        addOne(m.group(0));
      }
    }

    // Eğer hala hiç resim yoksa en azından tek bir boş state dön
    if (urls.isEmpty && p.image != null && p.image!.trim().isNotEmpty) {
      urls.add(p.image!.trim());
    }

    return urls.toList();
  }

  // Aynı kategoriden “bunlara da göz atın” öneri ürünleri
  List<Product> _buildSuggestions(Product current) {
    final all = widget.allProducts;
    if (all == null || all.isEmpty) return [];

    final currentCat = (current.category ?? '').trim();

    final sameCat = all.where((p) {
      if (p.id == current.id) return false;
      return (p.category ?? '').trim() == currentCat;
    }).toList();

    final others = all.where((p) {
      if (p.id == current.id) return false;
      return !sameCat.contains(p);
    }).toList();

    final List<Product> merged = [];
    merged.addAll(sameCat);
    merged.addAll(others);

    return merged.take(10).toList();
  }

  // HTML kırp ve sadeleştir
  String _clean(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    return s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _toBulletLines(String text) {
    final raw =
        text.replaceAll('\r', '\n').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
    final lines = raw.split('\n');
    if (lines.length >= 3) return lines;
    return raw
        .split(RegExp(r'\.\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final imgs = _images(p);
    final desc = _clean(p.description);
    final suggestions = _buildSuggestions(p);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: const Color(0xFF0B0F17),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 320,
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                onPressed: _favLoading ? null : _toggleFavorite,
                icon: Icon(
                  _isFav ? Icons.favorite : Icons.favorite_border,
                  color: _isFav ? Colors.redAccent : Colors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(
                images: imgs,
                heroTagBase: p.id,
                onTapImage: (i) => _openFullscreen(imgs, i, p.id),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Kampanya rozeti (varsa)
                  if (p.hasCampaign && p.campaign != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.shade400,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p.campaign!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Fiyat kartı (TOPLAM fiyat qty ile çarpılır)
                  _PriceCard(product: p, qty: _qty),
                  const SizedBox(height: 14),

                  // Adet
                  Row(
                    children: [
                      const Text(
                        'Adet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      _QtyPicker(
                        value: _qty,
                        onChanged: (v) => setState(() => _qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Küçük rozetler
                  Wrap(
                    spacing: 8,
                    runSpacing: -6,
                    children: [
                      if ((p.category ?? '').isNotEmpty)
                        _chip('Kategori: ${p.category}'),
                      _chip('Hızlı Gönderi'),
                      _chip('Güvenli Paket'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Açıklama
                  if (desc.isNotEmpty) ...[
                    const Text(
                      'Ürün Açıklaması',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ExpandableDescription(lines: _toBulletLines(desc)),
                    const SizedBox(height: 24),
                  ],

                  // Basit özellik tablosu
                  _SpecTable(product: p),
                  const SizedBox(height: 24),

                  // Bunlara da göz atın
                  if (suggestions.isNotEmpty) ...[
                    const Text(
                      'Bunlara da göz atabilirsiniz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 4),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final sp = suggestions[index];
                          final hasImage = (sp.image ?? '').isNotEmpty;

                          Widget priceWidget;
                          if (sp.hasCampaign) {
                            priceWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sp.displayPrice.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${sp.salePrice.toStringAsFixed(2)} ₺',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        decoration:
                                            TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.local_offer,
                                      color: Colors.greenAccent,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            priceWidget = Text(
                              '${sp.salePrice.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                color: Color(0xFFFFD166),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: sp,
                                    allProducts: widget.allProducts,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: const Color(0xFF131822),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: hasImage
                                        ? Image.network(
                                            sp.image!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                              color: Colors.white38,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.image,
                                            color: Colors.white38,
                                            size: 40,
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    sp.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  priceWidget,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(product: p, qty: _qty),
    );
  }

  Widget _chip(String text) => Chip(
        label: Text(text),
        labelStyle: const TextStyle(color: Colors.black),
        backgroundColor: const Color(0xFFFFD166),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      );

  void _openFullscreen(List<String> images, int index, String heroBase) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          images: images,
          initial: index,
          heroTagBase: heroBase,
        ),
      ),
    );
  }
}

/* ------------------------- GALERİ ------------------------- */

class _Gallery extends StatefulWidget {
  final List<String> images;
  final void Function(int index)? onTapImage;
  final String heroTagBase;
  const _Gallery({
    required this.images,
    required this.heroTagBase,
    this.onTapImage,
  });

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.98);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.images.isNotEmpty;
    return Stack(
      children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: hasAny ? widget.images.length : 1,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            if (!hasAny) {
              return _frame(
                child: const Icon(
                  Icons.image,
                  size: 72,
                  color: Colors.white24,
                ),
              );
            }
            final url = widget.images[i];
            final tag = '${widget.heroTagBase}-$i';
            return GestureDetector(
              onTap: () => widget.onTapImage?.call(i),
              child: Hero(
                tag: tag,
                child: _frame(
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Üst gradient (AppBar yazısı kaybolmasın)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: .55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sayfa sayacı
        if (hasAny && widget.images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _frame({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(color: Colors.white10, child: child),
      ),
    );
  }
}

/* --------------------- FULLSCREEN GALLERY --------------------- */

class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initial;
  final String heroTagBase;
  const _FullscreenGallery({
    required this.images,
    required this.initial,
    required this.heroTagBase,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initial);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: imgs.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final tag = '${widget.heroTagBase}-$i';
                return Center(
                  child: Hero(
                    tag: tag,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.network(
                        imgs[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 80,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / ${imgs.length}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------- FİYAT KARTI ------------------------- */

class _PriceCard extends StatelessWidget {
  final Product product;
  final int qty; // TOPLAM için
  const _PriceCard({required this.product, required this.qty});

  @override
  Widget build(BuildContext context) {
    final bool hasCamp = product.hasCampaign;
    final double unitPrice = product.displayPrice;
    final double total = unitPrice * qty;
    final double? oldTotal =
        hasCamp ? product.salePrice * qty : null;

    String discountLabel = '';
    if (hasCamp) {
      if (product.campaign?.discountType == 'PERCENT') {
        final v = product.campaign!.discountValue;
        discountLabel = '%${v.toStringAsFixed(0)} indirim';
      } else {
        final diff = product.salePrice - unitPrice;
        if (diff > 0) {
          discountLabel = '${diff.toStringAsFixed(0)} ₺ indirim';
        }
      }
    }

    // Stok durumu
    final bool inStock = (product.stock > 0) &&
        !((product.availability ?? '')
            .toLowerCase()
            .contains('out'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oldTotal != null) ...[
                  Text(
                    '${oldTotal.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      color: Colors.white60,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  '${total.toStringAsFixed(2)} ₺',
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Birim: ${unitPrice.toStringAsFixed(2)} ₺  •  Adet: $qty',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (hasCamp && discountLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        size: 16,
                        color: Colors.greenAccent.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        discountLabel,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: inStock ? Colors.green.shade600 : Colors.grey.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              inStock ? 'Stokta' : 'Tükendi',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- ADET SEÇİCİ ------------------------- */

class _QtyPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QtyPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, () {
            if (value > 1) onChanged(value - 1);
          }),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _btn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 18),
        ),
      );
}

/* ------------------------- AÇIKLAMA ------------------------- */

class _ExpandableDescription extends StatefulWidget {
  final List<String> lines;
  const _ExpandableDescription({required this.lines});

  @override
  State<_ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final display = _expanded ? widget.lines : widget.lines.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...display.map((e) {
          final line = e.trim();
          if (line.isEmpty) return const SizedBox.shrink();
          final bulletRemoved =
              line.replaceFirst(RegExp(r'^[-•]\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•',
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bulletRemoved,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (widget.lines.length > 6)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Daha az göster' : 'Tümünü göster',
              style: const TextStyle(color: Color(0xFFFFD166)),
            ),
          ),
      ],
    );
  }
}

/* ------------------------- ÖZELLİK TABLOSU ------------------------- */

class _SpecTable extends StatelessWidget {
  final Product product;
  const _SpecTable({required this.product});

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[];

    void addIf(String key, dynamic val) {
      final s = (val == null) ? '' : '$val'.trim();
      if (s.isNotEmpty) rows.add(MapEntry(key, s));
    }

    addIf('Kategori', product.category);
    addIf('Marka', product.brand);

    // Ek alanlar yoksa bile eski dinamik yapı kalsın (ileride genişletirsin)
    try {
      addIf('Renk', (product as dynamic).color);
      addIf('Boyut', (product as dynamic).size);
      addIf('Materyal', (product as dynamic).material);
    } catch (_) {}

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: rows.map((e) {
          final isLast = rows.last == e;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Colors.white10, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    e.value,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ------------------------- ALT BAR ------------------------- */

class _BottomBar extends StatelessWidget {
  final Product product;
  final int qty;
  const _BottomBar({required this.product, required this.qty});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SizedBox(
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
          onPressed: () {
            final cart = context.read<CartProvider>();
            for (int i = 0; i < qty; i++) {
              cart.addToCart(product);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sepete eklendi: $qty adet'),
              ),
            );
          },
          child: const Text(
            'Sepete ekle',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
