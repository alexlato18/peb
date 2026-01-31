enum SpanishSuit { oros, copas, espadas, bastos }

class SpanishCard {
  final SpanishSuit suit;

  /// 1-7, 10-12 (baraja española de 40)
  final int value;

  const SpanishCard({required this.suit, required this.value});

  /// Valor numérico para comparar (10,11,12 son mayores que 7)
  int get rank => value;

  String get suitLabel {
    switch (suit) {
      case SpanishSuit.oros:
        return "Oros";
      case SpanishSuit.copas:
        return "Copas";
      case SpanishSuit.espadas:
        return "Espadas";
      case SpanishSuit.bastos:
        return "Bastos";
    }
  }

  String get valueLabel {
    switch (value) {
      case 10:
        return "Sota (10)";
      case 11:
        return "Caballo (11)";
      case 12:
        return "Rey (12)";
      default:
        return value.toString();
    }
  }

  /// Para “Par o impar”, usamos el número tal cual (10,11,12 cuentan como números)
  bool get isEven => rank % 2 == 0;

  @override
  String toString() => "$valueLabel de $suitLabel";
}
