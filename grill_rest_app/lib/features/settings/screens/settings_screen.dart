import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_model.dart';
import '../models/backup_model.dart';
import '../providers/settings_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _macCtrl = TextEditingController();
  final _backupDescCtrl = TextEditingController();

  int _paperWidth = 80;
  bool _isInit = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _taxCtrl.dispose();
    _serviceCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _macCtrl.dispose();
    _backupDescCtrl.dispose();
    super.dispose();
  }

  void _populateForm(SettingsModel settings) {
    if (_isInit) return;
    _nameCtrl.text = settings.restaurantName;
    _currencyCtrl.text = settings.currency;
    _taxCtrl.text = settings.taxPercentage.toString();
    _serviceCtrl.text = settings.serviceCharge.toString();
    _ipCtrl.text = settings.wifiPrinterIp ?? '';
    _portCtrl.text = settings.wifiPrinterPort.toString();
    _macCtrl.text = settings.bluetoothAddress ?? '';
    _paperWidth = settings.paperWidth;
    _isInit = true;
  }

  Future<void> _saveSettings(SettingsModel currentSettings) async {
    if (!_formKey.currentState!.validate()) return;

    final updated = SettingsModel(
      restaurantName: _nameCtrl.text.trim(),
      currency: _currencyCtrl.text.trim().toUpperCase(),
      taxPercentage: double.parse(_taxCtrl.text.trim()),
      serviceCharge: double.parse(_serviceCtrl.text.trim()),
      wifiPrinterIp: _ipCtrl.text.trim().isEmpty ? null : _ipCtrl.text.trim(),
      wifiPrinterPort: int.parse(_portCtrl.text.trim()),
      bluetoothAddress: _macCtrl.text.trim().isEmpty ? null : _macCtrl.text.trim(),
      paperWidth: _paperWidth,
    );

    await ref.read(settingsProvider.notifier).updateSettings(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(l10nProvider).translate('saved')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _triggerBackup(AppLocalizations l10n) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('backup_restore')),
          content: TextField(
            controller: _backupDescCtrl,
            decoration: InputDecoration(
              labelText: l10n.translate('backup_description'),
              hintText: l10n.translate('backup_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final desc = _backupDescCtrl.text.trim();
                _backupDescCtrl.clear();
                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final backupService = BackupService();
                  await backupService.createBackup(
                    description: desc.isEmpty ? 'Manual POS snapshot' : desc,
                  );
                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }

  void _triggerRestore(BackupModel backup, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('restore_backup_title')),
          content: Text(l10n.translate('restore_backup_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final backupService = BackupService();
                  await backupService.restoreBackup(backup.docId);
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.green),
                    );
                    // Reload settings
                    _isInit = false;
                    ref.read(settingsProvider.notifier).loadSettings();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restoration failed: $e'), backgroundColor: Colors.red),
                    );
                  }
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

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('settings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          _populateForm(settings);

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Metadata configuration
                  _buildSectionHeader(l10n.translate('general_settings')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(labelText: l10n.translate('restaurant_name')),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _currencyCtrl,
                                  decoration: InputDecoration(labelText: l10n.translate('currency')),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _taxCtrl,
                                  decoration: InputDecoration(labelText: l10n.translate('tax_percentage')),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _serviceCtrl,
                                  decoration: InputDecoration(labelText: l10n.translate('service_charge')),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Printer Setup
                  _buildSectionHeader(l10n.translate('printer_settings')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ipCtrl,
                                  decoration: InputDecoration(labelText: l10n.translate('wifi_printer_ip')),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _portCtrl,
                                  decoration: InputDecoration(labelText: l10n.translate('wifi_printer_port')),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _macCtrl,
                            decoration: InputDecoration(labelText: l10n.translate('bluetooth_printer')),
                          ),
                          const SizedBox(height: 16),
                          // Paper Width segment Selector
                          Text(l10n.translate('paper_width'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('80mm Printer (Wide)'),
                                  selected: _paperWidth == 80,
                                  onSelected: (val) {
                                    if (val) setState(() => _paperWidth = 80);
                                  },
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: const Text('58mm Printer (Narrow)'),
                                  selected: _paperWidth == 58,
                                  onSelected: (val) {
                                    if (val) setState(() => _paperWidth = 58);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Theme and Language
                  _buildSectionHeader(l10n.translate('appearance_language')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Dark Mode
                          SwitchListTile(
                            title: Text(l10n.translate('dark_mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            value: themeMode == ThemeMode.dark,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              ref.read(themeModeProvider.notifier).toggleTheme(val);
                            },
                          ),
                          const Divider(),
                          // Language selectors
                          ListTile(
                            title: Text(l10n.translate('language'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: DropdownButton<String>(
                              value: language.languageCode,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                                DropdownMenuItem(value: 'fr', child: Text('Français (FR)')),
                                DropdownMenuItem(value: 'ar', child: Text('العربية (AR)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(localeProvider.notifier).changeLanguage(val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Backups and restoration
                  _buildSectionHeader(l10n.translate('backup_restore')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _triggerBackup(l10n),
                            icon: const Icon(Icons.backup_rounded),
                            label: Text(l10n.translate('backup_btn')),
                          ),
                          const Divider(height: 24),
                          Text(
                            l10n.translate('available_backups'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          // Stream backups list
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: BackupService().streamBackupsList(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text(
                                      l10n.translate('no_backups'),
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                  ),
                                );
                              }

                              final backups = snapshot.data!
                                  .map((map) => BackupModel.fromMap(map, map['id']))
                                  .toList();

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: backups.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final backup = backups[index];
                                  final kbSize = (backup.sizeBytes / 1024).toStringAsFixed(1);
                                  
                                  return ListTile(
                                    title: Text(backup.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('${backup.createdAt.substring(0, 16)} | $kbSize KB'),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () => _triggerRestore(backup, l10n),
                                      icon: const Icon(Icons.restore, size: 14),
                                      label: Text(l10n.translate('restore'), style: const TextStyle(fontSize: 10)),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: const Size(0, 32),
                                        backgroundColor: Colors.orange.shade800,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save configuration settings button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _saveSettings(settings),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      child: Text(
                        l10n.translate('save_order'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.translate('error_loading'))),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
      ),
    );
  }
}
