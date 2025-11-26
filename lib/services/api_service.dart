// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/banner_model.dart';

class ApiService {
  // kendi sunucun
  static const String baseUrl = 'http://13.60.41.68:3000';

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

      // sadece mobilde gösterilecekleri al
      final banners = data
          .map((e) => BannerModel.fromJson(e))
          .where((b) =>
              b.isActive && (b.place == 'mobile' || b.place == 'both'))
          .toList();

      // sıraya göre diz
      banners.sort((a, b) => a.order.compareTo(b.order));
      return banners;
    } else {
      throw Exception('Bannerlar alınamadı: ${res.statusCode}');
    }
  }
}
