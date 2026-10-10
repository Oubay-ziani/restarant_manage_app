class MenuItemModel {
  final String id;
  final Map<String, String> name; // Localized names: {'en': 'Sausage', 'ar': 'سجق', 'fr': 'Saucisse'}
  final double price;
  final String category; // 'steak', 'chicken', 'beverages', 'sides', etc.
  final String? imageUrl;
  final bool isActive;
  final int displayOrder;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    required this.isActive,
    required this.displayOrder,
  });

  // Get localized name based on active language code, with fallback to any available non-empty translation
  String getName(String languageCode) {
    if (name[languageCode] != null && name[languageCode]!.trim().isNotEmpty) {
      return name[languageCode]!;
    }
    if (name['ar'] != null && name['ar']!.trim().isNotEmpty) return name['ar']!;
    if (name['fr'] != null && name['fr']!.trim().isNotEmpty) return name['fr']!;
    if (name['en'] != null && name['en']!.trim().isNotEmpty) return name['en']!;
    for (final val in name.values) {
      if (val.trim().isNotEmpty) return val;
    }
    return '';
  }

  // Returns custom imageUrl if set, otherwise returns a name/category matched realistic Unsplash food photo
  String get displayImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!;
    }
    final String nameEn = (name['en'] ?? '').toLowerCase();
    final String nameAr = (name['ar'] ?? '').toLowerCase();
    final String nameFr = (name['fr'] ?? '').toLowerCase();
    final String catLower = category.toLowerCase();

    // 1. Brochet Poulet (أعواد دجاج)
    if (nameFr.contains('poulet') || nameEn.contains('poulet') || nameAr.contains('دجاج')) {
      return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80'; // Chicken Skewers on BBQ
    }

    // 2. Brochet Foie (أعواد كبد) / Melfouf
    if (nameFr.contains('foie') || nameEn.contains('foie') || nameAr.contains('كبدة') || nameFr.contains('melfouf') || nameAr.contains('ملفوف')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80'; // Liver Skewers / Melfouf Grill
    }

    // 3. Brochet Boeuf (أعواد لحم)
    if (nameFr.contains('boeuf') || nameEn.contains('boeuf') || (nameAr.contains('بروشيت') && nameAr.contains('لحم'))) {
      return 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=600&q=80'; // Beef Skewers Grill
    }

    // 4. Merguez / Succet (سجق)
    if (nameFr.contains('merguez') || nameEn.contains('merguez') || nameAr.contains('مرقاز') || nameFr.contains('succet') || nameAr.contains('سوسيت') || catLower == 'sausage') {
      return 'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=600&q=80'; // Grilled Sausages / Merguez
    }

    // 5. Viande Hachée / Chich Kebab / Kefta / Steak Haché (كفتة صغيرة)
    if (nameFr.contains('hachée') || nameFr.contains('haché') || nameAr.contains('مفروم') || nameFr.contains('kebab') || nameAr.contains('كباب') || nameAr.contains('كفتة') || catLower == 'kefta') {
      return 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?auto=format&fit=crop&w=600&q=80'; // Small Kefta / Minced Meat Patties
    }

    // 6. Steak / Côte / Entrecôte
    if (nameFr.contains('steak') || nameAr.contains('ستيك') || nameFr.contains('côte') || nameFr.contains('entrecôte') || catLower == 'steak') {
      return 'https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=600&q=80'; // Juicy Ribeye Steak
    }

    // 7. Escalope / Cuisse
    if (nameFr.contains('escalope') || nameAr.contains('إسكالوب') || nameFr.contains('cuisse') || nameAr.contains('فخذة') || catLower == 'chicken') {
      return 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80'; // Grilled Escalope / Chicken Leg
    }

    if (catLower == 'beverages') {
      return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=600&q=80'; // Beverages
    }

    if (catLower == 'sides') {
      return 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=600&q=80'; // French Fries / Sides
    }

    // Default BBQ Grill image
    return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80';
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map, String id) {
    // Safely parse name map
    final Map<String, String> localizedNames = {};
    if (map['name'] is Map) {
      (map['name'] as Map).forEach((key, val) {
        localizedNames[key.toString()] = val.toString();
      });
    } else if (map['name'] is String) {
      localizedNames['en'] = map['name'];
    }

    return MenuItemModel(
      id: id,
      name: localizedNames,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'grill',
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] ?? true,
      displayOrder: map['displayOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'displayOrder': displayOrder,
    };
  }

  MenuItemModel copyWith({
    Map<String, String>? name,
    double? price,
    String? category,
    String? imageUrl,
    bool? isActive,
    int? displayOrder,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}
