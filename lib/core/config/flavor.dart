enum Flavor {
  dev,
  staging,
  prod,
}

class FlavorConfig {
  FlavorConfig._();

  static Flavor _flavor = Flavor.dev;

  static Flavor get flavor => _flavor;

  static void setFlavor(Flavor flavor) {
    _flavor = flavor;
  }

  static String get appName {
    switch (_flavor) {
      case Flavor.dev:
        return 'Chat App (Dev)';
      case Flavor.staging:
        return 'Chat App (Staging)';
      case Flavor.prod:
        return 'Chat App';
    }
  }
}
