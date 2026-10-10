import 'package:cloud_firestore/cloud_firestore.dart';

class BackupModel {
  final String id;
  final DateTime timestamp;
  final String createdAt;
  final String fileName;
  final String docId; // Firestore document ID used for restore
  final String description;
  final int sizeBytes;

  BackupModel({
    required this.id,
    required this.timestamp,
    required this.createdAt,
    required this.fileName,
    required this.docId,
    required this.description,
    required this.sizeBytes,
  });

  factory BackupModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        ts = (map['timestamp'] as Timestamp).toDate();
      } else if (map['timestamp'] is String) {
        ts = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
      }
    }

    return BackupModel(
      id: id,
      timestamp: ts,
      createdAt: map['createdAt'] ?? '',
      fileName: map['fileName'] ?? '',
      docId: id, // use the Firestore doc ID for restoration
      description: map['description'] ?? '',
      sizeBytes: map['sizeBytes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': createdAt,
      'fileName': fileName,
      'description': description,
      'sizeBytes': sizeBytes,
    };
  }
}
