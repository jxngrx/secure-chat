import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/contact_repo_impl.dart';
import '../../domain/repositories/contact_repository.dart';

/// Contact repository provider
final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepositoryImpl.instance;
});
