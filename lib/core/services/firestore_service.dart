import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService() {
    _initPersistence();
  }

  void _initPersistence() {
    try {
      if (!kIsWeb) {
        // Mobile platform persistence configuration
        _db.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
    } catch (e) {
      debugPrint('Error setting Firestore persistence: $e');
    }
  }

  // Generic streams and actions
  Stream<List<T>> streamCollection<T>({
    required String collectionPath,
    required T Function(Map<String, dynamic> data, String id) builder,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _db.collection(collectionPath);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => builder(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<T> getDocument<T>({
    required String collectionPath,
    required String docId,
    required T Function(Map<String, dynamic> data, String id) builder,
  }) async {
    final doc = await _db.collection(collectionPath).doc(docId).get();
    if (!doc.exists) {
      throw Exception('Document not found');
    }
    return builder(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> setDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    await _db
        .collection(collectionPath)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
  }

  Future<String> addDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    final ref = await _db.collection(collectionPath).add(data);
    return ref.id;
  }

  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(collectionPath).doc(docId).update(data);
  }

  Future<void> deleteDocument({
    required String collectionPath,
    required String docId,
  }) async {
    await _db.collection(collectionPath).doc(docId).delete();
  }

  // Transactions / Batch Writes
  Future<void> runBatch(Future<void> Function(WriteBatch batch) action) async {
    final batch = _db.batch();
    await action(batch);
    await batch.commit();
  }

  DocumentReference getDocRef(String collectionPath, String docId) {
    return _db.collection(collectionPath).doc(docId);
  }

  CollectionReference getColRef(String collectionPath) {
    return _db.collection(collectionPath);
  }
}
