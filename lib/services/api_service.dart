// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/banner_model.dart';

class ApiService {
  /// ✔ Sabit Elastic IP kullandık (değişmeyecek)
  static const String baseUrl = 'http://51.20.206.19:3000';

  /* -------------------- ÜRÜNLER -------------------- */

  static Future<List<Product>> fetchProducts() async {
    final uri = Uri.parse('$baseUrl/api/products');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Product.fromJson(e)).toList();
    } else {
      throw Exception('Ürünler alınamadı: ${res.statusCode}');
    }
  }

  static Future<Product> fetchProduct(String id) async {
    final uri = Uri.parse('$baseUrl/api/products/$id');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Product.fromJson(data);
    } else {
      throw Exception('Ürün alınamadı: ${res.statusCode}');
    }
  }

  /* -------------------- BANNERLAR -------------------- */

  static Future<List<BannerModel>> fetchBanners() async {
    final uri = Uri.parse('$baseUrl/api/banners');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);

      final banners = data
          .map((e) => BannerModel.fromJson(e))
          .where(
            (b) => b.isActive && (b.place == 'mobile' || b.place == 'both'),
          )
          .toList();

      banners.sort((a, b) => a.order.compareTo(b.order));
      return banners;
    } else {
      throw Exception('Bannerlar alınamadı: ${res.statusCode}');
    }
  }

  /* -------------------- SİPARİŞ OLUŞTURMA -------------------- */

  static Future<Map<String, dynamic>> createOrder(
      Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/api/orders');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Sipariş isteği başarısız: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data;
  }
}
