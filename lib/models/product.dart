// lib/models/product.dart

/// Backend'den gelen kampanya bilgisi
class CampaignInfo {
  final String id;
  final String name;
  final String discountType; // "PERCENT" / "AMOUNT"
  final double discountValue;
  final String? startAt;
  final String? endAt;
  final bool? isActive;

  const CampaignInfo({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
    this.startAt,
    this.endAt,
    this.isActive,
  });

  factory CampaignInfo.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    return CampaignInfo(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      discountType: (map['discountType'] ?? '').toString(),
      discountValue: toDouble(map['discountValue']),
      startAt: map['startAt'] as String?,
      endAt: map['endAt'] as String?,
      isActive: map['isActive'] as bool?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'discountType': discountType,
        'discountValue': discountValue,
        'startAt': startAt,
        'endAt': endAt,
        'isActive': isActive,
      };
}

class Product {
  final String id;
  final String name;
  final String? description;
  final String? brand;

  final double basePrice;
  final double? xmlPriceWithTax;
  final double salePrice;

  /// Kampanya ile gelen fiyat (backend finalPrice)
  final double? finalPrice;

  /// Kampanya nesnesi (id, ad, oran vs.)
  final CampaignInfo? campaign;

  /// Ürün hangi kampanyaya bağlı (popup / filtre için)
  final String? campaignId;

  /// Arayüzde kolay kontrol
  bool get hasCampaign =>
      finalPrice != null &&
      finalPrice! > 0 &&
      finalPrice! < salePrice &&
      (campaign?.isActive ?? true);

  /// Ekranda gösterilecek ana fiyat
  double get displayPrice =>
      hasCampaign && finalPrice != null ? finalPrice! : salePrice;

  final String? category;
  final int stock;
  final String? availability;

  final String? image;
  final List<String> additionalImages;
  final String source; // xml / manual

  Product({
    required this.id,
    required this.name,
    this.description,
    this.brand,
    required this.basePrice,
    this.xmlPriceWithTax,
    required this.salePrice,
    this.finalPrice,
    this.campaign,
    this.campaignId,
    this.category,
    required this.stock,
    this.availability,
    this.image,
    required this.additionalImages,
    required this.source,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product.fromMap(json);
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<String> stringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    CampaignInfo? parseCampaign(dynamic v) {
      if (v is Map<String, dynamic>) {
        return CampaignInfo.fromMap(v);
      }
      return null;
    }

    return Product(
      id: (map['id'] ?? map['productId'] ?? '').toString(),
      name: (map['name'] ?? map['title'] ?? '').toString(),
      description: map['description'] as String?,
      brand: map['brand'] as String?,

      basePrice: toDouble(map['basePrice']),
      xmlPriceWithTax:
          map['xmlPriceWithTax'] != null ? toDouble(map['xmlPriceWithTax']) : null,

      salePrice: toDouble(map['salePrice'] ?? map['price']),

      /// Kampanya fiyatı backend'den finalPrice olarak geliyor
      finalPrice:
          map['finalPrice'] != null ? toDouble(map['finalPrice']) : null,

      /// Kampanya objesi backend'den "campaign" alanı ile geliyor
      campaign: parseCampaign(map['campaign']),

      /// Ürünün bağlı olduğu kampanya ID
      campaignId: (map['campaignId'] ?? map['campaign_id'])?.toString(),

      category: map['category'] as String?,
      stock: toInt(map['stock']),
      availability: map['availability'] as String?,
      image: map['image'] as String?,
      additionalImages: stringList(map['additionalImages']),
      source: (map['source'] ?? 'xml').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'brand': brand,
      'basePrice': basePrice,
      'xmlPriceWithTax': xmlPriceWithTax,
      'salePrice': salePrice,

      /// kampanya alanları
      'finalPrice': finalPrice,
      'campaign': campaign?.toMap(),
      'campaignId': campaignId,

      'category': category,
      'stock': stock,
      'availability': availability,
      'image': image,
      'additionalImages': additionalImages,
      'source': source,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
