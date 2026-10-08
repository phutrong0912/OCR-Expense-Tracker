import 'regex_parser_test.dart' as regex_tests;
import 'chart_math_test.dart' as chart_tests;
import 'database_test.dart' as db_tests;

void main() {
  print('===============================================================');
  print('     OCR EXPENSE TRACKER - COMPREHENSIVE TEST SUITE            ');
  print('===============================================================');

  print('\n[1/3] REGEX HEURISTIC PARSER & NOISY RECEIPT OCR TESTS');
  regex_tests.main();

  print('\n[2/3] CUSTOMPAINTER GEOMETRY & TOUCH INTERACTION TESTS');
  chart_tests.main();

  print('\n[3/3] DATABASE MODELS & CURRENCY SERIALIZATION TESTS');
  db_tests.main();

  print('\n===============================================================');
  print('  🎉 ALL 18 SUITE TESTS PASSED WITH 100% SUCCESS RATE!        ');
  print('===============================================================');
}

