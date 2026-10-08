import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../settings/models/settings_model.dart';
import '../../menu/screens/menu_screen.dart';
import '../../menu/widgets/smart_menu_item_image.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../providers/orders_provider.dart';
import '../../menu/providers/menu_provider.dart';
import '../../menu/models/menu_item_model.dart';
import '../../tables/providers/tables_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/print_service.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  final int tableNumber;
  const NewOrderScreen({super.key, required this.tableNumber});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final Map<String, int> _cart = {}; // menuItemId -> quantity
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addToCart(String itemId) {
    setState(() {
      _cart[itemId] = (_cart[itemId] ?? 0) + 1;
    });
  }

  void _setQuantity(String itemId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = quantity;
      }
    });
  }

  void _showQuantityDialog(String itemId, String itemName) {
    final l10n = ref.read(l10nProvider);
    final currentQty = _cart[itemId] ?? 1;
    final controller = TextEditingController(text: '$currentQty');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('set_quantity_title').replaceAll('{item}', itemName)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.translate('enter_quantity_hint'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(controller.text.trim());
                if (qty != null) {
                  _setQuantity(itemId, qty);
                }
                Navigator.pop(context);
              },
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        final current = _cart[itemId]!;
        if (current <= 1) {
          _cart.remove(itemId);
        } else {
          _cart[itemId] = current - 1;
        }
      }
    });
  }

  double _calculateTotal(List<MenuItemModel> items) {
    double sum = 0.0;
    _cart.forEach((itemId, qty) {
      final item = items.firstWhere((e) => e.id == itemId, orElse: () => MenuItemModel(id: '', name: {}, price: 0, category: '', isActive: false, displayOrder: 0));
      sum += item.price * qty;
    });
    return sum;
  }

  Future<void> _handleSaveOrder({required bool printTicket}) async {
    final l10n = ref.read(l10nProvider);
    final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
    
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_data')), backgroundColor: Colors.orange),
      );
      return;
    }

    // Build OrderItemModel list
    final List<OrderItemModel> orderItems = [];
    final currentLang = ref.read(localeProvider).languageCode;
    _cart.forEach((itemId, qty) {
      final menu = menuItems.firstWhere((e) => e.id == itemId);
      orderItems.add(
        OrderItemModel(
          menuItemId: itemId,
          name: menu.getName(currentLang),
          price: menu.price,
          quantity: qty,
        ),
      );
    });

    final double total = _calculateTotal(menuItems);
    
    // Create new OrderModel object
    final order = OrderModel(
      id: '',
      orderNumber: '', // set sequentially by repo
      tableNumber: widget.tableNumber,
      timestamp: DateTime.now(),
      items: orderItems,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      total: total,
      status: 'unpaid',
    );

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tablesRepo = ref.read(tablesRepositoryProvider);
      final ordersRepo = ref.read(ordersRepositoryProvider);

      // Save order
      final String orderId = await ordersRepo.createOrder(order, tablesRepo);

      // Optional Kitchen Ticket printing
      if (printTicket) {
        final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultConfig();
        final generatedNum = await FirebaseFirestore.instance.collection('orders').doc(orderId).get().then((doc) => doc.data()?['orderNumber'] as String? ?? '000');
        
        final printerBytes = PrintService().generateKitchenTicket(
          orderNumber: generatedNum,
          tableNumber: widget.tableNumber,
          dateTime: DateFormat('HH:mm').format(DateTime.now()),
          items: orderItems.map((e) => {'name': e.name, 'quantity': e.quantity}).toList(),
          notes: order.notes,
          paperWidth: settings.paperWidth,
        );

        if (settings.wifiPrinterIp != null && settings.wifiPrinterIp!.isNotEmpty) {
          await PrintService().printViaWifi(
            ip: settings.wifiPrinterIp!,
            port: settings.wifiPrinterPort,
            bytes: printerBytes,
          );
        } else if (settings.bluetoothAddress != null) {
          await PrintService().printViaBluetooth(
            macAddress: settings.bluetoothAddress!,
            bytes: printerBytes,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loader
        context.pop(); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('saved')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('error_occurred')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final menuItemsAsync = ref.watch(menuItemsStreamProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: l10n.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.tableNumber == 0
                ? '${l10n.translate('new_order')} - ${l10n.translate('takeaway')}'
                : widget.tableNumber == -1
                    ? '${l10n.translate('new_order')} - ${l10n.translate('temp_no_table')}'
                    : '${l10n.translate('new_order')} - ${l10n.translate('tables')} ${widget.tableNumber}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: menuItemsAsync.when(
          data: (allItems) {
            // Filter active menu items
            final activeItems = allItems.where((e) => e.isActive).toList();

            // Client side filter
            var filtered = activeItems;
            if (_selectedCategory != 'All') {
              filtered = filtered.where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
            }
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((e) {
                final nameEn = e.name['en']?.toLowerCase() ?? '';
                final nameAr = e.name['ar']?.toLowerCase() ?? '';
                final nameFr = e.name['fr']?.toLowerCase() ?? '';
                return nameEn.contains(_searchQuery.toLowerCase()) ||
                    nameAr.contains(_searchQuery.toLowerCase()) ||
                    nameFr.contains(_searchQuery.toLowerCase());
              }).toList();
            }

            final double cartTotal = _calculateTotal(allItems);

            if (isTablet) {
              return Row(
                children: [
                  // Grill menu grid (Left column)
                  Expanded(
                    flex: 3,
                    child: _buildMenuGrid(filtered, l10n),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // Checkout Cart panel (Right column)
                  Expanded(
                    flex: 2,
                    child: _buildCartPanel(allItems, cartTotal, settingsAsync.value ?? SettingsModel.defaultConfig(), l10n, isDark),
                  ),
                ],
              );
            }

            // Mobile portrait layout: menu grid, cart drawer accessible via FAB
            return Stack(
              children: [
                _buildMenuGrid(filtered, l10n),
                // Floating Cart view activator
                if (_cart.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    left: 16,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (context) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  height: mediaQuery.size.height * 0.75,
                                  child: _buildCartPanel(allItems, cartTotal, settingsAsync.value ?? SettingsModel.defaultConfig(), l10n, isDark),
                                ),
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shopping_cart, color: Colors.white),
                        label: Flexible(
                          child: Text(
                            '${l10n.translate('view_orders')} (${_cart.values.fold(0, (a, b) => a + b)} items - ${cartTotal.toStringAsFixed(0)} ${l10n.translate('currency')})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text(l10n.translate('error_loading'))),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(List<MenuItemModel> items, AppLocalizations l10n) {
    final String currentLang = ref.watch(localeProvider).languageCode;
    final currency = l10n.translate('currency');

    return Column(
      children: [
        // Category Pills & search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.translate('search'),
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: MenuScreen.categories.length,
            itemBuilder: (context, index) {
              final cat = MenuScreen.categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(l10n.translate(cat.toLowerCase()), style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Grid list
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l10n.translate('no_data')))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final qty = _cart[item.id] ?? 0;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: qty > 0 ? AppTheme.primaryColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _addToCart(item.id),
                        onLongPress: () => _showQuantityDialog(item.id, item.getName(currentLang)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image or Icon
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SmartMenuItemImage(
                                    imageUrl: item.displayImageUrl,
                                    category: item.category,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.getName(currentLang),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
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
                                  // Quantity pill if in cart — tap to input quantity
                                  if (qty > 0) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _showQuantityDialog(item.id, item.getName(currentLang)),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCartPanel(
    List<MenuItemModel> allItems,
    double rawSubtotal,
    SettingsModel settings,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final currency = l10n.translate('currency');
    final taxAmount = rawSubtotal * (settings.taxPercentage / 100);
    final serviceAmount = rawSubtotal * (settings.serviceCharge / 100);
    final grandTotal = rawSubtotal + taxAmount + serviceAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            l10n.translate('view_orders'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        // Cart Items list
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Text(
                    l10n.translate('no_data'),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final itemId = _cart.keys.elementAt(index);
                    final qty = _cart[itemId]!;
                    final item = allItems.firstWhere((e) => e.id == itemId);
                    final currentLang = ref.watch(localeProvider).languageCode;

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.getName(currentLang),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${item.price.toStringAsFixed(0)} $currency',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        // Subtotal
                        Text(
                          '${(item.price * qty).toStringAsFixed(0)} $currency',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        // Selectors
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () => _removeFromCart(itemId),
                            ),
                            InkWell(
                              onTap: () => _showQuantityDialog(itemId, item.getName(currentLang)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 12, color: AppTheme.primaryColor),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                              onPressed: () => _addToCart(itemId),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Extra info inputs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: l10n.translate('notes'),
              prefixIcon: const Icon(Icons.notes),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        // Summary calculations
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF131218) : Colors.grey.shade100,
          child: Column(
            children: [
              if (settings.taxPercentage > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tax (${settings.taxPercentage.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
                    Text('${taxAmount.toStringAsFixed(0)} $currency', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (settings.serviceCharge > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Service (${settings.serviceCharge.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
                    Text('${serviceAmount.toStringAsFixed(0)} $currency', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.translate('grand_total'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(
                    '${grandTotal.toStringAsFixed(0)} $currency',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action triggers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: Text(l10n.translate('cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleSaveOrder(printTicket: true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      child: Text(l10n.translate('print_kitchen'), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleSaveOrder(printTicket: false),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(l10n.translate('save_order'), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
