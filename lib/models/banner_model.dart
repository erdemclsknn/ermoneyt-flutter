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

  BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.targetType,
    required this.targetValue,
    required this.place,
    required this.order,
    required this.isActive,
  });

  // 🔥 EKLEMEN GEREKEN TEK ŞEY BU !
  bool get isPopup => targetType == 'campaign';

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
    );
  }
}
