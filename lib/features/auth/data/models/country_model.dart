class CountryModel {
  final String code;
  final String name;
  final String flag;
  final String dialCode;

  CountryModel({
    required this.code,
    required this.name,
    required this.flag,
    required this.dialCode,
  });

  static List<CountryModel> getCountries() {
    return [
      CountryModel(
        code: 'US',
        name: 'United States',
        flag: '🇺🇸',
        dialCode: '+1',
      ),
      CountryModel(
        code: 'GB',
        name: 'United Kingdom',
        flag: '🇬🇧',
        dialCode: '+44',
      ),
      CountryModel(
        code: 'CA',
        name: 'Canada',
        flag: '🇨🇦',
        dialCode: '+1',
      ),
      CountryModel(
        code: 'AU',
        name: 'Australia',
        flag: '🇦🇺',
        dialCode: '+61',
      ),
      CountryModel(
        code: 'IN',
        name: 'India',
        flag: '🇮🇳',
        dialCode: '+91',
      ),
      // Add more countries as needed
    ];
  }
}
