import 'dart:math' as Math;
import 'package:test/test.dart';
import 'package:zxcvbn/src/matching.dart';
import 'package:zxcvbn/src/scoring.dart';
import 'package:zxcvbn/src/match.dart';

//matching = require '../src/matching'

final log2 = scoring.log2;
final log10 = scoring.log10;
final nCk = scoring.nCk;
final EPSILON = 1e-10; // truncate to 10th decimal place
final truncate_float =
    (double float) => (float / EPSILON).roundToDouble() * EPSILON;
final approx_equal = (actual, expected, msg) =>
    expect(truncate_float(actual), truncate_float(expected), reason: msg);

void main() {
  test('nCk', () {
    final cases = [
      [0, 0, 1],
      [1, 0, 1],
      [5, 0, 1],
      [0, 1, 0],
      [0, 5, 0],
      [2, 1, 2],
      [4, 2, 6],
      [33, 7, 4272048],
    ];
    for (final i in cases) {
      final n = i[0];
      final k = i[1];
      final result = i[2];
      expect(
        nCk(n, k),
        result,
      ); //, "nCk(#{n}, #{k}) == #{result}"
    }
    final n = 49;
    final k = 12;
    expect(nCk(n, k), nCk(n, n - k)); // "mirror identity"
    expect(nCk(n, k),
        nCk(n - 1, k - 1) + nCk(n - 1, k)); //, "pascal's triangle identity"
  });

  test('log', () {
    for (final i in [
      [1, 0],
      [2, 1],
      [4, 2],
      [32, 5],
    ]) {
      final n = i[0].toDouble();
      final result = i[1];
      expect(log2(n), result, reason: "log2(#{n}) == #{result}");
    }
    for (final i in [
      [1, 0],
      [10, 1],
      [100, 2],
    ]) {
      final n = i[0].toDouble();
      final result = i[1];
      expect(log10(n), result, reason: "log10(#{n}) == #{result}");
    }
    final n = 17.toDouble();
    final p = 4.toDouble();
    approx_equal(log10(n * p), log10(n) + log10(p), "product rule");
    approx_equal(log10(n / p), log10(n) - log10(p), "quotient rule");
    approx_equal(log10(Math.e), 1 / Math.log(10), "base switch rule");
    approx_equal(log10(Math.pow(n, p) as double), p * log10(n), "power rule");
    approx_equal(log10(n), Math.log(n) / Math.log(10), "base change rule");
  });
  test('search', () {
    final m = (int i, int j, double guesses) => PasswordMatch()
      ..i = i
      ..j = j
      ..guesses = guesses;

    final password = '0123456789';

    // for tests, set additive penalty to zero.
    bool exclude_additive = true;

    Function msg = (String s) =>
        "returns one bruteforce match given an empty match sequence: #{s}";

    dynamic result = scoring.most_guessable_match_sequence(password, [],
        exclude_additive: true);
    expect(result.sequence.length, 1, reason: msg("result.length == 1"));

    dynamic m0 = result.sequence[0];
    expect(m0.pattern, 'bruteforce',
        reason: msg("match.pattern == 'bruteforce'"));
    expect(m0.token, password, reason: msg("match.token == #{password}"));
    expect([m0.i, m0.j], [0, 9], reason: msg("[i, j] == [#{m0.i}, #{m0.j}]"));

    msg = (String s) =>
        "returns match + bruteforce when match covers a prefix of password: #{s}";
    var matches = [m(0, 5, 1.0)];
    m0 = matches[0];
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.sequence.length, 2,
        reason: msg("result.match.sequence.length == 2"));
    expect(result.sequence[0], m0,
        reason: msg("first match is the provided match object"));
    var m1 = result.sequence[1];
    expect(m1.pattern, 'bruteforce', reason: msg("second match is bruteforce"));
    expect([m1.i, m1.j], [6, 9],
        reason: msg("second match covers full suffix after first match"));

    msg = (s) => "returns bruteforce + match when match covers a suffix: #{s}";
    matches = [m(3, 9, 1)];
    m1 = matches[0];
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.sequence.length, 2,
        reason: msg("result.match.sequence.length == 2"));
    m0 = result.sequence[0];
    expect(m0.pattern, 'bruteforce', reason: msg("first match is bruteforce"));
    expect([m0.i, m0.j], [0, 2],
        reason: msg("first match covers full prefix before second match"));
    expect(result.sequence[1], m1,
        reason: msg("second match is the provided match object"));

    msg = (s) =>
        "returns bruteforce + match + bruteforce when match covers an infix: #{s}";
    matches = [m(1, 8, 1)];
    m1 = matches[0];
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.sequence.length, 3, reason: msg("result.length == 3"));
    expect(result.sequence[1], m1,
        reason: msg("middle match is the provided match object"));
    m0 = result.sequence[0];
    var m2 = result.sequence[2];
    expect(m0.pattern, 'bruteforce', reason: msg("first match is bruteforce"));
    expect(m2.pattern, 'bruteforce', reason: msg("third match is bruteforce"));
    expect([m0.i, m0.j], [0, 0],
        reason: msg("first match covers full prefix before second match"));
    expect([m2.i, m2.j], [9, 9],
        reason: msg("third match covers full suffix after second match"));

    msg = (s) =>
        "chooses lower-guesses match given two matches of the same span: #{s}";
    matches = [m(0, 9, 1), m(0, 9, 2)];
    m0 = matches[0];
    m1 = matches[1];
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.sequence.length, 1, reason: msg("result.length == 1"));
    expect(result.sequence[0], m0, reason: msg("result.sequence[0] == m0"));
    // make sure ordering doesn't matter
    m0.guesses = 3.0;
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.sequence.length, 1, reason: msg("result.length == 1"));
    expect(result.sequence[0], m1, reason: msg("result.sequence[0] == m1"));

    msg = (s) =>
        "when m0 covers m1 and m2, choose [m0] when m0 < m1 * m2 * fact(2): #{s}";
    matches = [m(0, 9, 3), m(0, 3, 2), m(4, 9, 1)];
    m0 = matches[0];
    m1 = matches[1];
    m2 = matches[2];
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.guesses, 3, reason: msg("total guesses == 3"));
    expect(result.sequence, [m0], reason: msg("sequence is [m0]"));

    msg = (s) =>
        "when m0 covers m1 and m2, choose [m1, m2] when m0 > m1 * m2 * fact(2): #{s}";
    m0.guesses = 5.0;
    result = scoring.most_guessable_match_sequence(password, matches,
        exclude_additive: exclude_additive);
    expect(result.guesses, 4, reason: msg("total guesses == 4"));
    expect(result.sequence, [m1, m2], reason: msg("sequence is [m1, m2]"));
  });

  test('calc_guesses', () {
    PasswordMatch match = PasswordMatch()..guesses = 1;
    String msg = "estimate_guesses returns cached guesses when available";
    expect(scoring.estimate_guesses(match, ''), 1, reason: msg);
    match = PasswordMatch()
      ..pattern = 'date'
      ..token = '1977'
      ..year = 1977
      ..month = 7
      ..day = 14;
    msg = "estimate_guesses delegates based on pattern";
    expect(scoring.estimate_guesses(match, '1977'), scoring.date_guesses(match),
        reason: msg);
  });

  test('repeat guesses', () {
    for (final testCase in [
      ['aa', 'a', 2],
      ['999', '9', 3],
      [r'$$$$', r'$', 4],
      ['abab', 'ab', 2],
      ['batterystaplebatterystaplebatterystaple', 'batterystaple', 3]
    ]) {
      final token = testCase[0];
      final base_token = testCase[1];
      final repeat_count = testCase[2];

      final base_guesses = scoring
          .most_guessable_match_sequence(
              base_token as String, matching.omnimatch(base_token))
          .guesses;
      final match = PasswordMatch()
        ..token = token as String?
        ..base_token = base_token
        ..base_guesses = base_guesses.round()
        ..repeat_count = repeat_count as int?;
      final expected_guesses = base_guesses * (repeat_count as num);
      final msg =
          "the repeat pattern '#{token}' has guesses of #{expected_guesses}";
      expect(scoring.repeat_guesses(match), expected_guesses, reason: msg);
    }
  });
  test('sequence guesses', () {
    for (final testCase in [
      ['ab', true, 4 * 2], //      # obvious start * len-2
      ['XYZ', true, 26 * 3], //    # base26 * len-3
      ['4567', true, 10 * 4], //    # base10 * len-4
      ['7654', false, 10 * 4 * 2], // # base10 * len 4 * descending
      ['ZYX', false, 4 * 3 * 2], //  # obvious start * len-3 * descending
    ]) {
      final token = testCase[0];
      final ascending = testCase[1];
      final guesses = testCase[2];
      final match = PasswordMatch()
        ..token = token as String?
        ..ascending = ascending as bool?;
      final msg = "the sequence pattern '#{token}' has guesses of #{guesses}";
      expect(scoring.sequence_guesses(match), guesses, reason: msg);
    }
  });

  test('regex guesses', () {
    PasswordMatch match = PasswordMatch()
      ..token = 'aizocdk'
      ..regex_name = 'alpha_lower'
      ..regex_match = ['aizocdk'];
    String msg = "guesses of 26^7 for 7-char lowercase regex";
    expect(scoring.regex_guesses(match), Math.pow(26, 7), reason: msg);

    match = PasswordMatch()
      ..token = 'ag7C8'
      ..regex_name = 'alphanumeric'
      ..regex_match = ['ag7C8'];
    msg = "guesses of 62^5 for 5-char alphanumeric regex";
    expect(scoring.regex_guesses(match), Math.pow(2 * 26 + 10, 5), reason: msg);

    match = PasswordMatch()
      ..token = '1972'
      ..regex_name = 'recent_year'
      ..regex_match = ['1972'];
    msg = "guesses of |year - REFERENCE_YEAR| for distant year matches";
    expect(scoring.regex_guesses(match), (scoring.REFERENCE_YEAR - 1972).abs(),
        reason: msg);

    match = PasswordMatch()
      ..token = '2005'
      ..regex_name = 'recent_year'
      ..regex_match = ['2005'];
    msg = "guesses of MIN_YEAR_SPACE for a year close to REFERENCE_YEAR";
    expect(scoring.regex_guesses(match), scoring.MIN_YEAR_SPACE, reason: msg);
  });

  test('date guesses', () {
    PasswordMatch match = PasswordMatch()
      ..token = '1123'
      ..separator = ''
      ..has_full_year = false
      ..year = 1923
      ..month = 1
      ..day = 1;
    String msg = "guesses for ${match.token} is 365 * distance_from_ref_year";
    expect(scoring.date_guesses(match),
        365 * (scoring.REFERENCE_YEAR - match.year!).abs(),
        reason: msg);

    match = PasswordMatch()
      ..token = '1/1/2010'
      ..separator = '/'
      ..has_full_year = true
      ..year = 2010
      ..month = 1
      ..day = 1;
    msg = "recent years assume MIN_YEAR_SPACE.";
    msg += " extra guesses are added for separators.";
    expect(scoring.date_guesses(match), 365 * scoring.MIN_YEAR_SPACE * 4,
        reason: msg);
  });

  test('spatial guesses', () {
    PasswordMatch match = PasswordMatch()
      ..token = 'zxcvbn'
      ..graph = 'qwerty'
      ..turns = 1
      ..shifted_count = 0;

    final base_guesses = (scoring.KEYBOARD_STARTING_POSITIONS *
        scoring.KEYBOARD_AVERAGE_DEGREE *
        // # - 1 term because: not counting spatial patterns of length 1
        // # eg for length==6, multiplier is 5 for needing to try len2,len3,..,len6
        (match.token!.length - 1));
    String msg =
        "with no turns or shifts, guesses is starts * degree * (len-1)";
    expect(scoring.spatial_guesses(match), base_guesses, reason: msg);

    match.guesses = null;
    match.token = 'ZxCvbn';
    match.shifted_count = 2;
    double shifted_guesses = base_guesses * (nCk(6, 2) + nCk(6, 1));
    msg =
        "guesses is added for shifted keys, similar to capitals in dictionary matching";
    expect(scoring.spatial_guesses(match), shifted_guesses, reason: msg);

    match.guesses = null;
    match.token = 'ZXCVBN';
    match.shifted_count = 6;
    shifted_guesses = base_guesses * 2;

    msg = "when everything is shifted, guesses are doubled";
    expect(scoring.spatial_guesses(match), shifted_guesses, reason: msg);

    match = PasswordMatch()
      ..token = 'zxcft6yh'
      ..graph = 'qwerty'
      ..turns = 3
      ..shifted_count = 0;
    double guesses = 0;
    int L = match.token!.length;
    final s = scoring.KEYBOARD_STARTING_POSITIONS;
    final d = scoring.KEYBOARD_AVERAGE_DEGREE;
    for (int i = 2; i <= L; i++) {
      for (int j = 1; j <= Math.min<int>(match.turns!, i - 1); j++) {
        guesses += nCk(i - 1, j - 1) * s * Math.pow(d, j);
      }
    }
    msg =
        "spatial guesses accounts for turn positions, directions and starting keys";
    expect(scoring.spatial_guesses(match), guesses, reason: msg);
  });
  test('dictionary guesses', () {
    PasswordMatch match = PasswordMatch()
      ..token = 'aaaaa'
      ..rank = 32;
    String msg = "base guesses == the rank";
    expect(scoring.dictionary_guesses(match), 32, reason: msg);

    match = PasswordMatch()
      ..token = 'AAAaaa'
      ..rank = 32;
    msg = "extra guesses are added for capitalization";
    expect(scoring.dictionary_guesses(match),
        32 * scoring.uppercase_variations(match),
        reason: msg);

    match = PasswordMatch()
      ..token = 'aaa'
      ..rank = 32
      ..reversed = true;
    msg = "guesses are doubled when word is reversed";
    expect(scoring.dictionary_guesses(match), 32 * 2, reason: msg);

    match = PasswordMatch()
      ..token = 'aaa@@@'
      ..rank = 32
      ..l33t = true
      ..sub = {'@': 'a'};
    msg = "extra guesses are added for common l33t substitutions";

    expect(
        scoring.dictionary_guesses(match), 32 * scoring.l33t_variations(match),
        reason: msg);

    match = PasswordMatch()
      ..token = 'AaA@@@'
      ..rank = 32
      ..l33t = true
      ..sub = {'@': 'a'};
    msg =
        "extra guesses are added for both capitalization and common l33t substitutions";
    double expected = 32.0 *
        scoring.l33t_variations(match) *
        scoring.uppercase_variations(match);
    expect(scoring.dictionary_guesses(match), expected, reason: msg);
  });

  test('uppercase variants', () {
    for (final testCase in [
      ['', 1],
      ['a', 1],
      ['A', 2],
      ['abcdef', 1],
      ['Abcdef', 2],
      ['abcdeF', 2],
      ['ABCDEF', 2],
      ['aBcdef', nCk(6, 1)],
      ['aBcDef', nCk(6, 1) + nCk(6, 2)],
      ['ABCDEf', nCk(6, 1)],
      ['aBCDEf', nCk(6, 1) + nCk(6, 2)],
      ['ABCdef', nCk(6, 1) + nCk(6, 2) + nCk(6, 3)],
    ]) {
      final word = testCase[0];
      final variants = testCase[1];
      String msg = "guess multiplier of #{word} is #{variants}";
      PasswordMatch m = PasswordMatch()..token = word as String?;
      expect(scoring.uppercase_variations(m), variants, reason: msg);
    }
  });
  test('l33t variants', () {
    PasswordMatch match = PasswordMatch()..l33t = false;
    expect(scoring.l33t_variations(match), 1,
        reason: "1 variant for non-l33t matches");

    for (final testCase in [
      ['', 1.0, {}],
      ['a', 1.0, {}],
      [
        '4',
        2.0,
        {'4': 'a'}
      ],
      [
        '4pple',
        2.0,
        {'4': 'a'}
      ],
      ['abcet', 1, {}],
      [
        '4bcet',
        2.0,
        {'4': 'a'}
      ],
      [
        'a8cet',
        2.0,
        {'8': 'b'}
      ],
      [
        'abce+',
        2.0,
        {'+': 't'}
      ],
      [
        '48cet',
        4.0,
        {'4': 'a', '8': 'b'}
      ],
      [
        'a4a4aa',
        nCk(6, 2) + nCk(6, 1),
        {'4': 'a'}
      ],
      [
        '4a4a44',
        nCk(6, 2) + nCk(6, 1),
        {'4': 'a'}
      ],
      [
        'a44att+',
        (nCk(4, 2) + nCk(4, 1)) * nCk(3, 1),
        {'4': 'a', '+': 't'}
      ],
    ]) {
      final word = testCase[0];
      num v = testCase[1] as num;
      double variants = v.toDouble();
      final sub = testCase[2];
      match = PasswordMatch()
        ..token = word as String?
        ..sub = sub as Map<dynamic, dynamic>?
        ..l33t = !matching.empty(sub);
      String msg = "extra l33t guesses of #{word} is #{variants}";
      expect(scoring.l33t_variations(match), variants, reason: msg);
      match = PasswordMatch()
        ..token = 'Aa44aA'
        ..l33t = true
        ..sub = {'4': 'a'};
      variants = nCk(6, 2) + nCk(6, 1);
      msg = "capitalization doesn't affect extra l33t guesses calc";
      expect(scoring.l33t_variations(match), variants, reason: msg);
    }
  });
}
