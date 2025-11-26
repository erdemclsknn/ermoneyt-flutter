import 'package:flutter/material.dart';
import '../models/product.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  bool isFavorite(Product p) => _favoriteIds.contains(p.id);

  void toggleFavorite(Product p) {
    if (_favoriteIds.contains(p.id)) {
      _favoriteIds.remove(p.id);
    } else {
      _favoriteIds.add(p.id);
    }
    notifyListeners();
  }

  List<String> get favoriteIds => _favoriteIds.toList();
}
