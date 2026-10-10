import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item_model.dart';
import '../widgets/smart_menu_item_image.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/image_upload_service.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  static const List<String> categories = ['All', 'Grill', 'Steak', 'Chicken', 'Kefta', 'Sausage', 'Beverages', 'Sides'];

  // Presets for quick realistic food photo assignment
  static const Map<String, String> presetImages = {
    'بروشيت دجاج': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80',
    'بروشيت كبدة / ملفوف': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
    'بروشيت لحم': 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=600&q=80',
    'مرقاز / سوسيت': 'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=600&q=80',
    'شيش كباب / لحم مفروم': 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?auto=format&fit=crop&w=600&q=80',
    'ستيك / ضلع': 'https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=600&q=80',
    'إسكالوب / فخذ دجاج': 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80',
    'مشروبات (Beverages)': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=600&q=80',
    'مقبلات / بطاطس (Sides)': 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=600&q=80',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final filteredItems = ref.watch(filteredMenuItemsProvider);
    final selectedCategory = ref.watch(menuSelectedCategoryProvider);
    final searchController = TextEditingController(text: ref.read(menuSearchQueryProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('grill_menu'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            onPressed: () => _showAddEditDialog(context, ref),
            tooltip: l10n.translate('add_item'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Sort bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: l10n.translate('search'),
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      ref.read(menuSearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Sort selector
                DropdownButton<String>(
                  value: ref.watch(menuSortOrderProvider),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort),
                  items: ['Display Order', 'Price Asc', 'Price Desc', 'Name']
                      .map((String val) => DropdownMenuItem<String>(
                            value: val,
                            child: Text(
                              l10n.translate(val.toLowerCase().replaceAll(' ', '_')),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(menuSortOrderProvider.notifier).state = val;
                    }
                  },
                ),
              ],
            ),
          ),

          // Categories Chips horizontal list
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(l10n.translate(cat.toLowerCase())),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        ref.read(menuSelectedCategoryProvider.notifier).state = cat;
                      }
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                );
              },
            ),
          ),

          // Menu Items grid list
          Expanded(
            child: filteredItems.isEmpty
                ? Center(child: Text(l10n.translate('no_data')))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildItemCard(context, ref, item, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, MenuItemModel item, AppLocalizations l10n) {
    final String currentLang = ref.watch(localeProvider).languageCode;
    final currency = l10n.translate('currency');

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _showAddEditDialog(context, ref, item: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image header
            SizedBox(
              height: 90,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SmartMenuItemImage(
                      imageUrl: item.displayImageUrl,
                      category: item.category,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title & Active Toggle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.getName(currentLang),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          width: 36,
                          child: Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              value: item.isActive,
                              activeThumbColor: AppTheme.primaryColor,
                              onChanged: (val) {
                                ref.read(menuRepositoryProvider).toggleItemActive(item.id, val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Price & Edit Actions Row (Fully Responsive)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price container — click to quick edit price
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showQuickPriceDialog(context, ref, item, l10n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${item.price.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Action buttons with compact constraints to avoid overflow
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryColor),
                              tooltip: l10n.translate('edit'),
                              onPressed: () => _showAddEditDialog(context, ref, item: item),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              tooltip: l10n.translate('delete'),
                              onPressed: () => _handleDelete(context, ref, item, l10n),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick price-change dialog — one field, instant save.
  void _showQuickPriceDialog(BuildContext context, WidgetRef ref, MenuItemModel item, AppLocalizations l10n) {
    final String currentLang = ref.read(localeProvider).languageCode;
    final priceCtrl = TextEditingController(text: item.price.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('quick_price_edit').replaceAll('{item}', item.getName(currentLang))),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: priceCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.translate('price'),
              suffixText: l10n.translate('currency'),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return l10n.translate('required');
              if (double.tryParse(val) == null) return l10n.translate('invalid_number');
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: Text(l10n.translate('confirm')),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final updated = item.copyWith(price: double.parse(priceCtrl.text.trim()));
              await ref.read(menuRepositoryProvider).updateMenuItem(updated);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.getName(currentLang)}: ${priceCtrl.text} ${l10n.translate("currency")}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Complete Add / Edit Dialog for Menu Item (Name, Price, Image, Category)
  void _showAddEditDialog(BuildContext context, WidgetRef ref, {MenuItemModel? item}) {
    final l10n = ref.read(l10nProvider);
    final formKey = GlobalKey<FormState>();

    final nameEnCtrl = TextEditingController(text: item?.name['en'] ?? '');
    final nameArCtrl = TextEditingController(text: item?.name['ar'] ?? '');
    final nameFrCtrl = TextEditingController(text: item?.name['fr'] ?? '');
    final priceCtrl = TextEditingController(text: item?.price.toStringAsFixed(0) ?? '');
    final orderCtrl = TextEditingController(text: item?.displayOrder.toString() ?? '0');
    final urlCtrl = TextEditingController(text: item?.imageUrl ?? '');
    String selectedCat = item?.category ?? 'Grill';
    bool isActive = item?.isActive ?? true;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(item == null ? Icons.add_circle_outline : Icons.edit, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(item == null ? l10n.translate('add_item') : l10n.translate('edit_item')),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Preview & Photo Options Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('item_image'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Image preview box
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: SmartMenuItemImage(
                                        imageUrl: urlCtrl.text.trim().isEmpty ? (item?.displayImageUrl ?? '') : urlCtrl.text.trim(),
                                        category: selectedCat,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Photo action buttons (Gallery, Camera, Presets)
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        // Pick from Gallery
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 11),
                                          ),
                                          icon: isUploadingImage
                                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Icon(Icons.photo_library, size: 14),
                                          label: Text(l10n.translate('gallery')),
                                          onPressed: isUploadingImage
                                              ? null
                                              : () async {
                                                  final picker = ImagePicker();
                                                  final picked = await picker.pickImage(
                                                    source: ImageSource.gallery,
                                                    imageQuality: 70,
                                                    maxWidth: 800,
                                                  );
                                                  if (picked == null) return;
                                                  setState(() => isUploadingImage = true);
                                                  try {
                                                    final base64Url = await ImageUploadService().encodeImageAsBase64(File(picked.path));
                                                    urlCtrl.text = base64Url;
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('${l10n.translate("error_occurred")}: $e'), backgroundColor: Colors.red),
                                                      );
                                                    }
                                                  } finally {
                                                    setState(() => isUploadingImage = false);
                                                  }
                                                },
                                        ),
                                        // Take Photo with Camera
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 11),
                                            backgroundColor: Colors.teal,
                                          ),
                                          icon: const Icon(Icons.camera_alt, size: 14),
                                          label: Text(l10n.translate('camera')),
                                          onPressed: isUploadingImage
                                              ? null
                                              : () async {
                                                  final picker = ImagePicker();
                                                  final picked = await picker.pickImage(
                                                    source: ImageSource.camera,
                                                    imageQuality: 70,
                                                    maxWidth: 800,
                                                  );
                                                  if (picked == null) return;
                                                  setState(() => isUploadingImage = true);
                                                  try {
                                                    final base64Url = await ImageUploadService().encodeImageAsBase64(File(picked.path));
                                                    urlCtrl.text = base64Url;
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('${l10n.translate("error_occurred")}: $e'), backgroundColor: Colors.red),
                                                      );
                                                    }
                                                  } finally {
                                                    setState(() => isUploadingImage = false);
                                                  }
                                                },
                                        ),
                                        // Choose Preset Photo
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 11),
                                          ),
                                          icon: const Icon(Icons.collections, size: 14),
                                          label: Text(l10n.translate('preset_images')),
                                          onPressed: () => _showPresetImagesPicker(context, ref, (presetUrl) {
                                            setState(() {
                                              urlCtrl.text = presetUrl;
                                            });
                                          }),
                                        ),
                                        if (urlCtrl.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                                            tooltip: l10n.translate('clear_image'),
                                            onPressed: () => setState(() => urlCtrl.clear()),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: urlCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('image_url_hint'),
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Arabic name
                        TextFormField(
                          controller: nameArCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.translate('name_ar'),
                            prefixIcon: const Icon(Icons.restaurant_menu),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? l10n.translate('required') : null,
                        ),
                        const SizedBox(height: 10),

                        // French name
                        TextFormField(
                          controller: nameFrCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.translate('name_fr'),
                            prefixIcon: const Icon(Icons.translate),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // English name
                        TextFormField(
                          controller: nameEnCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.translate('name_en'),
                            prefixIcon: const Icon(Icons.language),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Price & Category Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l10n.translate('price')} *',
                                  suffixText: l10n.translate('currency'),
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'مطلوب';
                                  if (double.tryParse(val.trim()) == null) return 'رقم غير صحيح';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCat,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('category'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: ['Grill', 'Steak', 'Chicken', 'Kefta', 'Sausage', 'Beverages', 'Sides']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedCat = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Display order & Status
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: orderCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('display_order'),
                                  prefixIcon: const Icon(Icons.format_list_numbered),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'مطلوب';
                                  if (int.tryParse(val.trim()) == null) return 'رقم غير صحيح';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(l10n.translate('is_active'), style: const TextStyle(fontSize: 12)),
                                    Switch(
                                      value: isActive,
                                      activeThumbColor: AppTheme.primaryColor,
                                      onChanged: (val) => setState(() => isActive = val),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.translate('cancel')),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(l10n.translate('confirm')),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final String arName = nameArCtrl.text.trim();
                    final String enName = nameEnCtrl.text.trim().isEmpty ? arName : nameEnCtrl.text.trim();
                    final String frName = nameFrCtrl.text.trim().isEmpty ? arName : nameFrCtrl.text.trim();

                    final newItem = MenuItemModel(
                      id: item?.id ?? '',
                      name: {
                        'ar': arName,
                        'en': enName,
                        'fr': frName,
                      },
                      price: double.parse(priceCtrl.text.trim()),
                      category: selectedCat,
                      imageUrl: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                      isActive: isActive,
                      displayOrder: int.parse(orderCtrl.text.trim()),
                    );

                    final repo = ref.read(menuRepositoryProvider);
                    if (item == null) {
                      await repo.addMenuItem(newItem);
                    } else {
                      await repo.updateMenuItem(newItem);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('saved')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Preset food image picker sheet
  void _showPresetImagesPicker(BuildContext context, WidgetRef ref, Function(String url) onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.read(l10nProvider).translate('choose_preset_photo'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: presetImages.length,
                  itemBuilder: (context, index) {
                    final key = presetImages.keys.elementAt(index);
                    final url = presetImages[key]!;
                    return InkWell(
                      onTap: () {
                        onSelected(url);
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(url, fit: BoxFit.cover),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  key,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDelete(BuildContext context, WidgetRef ref, MenuItemModel item, AppLocalizations l10n) {
    final String currentLang = ref.read(localeProvider).languageCode;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('delete_item')),
          content: Text(l10n.translate('confirm_delete_item').replaceAll('{item}', item.getName(currentLang))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.translate('deleted')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }
}
