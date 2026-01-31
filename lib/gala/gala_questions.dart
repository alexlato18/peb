enum GalaQuestionType { profileSingle, text }

class GalaQuestion {
  const GalaQuestion({
    required this.id,
    required this.title,
    required this.type,
    this.maxLen = 120,
    this.optional = false,
  });

  final String id;
  final String title;
  final GalaQuestionType type;
  final int maxLen;
  final bool optional;
}

/// ✅ SOLO 3 preguntas fijas para todos los eventos de gala
const galaQuestions = <GalaQuestion>[
  GalaQuestion(
    id: 'mvp',
    title: 'MVP (elige 1 persona)',
    type: GalaQuestionType.profileSingle,
    optional: false,
  ),
  GalaQuestion(
    id: 'moment_of_year_candidate',
    title: '¿Algún candidato a “Momento del año”? (opcional)',
    type: GalaQuestionType.text,
    maxLen: 140,
    optional: true,
  ),
  GalaQuestion(
    id: 'quote_of_year',
    title: 'Frase del año (opcional)',
    type: GalaQuestionType.text,
    maxLen: 140,
    optional: true,
  ),
];
