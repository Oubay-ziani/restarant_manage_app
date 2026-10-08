import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// BackupService — stores full Firestore snapshots directly in the
/// 'backups' collection as a base64-encoded JSON string.
/// No Firebase Storage required.
class BackupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> _backupCollections = [
    'settings',
    'menu_items',
    'tables',
    'orders',
    'daily_statistics',
    'daily_reports',
  ];

  /// Creates a backup: reads all collections → encodes to base64 → stores in Firestore.
  Future<String> createBackup({required String description}) async {
    try {
      final Map<String, List<Map<String, dynamic>>> dbSnapshot = {};

      // 1. Read all documents across all collections
      for (final collection in _backupCollections) {
        final querySnapshot = await _db.collection(collection).get();
        final List<Map<String, dynamic>> docsList = [];
        for (final doc in querySnapshot.docs) {
          docsList.add({'_id': doc.id, ...doc.data()});
        }
        dbSnapshot[collection] = docsList;
      }

      // 2. JSON → UTF-8 bytes → base64
      final String jsonString = jsonEncode(dbSnapshot);
      final String base64Data = base64Encode(utf8.encode(jsonString));
      final int sizeBytes = utf8.encode(jsonString).length;

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'backup_$timestamp.json';

      // 3. Store inline in Firestore — no Storage bucket needed
      final backupMeta = {
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'fileName': fileName,
        'base64Data': base64Data,
        'description': description,
        'sizeBytes': sizeBytes,
      };

      final docRef = await _db.collection('backups').add(backupMeta);
      debugPrint('Backup saved to Firestore: ${docRef.id}');
      return 'Backup created successfully: $fileName';
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      throw Exception('Backup creation failed: $e');
    }
  }

  /// Restores the database from a Firestore backup document ID.
  Future<void> restoreBackup(String backupDocId) async {
    try {
      // 1. Fetch backup document
      final doc = await _db.collection('backups').doc(backupDocId).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception('Backup document not found.');
      }

      final String? base64Data = doc.data()!['base64Data'] as String?;
      if (base64Data == null || base64Data.isEmpty) {
        throw Exception('Backup data is empty or missing.');
      }

      // 2. base64 → UTF-8 → JSON
      final String jsonString = utf8.decode(base64Decode(base64Data));
      final Map<String, dynamic> dbSnapshot = jsonDecode(jsonString);

      // 3. Restore each collection
      for (final collection in _backupCollections) {
        final currentDocs = await _db.collection(collection).get();
        final deleteBatch = _db.batch();
        for (final d in currentDocs.docs) {
          deleteBatch.delete(d.reference);
        }
        await deleteBatch.commit();

        final list = dbSnapshot[collection] as List<dynamic>?;
        if (list != null) {
          final writeBatch = _db.batch();
          for (final item in list) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(item);
            final String id = data['_id'] as String;
            data.remove('_id');
            writeBatch.set(_db.collection(collection).doc(id), data);
          }
          await writeBatch.commit();
        }
      }
      debugPrint('Database restoration complete.');
    } catch (e) {
      debugPrint('Restoration failed: $e');
      throw Exception('Restoration failed: $e');
    }
  }

  /// Stream of backups list (without the heavy base64 payload).
  Stream<List<Map<String, dynamic>>> streamBackupsList() {
    return _db
        .collection('backups')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? '',
          'description': data['description'] ?? '',
          'createdAt': data['createdAt'] ?? '',
          'sizeBytes': data['sizeBytes'] ?? 0,
          'timestamp': data['timestamp'],
        };
      }).toList();
    });
  }
}


