import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_update_repository.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) => AppUpdateRepository());
