import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/isar_schema.dart';
import 'api_service.dart';

class SyncService with ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Isar? _isar;
  final ApiService _api = ApiService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSalesCount = 0;
  String? _lastSyncError;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSalesCount => _pendingSalesCount;
  String? get lastSyncError => _lastSyncError;

  // Initialize Isar database
  Future<void> initialize() async {
    if (_isar != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [LocalProductSchema, LocalSaleSchema],
        directory: dir.path,
      );

      // Update pending count
      await _updatePendingCount();

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      debugPrint('SyncService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize SyncService: $e');
      rethrow;
    }
  }

  // Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final wasOffline = !_isOnline;
        _isOnline = results.isNotEmpty &&
                    results.first != ConnectivityResult.none;

        notifyListeners();

        // If just came online, trigger sync
        if (wasOffline && _isOnline) {
          debugPrint('Connection restored - triggering sync');
          await syncPendingSales();
        }
      },
    );

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.isNotEmpty &&
                  results.first != ConnectivityResult.none;
      notifyListeners();
    });
  }

  // Update pending sales count
  Future<void> _updatePendingCount() async {
    if (_isar == null) return;

    final count = await _isar!.localSales
        .filter()
        .isSyncedEqualTo(false)
        .count();

    _pendingSalesCount = count;
    notifyListeners();
  }

  // Queue a sale for offline processing
  Future<LocalSale> queueSale({
    required double totalAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? paymentProofUrl,
  }) async {
    if (_isar == null) {
      throw Exception('SyncService not initialized');
    }

    final sale = LocalSale.fromSaleItems(
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      items: items,
      paymentProofUrl: paymentProofUrl,
    );

    await _isar!.writeTxn(() async {
      await _isar!.localSales.put(sale);
    });

    await _updatePendingCount();

    debugPrint('Sale queued for sync: ${sale.id}');

    // Try to sync immediately if online
    if (_isOnline) {
      syncPendingSales();
    }

    return sale;
  }

  // Sync all pending sales to server
  Future<void> syncPendingSales() async {
    if (_isar == null) return;
    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return;
    }
    if (!_isOnline) {
      debugPrint('Cannot sync - device is offline');
      return;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final pendingSales = await _isar!.localSales
          .filter()
          .isSyncedEqualTo(false)
          .findAll();

      if (pendingSales.isEmpty) {
        debugPrint('No pending sales to sync');
        _isSyncing = false;
        notifyListeners();
        return;
      }

      debugPrint('Syncing ${pendingSales.length} pending sales');

      int successCount = 0;
      int failCount = 0;

      for (final sale in pendingSales) {
        try {
          // Attempt to sync this sale
          final response = await _api.post(
            '/sales',
            requiresAuth: true,
            body: sale.toJson(),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Mark as synced
            await _isar!.writeTxn(() async {
              sale.isSynced = true;
              sale.syncedAt = DateTime.now();
              sale.syncError = null;
              await _isar!.localSales.put(sale);
            });

            successCount++;
            debugPrint('Sale ${sale.id} synced successfully');
          } else {
            throw Exception('Server returned ${response.statusCode}');
          }
        } catch (e) {
          // Mark sync error
          await _isar!.writeTxn(() async {
            sale.syncError = e.toString();
            sale.retryCount = sale.retryCount + 1;
            await _isar!.localSales.put(sale);
          });

          failCount++;
          debugPrint('Failed to sync sale ${sale.id}: $e');
        }
      }

      debugPrint('Sync complete: $successCount succeeded, $failCount failed');

      if (failCount > 0) {
        _lastSyncError = 'Failed to sync $failCount sales';
      }

      await _updatePendingCount();
    } catch (e) {
      _lastSyncError = e.toString();
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Get all local sales (for debugging/viewing)
  Future<List<LocalSale>> getAllLocalSales() async {
    if (_isar == null) return [];
    return await _isar!.localSales.where().findAll();
  }

  // Get pending (unsynced) sales
  Future<List<LocalSale>> getPendingSales() async {
    if (_isar == null) return [];
    return await _isar!.localSales
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  // Clear all synced sales (cleanup)
  Future<void> clearSyncedSales() async {
    if (_isar == null) return;

    await _isar!.writeTxn(() async {
      final syncedSales = await _isar!.localSales
          .filter()
          .isSyncedEqualTo(true)
          .findAll();

      for (final sale in syncedSales) {
        await _isar!.localSales.delete(sale.id!);
      }
    });

    await _updatePendingCount();
    debugPrint('Cleared synced sales');
  }

  // Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _isar?.close();
    super.dispose();
  }
}
