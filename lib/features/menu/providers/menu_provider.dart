import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/l10n/app_localizations.dart';

class MenuRepository {
  final FirestoreService _firestoreService;
  static const String _collectionPath = 'menu_items';

  MenuRepository(this._firestoreService);

  Stream<List<MenuItemModel>> streamMenuItems() {
    return _firestoreService.streamCollection<MenuItemModel>(
      collectionPath: _collectionPath,
      builder: (data, id) => MenuItemModel.fromMap(data, id),
      queryBuilder: (query) => query.orderBy('displayOrder', descending: false),
    );
  }

  Future<void> addMenuItem(MenuItemModel item) async {
    await _firestoreService.addDocument(
      collectionPath: _collectionPath,
      data: item.toMap(),
    );
  }

  Future<void> updateMenuItem(MenuItemModel item) async {
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: item.id,
      data: item.toMap(),
    );
  }

  Future<void> deleteMenuItem(String id) async {
    await _firestoreService.deleteDocument(
      collectionPath: _collectionPath,
      docId: id,
    );
  }

  Future<void> toggleItemActive(String id, bool isActive) async {
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: id,
      data: {'isActive': isActive},
    );
  }

  /// Seeds the 15 default grill dishes if the collection is empty.
  Future<void> initializeMenuItems() async {
    try {
      final colRef = _firestoreService.getColRef(_collectionPath);
      final snapshot = await colRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) return; // already seeded

      final List<Map<String, dynamic>> defaultItems = [
        {'en': 'Brochet Poulet',     'ar': 'بروشيت دجاج',     'fr': 'Brochet Poulet',     'price': 150.0,  'cat': 'Grill', 'order': 1},
        {'en': 'Brochet Boeuf',      'ar': 'بروشيت لحم',      'fr': 'Brochet Boeuf',      'price': 200.0,  'cat': 'Grill', 'order': 2},
        {'en': 'Brochet Foie',       'ar': 'بروشيت كبدة',     'fr': 'Brochet Foie',       'price': 250.0,  'cat': 'Grill', 'order': 3},
        {'en': 'Brochet Melfouf',    'ar': 'بروشيت ملفوف',    'fr': 'Brochet Melfouf',    'price': 400.0,  'cat': 'Grill', 'order': 4},
        {'en': 'Brochet Merguez',    'ar': 'بروشيت مرقاز',    'fr': 'Brochet Merguez',    'price': 200.0,  'cat': 'Grill', 'order': 5},
        {'en': 'Chich Kebab',        'ar': 'شيش كباب',         'fr': 'Chich Kebab',        'price': 200.0,  'cat': 'Kefta', 'order': 6},
        {'en': 'Viande Hachée',      'ar': 'لحم مفروم',        'fr': 'Viande Hachée',      'price': 70.0,   'cat': 'Kefta', 'order': 7},
        {'en': 'Steak Haché Fromage','ar': 'ستيك هاشيه فروماج','fr': 'Steak Haché Fromage','price': 600.0,  'cat': 'Steak', 'order': 8},
        {'en': 'Escalope',           'ar': 'إسكالوب',          'fr': 'Escalope',           'price': 450.0,  'cat': 'Chicken', 'order': 9},
        {'en': 'Cuisse',             'ar': 'فخذة دجاج',        'fr': 'Cuisse',             'price': 450.0,  'cat': 'Chicken', 'order': 10},
        {'en': 'Tranche Foie',       'ar': 'شريحة كبدة',       'fr': 'Tranche Foie',       'price': 900.0,  'cat': 'Grill', 'order': 11},
        {'en': 'Succet',             'ar': 'سوسيت',            'fr': 'Succet',             'price': 800.0,  'cat': 'Grill', 'order': 12},
        {'en': 'Côte',               'ar': 'ضلع',              'fr': 'Côte',               'price': 900.0,  'cat': 'Steak', 'order': 13},
        {'en': 'Entrecôte',          'ar': 'أنتريكوت',         'fr': 'Entrecôte',          'price': 900.0,  'cat': 'Steak', 'order': 14},
        {'en': 'Steak',              'ar': 'ستيك',             'fr': 'Steak',              'price': 900.0,  'cat': 'Steak', 'order': 15},
      ];

      for (final item in defaultItems) {
        await colRef.add({
          'name': {'en': item['en'], 'ar': item['ar'], 'fr': item['fr']},
          'price': item['price'],
          'category': item['cat'],
          'isActive': true,
          'displayOrder': item['order'],
          'imageUrl': null,
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize menu items: $e');
    }
  }
}

// Riverpod Providers
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return MenuRepository(firestore);
});

final menuItemsStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  // Auto-seed default dishes on first launch
  repo.initializeMenuItems();
  return repo.streamMenuItems();
});

// Search & Sort state providers
final menuSearchQueryProvider = StateProvider<String>((ref) => '');
final menuSelectedCategoryProvider = StateProvider<String>((ref) => 'All');
final menuSortOrderProvider = StateProvider<String>((ref) => 'Display Order'); // 'Display Order', 'Price Asc', 'Price Desc', 'Name'

// Filtered Menu Items Provider
final filteredMenuItemsProvider = Provider<List<MenuItemModel>>((ref) {
  final itemsAsync = ref.watch(menuItemsStreamProvider);
  final query = ref.watch(menuSearchQueryProvider).toLowerCase().trim();
  final category = ref.watch(menuSelectedCategoryProvider);
  final sortOrder = ref.watch(menuSortOrderProvider);
  ref.watch(localeNotifierProvider); // Trigger rebuild on locale change

  final items = itemsAsync.value ?? [];
  
  List<MenuItemModel> filtered = items;

  // Filter by Category
  if (category != 'All') {
    filtered = filtered.where((item) => item.category.toLowerCase() == category.toLowerCase()).toList();
  }

  // Filter by Search Query
  if (query.isNotEmpty) {
    filtered = filtered.where((item) {
      final nameEn = item.name['en']?.toLowerCase() ?? '';
      final nameAr = item.name['ar']?.toLowerCase() ?? '';
      final nameFr = item.name['fr']?.toLowerCase() ?? '';
      return nameEn.contains(query) || nameAr.contains(query) || nameFr.contains(query);
    }).toList();
  }

  // Sort
  if (sortOrder == 'Display Order') {
    filtered.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  } else if (sortOrder == 'Price Asc') {
    filtered.sort((a, b) => a.price.compareTo(b.price));
  } else if (sortOrder == 'Price Desc') {
    filtered.sort((a, b) => b.price.compareTo(a.price));
  } else if (sortOrder == 'Name') {
    filtered.sort((a, b) => (a.name['en'] ?? '').compareTo(b.name['en'] ?? ''));
  }

  return filtered;
});

// Dummy provider for locale fallback if needed, referencing main locale
final localeNotifierProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).languageCode;
});
