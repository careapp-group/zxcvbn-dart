import 'package:test/test.dart';
import 'package:zxcvbn/src/result.dart';
import 'package:zxcvbn/zxcvbn.dart';

void main() {
  group(Zxcvbn, () {
    final zxcvbn = Zxcvbn();
    test('zxcvbn', () {
      Result result = zxcvbn.evaluate('zxcvbn');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 1.76343);
    });
    test('qwer43@!', () {
      final result = zxcvbn.evaluate('qwer43@!');
      expect(result.score!.round(), 2);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 7.3033);
    });
    test('Tr0ub4dour&3', () {
      final result = zxcvbn.evaluate('Tr0ub4dour&3');
      expect(result.score!.round(), 2);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 7.28008);
    });
    test('correcthorsebatterystaple', () {
      final result = zxcvbn.evaluate('correcthorsebatterystaple');
      expect(result.score!.round(), 4);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 14.43696);
    });
    test('correcthorsebatterystaple with subs', () {
      final result = zxcvbn.evaluate(r'coRrecth0rseba++ery9.23.2007staple$');
      expect(result.score!.round(), 4);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 20.71185);
    });
    test('p@ssword', () {
      final result = zxcvbn.evaluate('p@ssword');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 0.69897);
    });
    test('password with more subs', () {
      final result = zxcvbn.evaluate(r'p@$$word');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 0.95424);
    });
    test('123456', () {
      final result = zxcvbn.evaluate(r'123456');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 0.30103);
    });
    test('123456789', () {
      final result = zxcvbn.evaluate(r'123456789');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 0.77815);
    });
    test('11111111', () {
      final result = zxcvbn.evaluate(r'11111111');
      expect(result.score!.round(), 0);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 1.80618);
    });
    test('zxcvbnm,./', () {
      final result = zxcvbn.evaluate(r'zxcvbnm,./');
      expect(result.score!.round(), 1);
      expect(double.parse(result.guesses_log10.toStringAsFixed(5)), 3.58984);
    });
  });
}
