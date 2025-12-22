enum Environment {
  dev,
  prod,
}

class Env {
  Env._();

  static Environment _environment = Environment.dev;

  static Environment get environment => _environment;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static bool get isDev => _environment == Environment.dev;
  static bool get isProd => _environment == Environment.prod;

  // API URLs
  static String get baseUrl {
    switch (_environment) {
      case Environment.dev:
        return 'https://api-dev.example.com';
      case Environment.prod:
        return 'https://api.example.com';
    }
  }

  // WebSocket URLs
  static String get wsUrl {
    switch (_environment) {
      case Environment.dev:
        return 'wss://ws-dev.example.com';
      case Environment.prod:
        return 'wss://ws.example.com';
    }
  }
}
