enum Environment {
  dev,
  prod,
}

class EnvConfig {
  const EnvConfig({
    required this.apiBaseUrl,
    required this.socketUrl,
    this.apiPrefix = '/api/v1',
  });

  final String apiBaseUrl;
  final String socketUrl;
  final String apiPrefix;

  String get apiUrlWithPrefix => '$apiBaseUrl$apiPrefix';
}

class Env {
  Env._();

  static Environment _environment = Environment.dev;
  static EnvConfig _config = _envConfigs[Environment.dev]!;

  static final Map<Environment, EnvConfig> _envConfigs = {
    Environment.dev: const EnvConfig(
      apiBaseUrl: 'http://localhost:3000',
      socketUrl: 'http://localhost:3000',
    ),
    Environment.prod: const EnvConfig(
      apiBaseUrl: 'https://your-api-domain.com',
      socketUrl: 'https://your-api-domain.com',
    ),
  };

  static Environment get environment => _environment;

  static EnvConfig get config => _config;

  static void setEnvironment(Environment env) {
    _environment = env;
    _config = _envConfigs[env] ?? _envConfigs[Environment.dev]!;
  }

  static bool get isDev => _environment == Environment.dev;
  static bool get isProd => _environment == Environment.prod;

  static String get baseUrl => _config.apiUrlWithPrefix;
  static String get socketUrl => _config.socketUrl;
  static String get apiPrefix => _config.apiPrefix;
}
