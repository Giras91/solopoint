import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../data/table_repository.dart';

final tableListProvider = StreamProvider<List<RestaurantTable>>((ref) {
  final repository = ref.watch(tableRepositoryProvider);
  return repository.watchAllTables();
});
