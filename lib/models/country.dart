class Country {
  final String code;
  final String name;
  final String languageCode;

  const Country({
    required this.code,
    required this.name,
    required this.languageCode,
  });

  @override
  String toString() => '$name ($code)';
}
