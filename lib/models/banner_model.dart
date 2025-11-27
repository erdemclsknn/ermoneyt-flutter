// lib/models/banner_model.dart
class BannerModel {
  final String id;
  final String title;
  final String imageUrl;
  final String targetType;
  final String targetValue;
  final String place;
  final int order;
  final bool isActive;
  final bool isPopup; // <-- ARTIK GERÇEK FIELD

  BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.targetType,
    required this.targetValue,
    required this.place,
    required this.order,
    required this.isActive,
    required this.isPopup,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      targetType: json['targetType'] ?? '',
      targetValue: json['targetValue'] ?? '',
      place: json['place'] ?? 'both',
      order: (json['order'] ?? 0) is int
          ? json['order']
          : int.tryParse(json['order'].toString()) ?? 0,
      isActive: json['isActive'] != false,
      // API'de isPopup veya is_popup gelebilir, ikisini de yakala
      isPopup: json['isPopup'] == true || json['is_popup'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'targetType': targetType,
      'targetValue': targetValue,
      'place': place,
      'order': order,
      'isActive': isActive,
      'isPopup': isPopup,
    };
  }
}
