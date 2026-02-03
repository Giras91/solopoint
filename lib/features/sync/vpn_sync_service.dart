import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../stores/store_repository.dart';
import '../stores/sync_service.dart';

final vpnSyncServiceProvider = Provider<VpnSyncService>((ref) {
  final storeRepo = ref.watch(storeRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return VpnSyncService(storeRepo, syncService);
});

/// VPN-based synchronization service for multi-store operations
/// Main Terminal acts as server, Branch outlets act as clients
class VpnSyncService {
  final StoreRepository _storeRepository;
  final SyncService _syncService;
  HttpServer? _server;
  bool _isServerRunning = false;

  VpnSyncService(this._storeRepository, this._syncService);

  // ============== SERVER SIDE (Main Terminal) ==============

  /// Start HTTP server on main terminal for sync
  Future<bool> startSyncServer({int port = 8888}) async {
    if (_isServerRunning) {
      return true;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;

      _server!.listen((HttpRequest request) async {
        await _handleSyncRequest(request);
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop sync server
  Future<void> stopSyncServer() async {
    await _server?.close();
    _server = null;
    _isServerRunning = false;
  }

  /// Handle incoming sync requests from branch outlets
  Future<void> _handleSyncRequest(HttpRequest request) async {
    try {
      final uri = request.uri;
      final method = request.method;

      // CORS headers
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Content-Type', 'application/json');

      if (method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      // Parse request body
      final body = await utf8.decoder.bind(request).join();
      final data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : <String, dynamic>{};

      Map<String, dynamic> response;

      // Route handling
      if (uri.path == '/sync/pull') {
        response = await _handlePullRequest(data);
      } else if (uri.path == '/sync/push') {
        response = await _handlePushRequest(data);
      } else if (uri.path == '/sync/status') {
        response = await _handleStatusRequest(data);
      } else {
        response = {'success': false, 'error': 'Unknown endpoint'};
        request.response.statusCode = HttpStatus.notFound;
      }

      request.response.write(jsonEncode(response));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'success': false, 'error': e.toString()}));
      await request.response.close();
    }
  }

  /// Handle pull request (branch requesting updates from main)
  Future<Map<String, dynamic>> _handlePullRequest(Map<String, dynamic> data) async {
    try {
      final storeId = data['storeId'] as int?;
      // lastSyncAt can be used for filtering changes in the future
      // final lastSyncAt = data['lastSyncAt'] as String?;

      if (storeId == null) {
        return {'success': false, 'error': 'Missing storeId'};
      }

      // Get pending changes for this store
      final changes = await _storeRepository.watchPendingChanges(storeId).first;

      final changesData = changes.map((change) => {
            'id': change.id,
            'entityType': change.entityType,
            'entityId': change.entityId,
            'operation': change.operation,
            'payload': jsonDecode(change.payload),
            'createdAt': change.createdAt.toIso8601String(),
          }).toList();

      return {
        'success': true,
        'changes': changesData,
        'serverTime': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle push request (branch sending updates to main)
  Future<Map<String, dynamic>> _handlePushRequest(Map<String, dynamic> data) async {
    try {
      final storeId = data['storeId'] as int?;
      final changes = data['changes'] as List<dynamic>?;

      if (storeId == null || changes == null) {
        return {'success': false, 'error': 'Missing required fields'};
      }

      final processedChanges = <int>[];
      final failedChanges = <Map<String, dynamic>>[];

      for (final change in changes) {
        try {
          final changeMap = change as Map<String, dynamic>;
          final changeId = changeMap['id'] as int;

          // Process change based on entity type
          await _processIncomingChange(changeMap);

          // Log successful sync (ignoring the log ID for now)
          await _syncService.logSync(
            targetStoreId: storeId,
            entityType: changeMap['entityType'] as String,
            entityId: changeMap['entityId'] as int,
            status: 'success',
          );

          processedChanges.add(changeId);
        } catch (e) {
          failedChanges.add({
            'change': change,
            'error': e.toString(),
          });
        }
      }

      return {
        'success': true,
        'processed': processedChanges.length,
        'failed': failedChanges.length,
        'processedIds': processedChanges,
        'failures': failedChanges,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle status request
  Future<Map<String, dynamic>> _handleStatusRequest(Map<String, dynamic> data) async {
    final storeId = data['storeId'] as int?;

    if (storeId == null) {
      return {'success': false, 'error': 'Missing storeId'};
    }

    final store = await _storeRepository.getStoreById(storeId);
    if (store == null) {
      return {'success': false, 'error': 'Store not found'};
    }

    final pendingChanges = await _storeRepository.watchPendingChanges(storeId).first;

    return {
      'success': true,
      'store': {
        'id': store.id,
        'code': store.code,
        'name': store.name,
        'isActive': store.isActive,
        'lastSyncAt': store.lastSyncAt?.toIso8601String(),
      },
      'pendingChanges': pendingChanges.length,
      'serverTime': DateTime.now().toIso8601String(),
    };
  }

  // ============== CLIENT SIDE (Branch Outlets) ==============

  /// Pull updates from main terminal
  Future<Map<String, dynamic>> pullUpdates({
    required String serverVpnAddress,
    required int serverPort,
    required int storeId,
    DateTime? lastSyncAt,
  }) async {
    try {
      final url = 'http://$serverVpnAddress:$serverPort/sync/pull';
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));

      request.headers.contentType = ContentType.json;
      final body = jsonEncode({
        'storeId': storeId,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      client.close();

      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['success'] == true) {
        // Process received changes
        final changes = data['changes'] as List<dynamic>;
        for (final change in changes) {
          await _processIncomingChange(change as Map<String, dynamic>);
        }

        // Update last sync time
        await _syncService.updateLastSync();
      }

      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Push local changes to main terminal
  Future<Map<String, dynamic>> pushChanges({
    required String serverVpnAddress,
    required int serverPort,
    required int storeId,
  }) async {
    try {
      final pendingChanges = await _storeRepository.watchPendingChanges(storeId).first;

      if (pendingChanges.isEmpty) {
        return {'success': true, 'message': 'No changes to push'};
      }

      final changesData = pendingChanges.map((change) => {
            'id': change.id,
            'entityType': change.entityType,
            'entityId': change.entityId,
            'operation': change.operation,
            'payload': change.payload,
            'createdAt': change.createdAt.toIso8601String(),
          }).toList();

      final url = 'http://$serverVpnAddress:$serverPort/sync/push';
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));

      request.headers.contentType = ContentType.json;
      final body = jsonEncode({
        'storeId': storeId,
        'changes': changesData,
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      client.close();

      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['success'] == true) {
        // Mark successfully synced changes
        final processedIds = (data['processedIds'] as List<dynamic>).cast<int>();
        for (final changeId in processedIds) {
          await _syncService.markChangeSynced(changeId);
        }

        // Update last sync time
        await _syncService.updateLastSync();
      }

      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check connection and sync status with main terminal
  Future<Map<String, dynamic>> checkSyncStatus({
    required String serverVpnAddress,
    required int serverPort,
    required int storeId,
  }) async {
    try {
      final url = 'http://$serverVpnAddress:$serverPort/sync/status';
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));

      request.headers.contentType = ContentType.json;
      final body = jsonEncode({'storeId': storeId});
      request.write(body);

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      client.close();

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============== HELPER METHODS ==============

  /// Process incoming change from sync
  Future<void> _processIncomingChange(Map<String, dynamic> change) async {
    final entityType = change['entityType'] as String;
    // operation can be used for specific processing logic in the future
    // final operation = change['operation'] as String;
    final payloadStr = change['payload'] is String
        ? change['payload'] as String
        : jsonEncode(change['payload']);
    final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

    // TODO: Implement actual entity processing based on type
    // This would integrate with OrderRepository, InventoryRepository, etc.
    // For now, just log the sync operation
    await _syncService.logSync(
      targetStoreId: payload['storeId'] as int? ?? 0,
      entityType: entityType,
      entityId: change['entityId'] as int,
      status: 'processed',
    );
  }
}
