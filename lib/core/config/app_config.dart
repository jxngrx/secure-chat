import 'env.dart';
import 'flavor.dart';

class AppConfig {
  AppConfig._();

  static void initialize({
    required Environment environment,
    required Flavor flavor,
  }) {
    Env.setEnvironment(environment);
    FlavorConfig.setFlavor(flavor);
  }
}
