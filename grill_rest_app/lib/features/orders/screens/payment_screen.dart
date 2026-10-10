import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../settings/models/settings_model.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../tables/providers/tables_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/print_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _paymentMethod = 'cash'; // 'cash', 'card', 'mixed'
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment(OrderModel order) async {
    final l10n = ref.read(l10nProvider);
    
    if (_paymentMethod == 'mixed') {
      final cashVal = double.tryParse(_cashAmountController.text) ?? 0.0;
      final cardVal = double.tryParse(_cardAmountController.text) ?? 0.0;
      final sum = cashVal + cardVal;

      if ((sum - order.total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment sum ($sum) must match order total (${order.total.toStringAsFixed(0)}).'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final tablesRepo = ref.read(tablesRepositoryProvider);
      final cashier = ref.read(currentAdminUserProvider).value?.name ?? 'Admin';

      // 1. Process payment in DB (sets state to paid, archives stats)
      await ref.read(ordersRepositoryProvider).processPayment(
            order: order,
            paymentMethod: _paymentMethod,
            cashierName: cashier,
            tablesRepo: tablesRepo,
          );

      // 2. Automatically print customer receipt
      final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultConfig();
      final printerBytes = PrintService().generateCustomerReceipt(
        restaurantName: settings.restaurantName,
        orderNumber: order.orderNumber,
        tableNumber: order.tableNumber,
        dateTime: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        items: order.items.map((e) => {'name': e.name, 'quantity': e.quantity, 'price': e.price}).toList(),
        total: order.total,
        paperWidth: settings.paperWidth,
        currency: settings.currency,
        cashierName: cashier,
        taxPercent: settings.taxPercentage,
        servicePercent: settings.serviceCharge,
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

      if (mounted) {
        setState(() => _isLoading = false);
        context.pop(); // Close checkout screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('success_operation')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('error_occurred')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final currency = l10n.translate('currency');

    return Directionality(
      textDirection: l10n.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.translate('payment'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: StreamBuilder<OrderModel>(
          stream: ref.read(ordersRepositoryProvider).streamAllOrders().map(
                (list) => list.firstWhere((e) => e.id == widget.orderId),
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Center(child: Text(l10n.translate('no_data')));
            }

            final order = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoice details
                          Text(
                            l10n.translate('order_no').replaceAll('{number}', order.orderNumber),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Table ${order.tableNumber}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const Divider(height: 32),

                          // Billing summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.translate('grand_total'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${order.total.toStringAsFixed(0)} $currency',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          // Mode selection
                          const Text(
                            'Select Payment Mode',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildModeRadio('cash', l10n.translate('cash'), Icons.payments_outlined),
                          const SizedBox(height: 8),
                          _buildModeRadio('card', l10n.translate('card'), Icons.credit_card_outlined),
                          const SizedBox(height: 8),
                          _buildModeRadio('mixed', l10n.translate('mixed_payment'), Icons.account_balance_wallet_outlined),
                          const SizedBox(height: 24),

                          // Mixed inputs if applicable
                          if (_paymentMethod == 'mixed') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cashAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: l10n.translate('cash_amount'),
                                      prefixIcon: const Icon(Icons.money),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cardAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: l10n.translate('card_amount'),
                                      prefixIcon: const Icon(Icons.credit_card),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Complete Checkout trigger
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _handlePayment(order),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      l10n.translate('complete_payment'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeRadio(String value, String title, IconData icon) {
    final isSelected = _paymentMethod == value;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade800.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.06) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : null,
            color: isSelected ? AppTheme.primaryColor : null,
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isSelected ? AppTheme.primaryColor : Colors.grey,
        ),
        onTap: () {
          setState(() {
            _paymentMethod = value;
            if (value != 'mixed') {
              _cashAmountController.clear();
              _cardAmountController.clear();
            }
          });
        },
      ),
    );
  }
}
