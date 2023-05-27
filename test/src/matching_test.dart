import 'package:test/test.dart';
import 'package:zxcvbn/src/match.dart';
import 'package:zxcvbn/src/matching.dart';
import 'package:zxcvbn/src/adjacency_graphs.dart';

// takes a pattern and list of prefixes/suffixes
// returns a bunch of variants of that pattern embedded
// with each possible prefix/suffix combination, including no prefix/suffix
// returns a list of triplets [variant, i, j] where [i,j] is the start/end of the pattern, inclusive
genpws(pattern, prefixes, suffixes) {
  prefixes = [...prefixes];
  suffixes = [...suffixes];
  for (List lst in [prefixes, suffixes]) {
    if (!lst.contains('')) {
      lst.insert(0, '');
    }
  }
  final result = [];
  for (final prefix in prefixes) {
    for (final suffix in suffixes) {
      int? i = prefix.length;
      int? j = prefix.length + pattern.length - 1;
      result.add([prefix + pattern + suffix, i, j]);
    }
  }
  return result;
}

check_matches(prefix, List<PasswordMatch> matches, pattern_names, patterns, ijs,
    Map<String, List<dynamic>> props) {
  if (pattern_names is String) {
    // shortcut: if checking for a list of the same type of patterns,
    // allow passing a string 'pat' instead of array ['pat', 'pat', ...]
    pattern_names = List.generate(patterns.length, (index) => pattern_names);
  }

  bool is_equal_len_args = pattern_names.length == patterns.length &&
      pattern_names.length == ijs.length;

  props.forEach((prop, lst) {
    is_equal_len_args = is_equal_len_args && (lst.length == patterns.length);
    if (!is_equal_len_args) {
      throw Exception('unequal argument lists to check matches');
    }
  });

  String msg = "${prefix}: matches.length == ${patterns.length}";

  expect(matches.length, patterns.length, reason: msg);

  for (int k = 0; k < patterns.length; k++) {
    final match = matches[k];
    final pattern_name = pattern_names[k];
    final pattern = patterns[k];

    int? i = ijs[k][0];
    int? j = ijs[k][1];

    msg = "${prefix}: matches[${k}].pattern == '${pattern_name}'";
    expect(match.pattern, pattern_name, reason: msg);
    msg = "${prefix}: matches[${k}] should have [i, j] of [${i}, ${j}]";

    expect([match.i, match.j], [i, j], reason: msg);

    msg = "${prefix}: matches[${k}].token == '${pattern}'";
    expect(match.token, pattern, reason: msg);
    props.forEach((prop_name, prop_list) {
      dynamic prop_msg = prop_list[k];
      if (prop_msg is String) {
        prop_msg = "'${prop_msg}'";
      }
      msg = "${prefix}: matches[${k}].${prop_name} == ${prop_msg}";
      expect(match[prop_name], prop_list[k], reason: msg);
    });
  }
}

void main() {
  test('matching utils', () {
    expect(matching.empty([]), true,
        reason: ".empty returns true for an empty array");
    expect(matching.empty({}), true,
        reason: ".empty returns true for an empty object");

    for (final obj in [
      [1],
      [1, 2],
      [[]],
      {'a': 1},
      {0: {}},
    ]) {
      expect(matching.empty(obj), false,
          reason: ".empty returns false for non-empty objects and arrays");
    }

    var lst = [];
    matching.extend(lst, []);
    expect(lst, [],
        reason: "extending an empty list with an empty list leaves it empty");
    matching.extend(lst, [1]);
    expect(lst, [1],
        reason:
            "extending an empty list with another makes it equal to the other");
    matching.extend(lst, [2, 3]);
    expect(lst, [1, 2, 3],
        reason:
            "extending a list with another adds each of the other's elements");
    final lst1 = [1];
    final lst2 = [2];
    matching.extend(lst1, lst2);
    expect(lst2, [2],
        reason: "extending a list by another doesn't affect the other");

    var chr_map = <String, String>{'a': 'A', 'b': 'B'};
    for (final testCase in [
      ['a', chr_map, 'A'],
      ['c', chr_map, 'c'],
      ['ab', chr_map, 'AB'],
      ['abc', chr_map, 'ABc'],
      ['aa', chr_map, 'AA'],
      ['abab', chr_map, 'ABAB'],
      ['', chr_map, ''],
      ['', <String, String>{}, ''],
      ['abc', <String, String>{}, 'abc'],
    ]) {
      final String string = testCase[0] as String;
      final Map<String, String> map = testCase[1] as Map<String, String>;
      final result = testCase[2];
      final msg = "translates '${string}' to '${result}' with provided charmap";
      expect(matching.translate(string, map), result, reason: msg);
    }

    for (final testCase in [
      [0, 1, 0],
      [1, 1, 0],
      [-1, 1, 0],
      [5, 5, 0],
      [3, 5, 3],
      [-1, 5, 4],
      [-5, 5, 0],
      [6, 5, 1],
    ]) {
      final dividend = testCase[0];
      final divisor = testCase[1];
      final remainder = testCase[2];
      final msg = "mod(${dividend}, ${divisor}) == ${remainder}";
      expect(matching.mod(dividend, divisor), remainder, reason: msg);
    }

    expect(matching.sorted([]), [],
        reason: "sorting an empty list leaves it empty");

    final m1 = PasswordMatch()
      ..i = 5
      ..j = 5;
    final m2 = PasswordMatch()
      ..i = 6
      ..j = 7;
    final m3 = PasswordMatch()
      ..i = 2
      ..j = 5;
    final m4 = PasswordMatch()
      ..i = 0
      ..j = 0;
    final m5 = PasswordMatch()
      ..i = 2
      ..j = 3;
    final m6 = PasswordMatch()
      ..i = 0
      ..j = 3;

    final msg = "matches are sorted on i index primary, j secondary";
    expect(matching.sorted([m1, m2, m3, m4, m5, m6]), [m4, m6, m5, m3, m1, m2],
        reason: msg);
  });

  test('dictionary matching', () {
    final test_dicts = {
      'd1': {
        'motherboard': 1,
        'mother': 2,
        'board': 3,
        'abcd': 4,
        'cdef': 5,
      },
      'd2': {
        'z': 1,
        '8': 2,
        '99': 3,
        r'$': 4,
        'asdf1234&*': 5,
      }
    };

    final dm =
        (pw) => matching.dictionary_match(pw, ranked_dictionaries: test_dicts);

    List<PasswordMatch> matches = dm('motherboard');
    List<String> patterns = ['mother', 'motherboard', 'board'];
    String msg = "matches words that contain other words";

    check_matches(msg, matches, 'dictionary', patterns, [
      [0, 5],
      [0, 10],
      [6, 10]
    ], {
      'matched_word': ['mother', 'motherboard', 'board'],
      'rank': [2, 1, 3],
      'dictionary_name': ['d1', 'd1', 'd1']
    });

    matches = dm('abcdef');
    patterns = ['abcd', 'cdef'];
    msg = "matches multiple words when they overlap";

    check_matches(msg, matches, 'dictionary', patterns, [
      [0, 3],
      [2, 5]
    ], {
      'matched_word': ['abcd', 'cdef'],
      'rank': [4, 5],
      'dictionary_name': ['d1', 'd1'],
    });

    matches = dm('BoaRdZ');
    patterns = ['BoaRd', 'Z'];
    msg = "ignores uppercasing";
    check_matches(msg, matches, 'dictionary', patterns, [
      [0, 4],
      [5, 5]
    ], {
      'matched_word': ['board', 'z'],
      'rank': [3, 1],
      'dictionary_name': ['d1', 'd2']
    });

    final prefixes = ['q', '%%'];
    final suffixes = ['%', 'qq'];
    final word = 'asdf1234&*';

    for (final testCase in genpws(word, prefixes, suffixes)) {
      final password = testCase[0];
      final i = testCase[1];
      final j = testCase[2];

      final matches = dm(password);
      final msg = "identifies words surrounded by non-words";
      check_matches(msg, matches, 'dictionary', [
        word
      ], [
        [i, j]
      ], {
        'matched_word': [word],
        'rank': [5],
        'dictionary_name': ['d2'],
      });
    }

    test_dicts.forEach((name, dict) {
      dict.forEach((word, rank) {
        if (word != 'motherboard') {
          final matches = dm(word);
          final msg = "matches against all words in provided dictionaries";
          check_matches(msg, matches, 'dictionary', [
            word
          ], [
            [0, word.length - 1]
          ], {
            'matched_word': [word],
            'rank': [rank],
            'dictionary_name': [name]
          });
        }
      });
    });

    // test the default dictionaries
    matches = matching.dictionary_match('wow');
    patterns = ['wow'];
    final ijs = [
      [0, 2]
    ];
    msg = "default dictionaries";
    check_matches(msg, matches, 'dictionary', patterns, ijs, {
      'matched_word': patterns,
      'rank': [322],
      'dictionary_name': ['us_tv_and_film']
    });

    matching.set_user_input_dictionary(['foo', 'bar']);
    matches = matching.dictionary_match('foobar');
    matches = matches
        .where((match) => match.dictionary_name == 'user_inputs')
        .toList();
    msg = "matches with provided user input dictionary";
    check_matches(msg, matches, 'dictionary', [
      'foo',
      'bar'
    ], [
      [0, 2],
      [3, 5]
    ], {
      'matched_word': ['foo', 'bar'],
      'rank': [1, 2]
    });
  });
  test('reverse dictionary matching', () {
    final test_dicts = {
      'd1': {
        '123': 1,
        '321': 2,
        '456': 3,
        '654': 4,
      }
    };
    final password = '0123456789';
    final matches = matching.reverse_dictionary_match(password,
        ranked_dictionaries: test_dicts);
    final msg = 'matches against reversed words';
    check_matches(msg, matches, 'dictionary', [
      '123',
      '456'
    ], [
      [1, 3],
      [4, 6]
    ], {
      'matched_word': ['321', '654'],
      'reversed': [true, true],
      'dictionary_name': ['d1', 'd1'],
      'rank': [2, 4],
    });
  });
  test('l33t matching', () {
    final test_table = <String, List<String>>{
      'a': ['4', '@'],
      'c': ['(', '{', '[', '<'],
      'g': ['6', '9'],
      'o': ['0'],
    };

    for (final testCase in [
      ['', <String, List<String>>{}],
      [r'abcdefgo123578!#$&*)]}>', <String, List<String>>{}],
      ['a', <String, List<String>>{}],
      [
        '4',
        <String, List<String>>{
          'a': ['4']
        }
      ],
      [
        '4@',
        <String, List<String>>{
          'a': ['4', '@']
        }
      ],
      [
        '4({60',
        <String, List<String>>{
          'a': ['4'],
          'c': ['(', '{'],
          'g': ['6'],
          'o': ['0']
        }
      ],
    ]) {
      final pw = testCase[0];
      final expected = testCase[1];
      final msg =
          "reduces l33t table to only the substitutions that a password might be employing";
      expect(
          matching.relevant_l33t_subtable(pw as String, test_table), expected,
          reason: msg);
    }

    for (final testCase in [
      [
        <String, List<String>>{},
        <Map<String, String>>[{}]
      ],
      [
        <String, List<String>>{
          'a': ['@']
        },
        <Map<String, String>>[
          {'@': 'a'}
        ]
      ],
      [
        <String, List<String>>{
          'a': ['@', '4']
        },
        <Map<String, String>>[
          {'@': 'a'},
          {'4': 'a'}
        ]
      ],
      [
        <String, List<String>>{
          'a': ['@', '4'],
          'c': ['(']
        },
        <Map<String, String>>[
          {'@': 'a', '(': 'c'},
          {'4': 'a', '(': 'c'}
        ]
      ],
    ]) {
      final Map<String, List<String>> table =
          testCase[0] as Map<String, List<String>>;
      final List<Map<String, String>> subs =
          testCase[1] as List<Map<String, String>>;
      final msg =
          "enumerates the different sets of l33t substitutions a password might be using";
      expect(matching.enumerate_l33t_subs(table), subs, reason: msg);
    }

    final dicts = {
      'words': {
        'aac': 1,
        'password': 3,
        'paassword': 4,
        'asdf0': 5,
      },
      'words2': {
        'cgo': 1,
      }
    };
    final lm = (pw) => matching.l33t_match(pw,
        ranked_dictionaries: dicts, l33t_table: test_table);

    expect(lm(''), [], reason: "doesn't match ''");
    expect(lm('password'), [], reason: "doesn't match pure dictionary words");

    for (final testCase in [
      [
        'p4ssword',
        'p4ssword',
        'password',
        'words',
        3,
        [0, 7],
        {'4': 'a'}
      ],
      [
        'p@ssw0rd',
        'p@ssw0rd',
        'password',
        'words',
        3,
        [0, 7],
        {'@': 'a', '0': 'o'}
      ],
      [
        'aSdfO{G0asDfO',
        '{G0',
        'cgo',
        'words2',
        1,
        [5, 7],
        {'{': 'c', '0': 'o'}
      ],
    ]) {
      final password = testCase[0];
      final pattern = testCase[1];
      final word = testCase[2];
      final dictionary_name = testCase[3];
      final rank = testCase[4];
      final ij = testCase[5];
      final sub = testCase[6];
      final msg = "matches against common l33t substitutions";
      check_matches(msg, lm(password), 'dictionary', [
        pattern
      ], [
        ij
      ], {
        'l33t': [true],
        'sub': [sub],
        'matched_word': [word],
        'rank': [rank],
        'dictionary_name': [dictionary_name],
      });
    }

    var matches = lm('@a(go{G0');
    String msg = "matches against overlapping l33t patterns";

    check_matches(msg, matches, 'dictionary', [
      '@a(',
      '(go',
      '{G0'
    ], [
      [0, 2],
      [2, 4],
      [5, 7]
    ], {
      'l33t': [true, true, true],
      'sub': [
        {'@': 'a', '(': 'c'},
        {'(': 'c'},
        {'{': 'c', '0': 'o'}
      ],
      'matched_word': ['aac', 'cgo', 'cgo'],
      'rank': [1, 1, 1],
      'dictionary_name': ['words', 'words2', 'words2'],
    });

    msg =
        "doesn't match when multiple l33t substitutions are needed for the same letter";
    expect(lm('p4@ssword'), [], reason: msg);

    msg = "doesn't match single-character l33ted words";
    matches = matching.l33t_match('4 1 @');
    expect(matches, [], reason: msg);

    //  known issue: subsets of substitutions aren't tried.
    //  for long inputs, trying every subset of every possible substitution could quickly get large,
    //  but there might be a performant way to fix.
    //  (so in this example: {'4': a, '0': 'o'} is detected as a possible sub,
    //  but the subset {'4': 'a'} isn't tried, missing the match for asdf0.)
    //  TODO: consider partially fixing by trying all subsets of size 1 and maybe 2
    msg = "doesn't match with subsets of possible l33t substitutions";
    expect(lm('4sdf0'), [], reason: msg);
  });

  test('spatial matching', () {
    for (final String password in ['', '/', 'qw', '*/']) {
      String msg = "doesn't match 1- and 2-character spatial patterns";
      expect(matching.spatial_match(password), [], reason: msg);
    }

    // for testing, make a subgraph that contains a single keyboard
    final _graphs = {'qwerty': adjacency_graphs['qwerty']};
    String pattern = '6tfGHJ';
    List<PasswordMatch> matches =
        matching.spatial_match("rz!${pattern}%z", _graphs);
    String msg =
        "matches against spatial patterns surrounded by non-spatial patterns";

    check_matches(msg, matches, 'spatial', [
      pattern
    ], [
      [3, 3 + pattern.length - 1]
    ], {
      'graph': ['qwerty'],
      'turns': [2],
      'shifted_count': [3],
    });

    for (final testCase in [
      ['12345', 'qwerty', 1, 0],
      ['@WSX', 'qwerty', 1, 4],
      ['6tfGHJ', 'qwerty', 2, 3],
      ['hGFd', 'qwerty', 1, 2],
      ['/;p09876yhn', 'qwerty', 3, 0],
      ['Xdr%', 'qwerty', 1, 2],
      ['159-', 'keypad', 1, 0],
      ['*84', 'keypad', 1, 0],
      ['/8520', 'keypad', 1, 0],
      ['369', 'keypad', 1, 0],
      ['/963.', 'mac_keypad', 1, 0],
      ['*-632.0214', 'mac_keypad', 9, 0],
      ['aoEP%yIxkjq:', 'dvorak', 4, 5],
      [';qoaOQ:Aoq;a', 'dvorak', 11, 4],
    ]) {
      final String pattern = testCase[0] as String;
      final keyboard = testCase[1];
      final turns = testCase[2];
      final shifts = testCase[3];

      final Map<String, Map<String, List<String?>>?> _graphs =
          <String, Map<String, List<String?>>?>{};
      _graphs[keyboard as String] = adjacency_graphs[keyboard];
      List<PasswordMatch> matches = matching.spatial_match(pattern, _graphs);
      String msg = "matches '#{pattern}' as a #{keyboard} pattern";
      check_matches(msg, matches, 'spatial', [
        pattern
      ], [
        [0, pattern.length - 1]
      ], {
        'graph': [keyboard],
        'turns': [turns],
        'shifted_count': [shifts],
      });
    }
  });
  test('sequence matching', () {
    for (final password in ['', 'a', '1']) {
      final msg = "doesn't match length-${password.length} sequences";
      expect(matching.sequence_match(password), [], reason: msg);
    }

    List<PasswordMatch> matches = matching.sequence_match('abcbabc');
    String msg = "matches overlapping patterns";
    check_matches(msg, matches, 'sequence', [
      'abc',
      'cba',
      'abc'
    ], [
      [0, 2],
      [2, 4],
      [4, 6]
    ], {
      'ascending': [true, false, true]
    });

    List<String> prefixes = ['!', '22'];
    List<String> suffixes = ['!', '22'];
    String pattern = 'jihg';

    final genpwsResult = genpws(pattern, prefixes, suffixes);

    for (final testCase in genpwsResult) {
      String password = testCase[0];
      int? i = testCase[1];
      int? j = testCase[2];

      matches = matching.sequence_match(password);
      msg = "matches embedded sequence patterns ${password}";
      check_matches(msg, matches, 'sequence', [
        pattern
      ], [
        [i, j]
      ], {
        'sequence_name': ['lower'],
        'ascending': [false]
      });
    }

    for (final testCase in [
      ['ABC', 'upper', true],
      ['CBA', 'upper', false],
      ['PQR', 'upper', true],
      ['RQP', 'upper', false],
      ['XYZ', 'upper', true],
      ['ZYX', 'upper', false],
      ['abcd', 'lower', true],
      ['dcba', 'lower', false],
      ['jihg', 'lower', false],
      ['wxyz', 'lower', true],
      ['zxvt', 'lower', false],
      ['0369', 'digits', true],
      ['97531', 'digits', false],
    ]) {
      pattern = testCase[0] as String;
      String name = testCase[1] as String;
      bool is_ascending = testCase[2] as bool;
      List<PasswordMatch> matches = matching.sequence_match(pattern);
      String msg = "matches '${pattern}' as a '${name}' sequence";
      check_matches(msg, matches, 'sequence', [
        pattern
      ], [
        [0, pattern.length - 1]
      ], {
        'sequence_name': [name],
        'ascending': [is_ascending],
      });
    }
  });
  test('repeat matching', () {
    for (final password in ['', '#']) {
      final msg = "doesn't match length-#{password.length} repeat patterns";
      expect(matching.repeat_match(password), [], reason: msg);
    }

    // test single-character repeats
    List<String> prefixes = ['@', 'y4@'];
    List<String> suffixes = ['u', 'u%7'];
    String pattern = '&&&&&';

    final pws = genpws(pattern, prefixes, suffixes);
    for (final testCase in pws) {
      String password = testCase[0];
      int? i = testCase[1];
      int? j = testCase[2];
      final matches = matching.repeat_match(password);
      final msg = "matches embedded repeat patterns";
      check_matches(msg, matches, 'repeat', [
        pattern
      ], [
        [i, j]
      ], {
        'base_token': ['&']
      });
    }

    for (final length in [3, 12]) {
      for (final chr in ['a', 'Z', '4', '&']) {
        final pattern = List.generate(length, (index) => chr).join();
        final matches = matching.repeat_match(pattern);
        final msg = "matches repeats with base character '${chr}'";
        check_matches(msg, matches, 'repeat', [
          pattern
        ], [
          [0, pattern.length - 1]
        ], {
          'base_token': [chr]
        });
      }
    }

    List<PasswordMatch> matches = matching.repeat_match('BBB1111aaaaa@@@@@@');
    List<String> patterns = ['BBB', '1111', 'aaaaa', '@@@@@@'];
    String msg = 'matches multiple adjacent repeats';
    check_matches(msg, matches, 'repeat', patterns, [
      [0, 2],
      [3, 6],
      [7, 11],
      [12, 17]
    ], {
      'base_token': ['B', '1', 'a', '@']
    });

    matches = matching.repeat_match('2818BBBbzsdf1111@*&@!aaaaaEUDA@@@@@@1729');
    msg = 'matches multiple repeats with non-repeats in-between';
    check_matches(msg, matches, 'repeat', patterns, [
      [4, 6],
      [12, 15],
      [21, 25],
      [30, 35]
    ], {
      'base_token': ['B', '1', 'a', '@']
    });

    // test multi-character repeats
    pattern = 'abab';
    matches = matching.repeat_match(pattern);
    msg = 'matches multi-character repeat pattern';
    check_matches(msg, matches, 'repeat', [
      pattern
    ], [
      [0, pattern.length - 1]
    ], {
      'base_token': ['ab']
    });

    pattern = 'aabaab';
    matches = matching.repeat_match(pattern);
    msg = 'matches aabaab as a repeat instead of the aa prefix';
    check_matches(msg, matches, 'repeat', [
      pattern
    ], [
      [0, pattern.length - 1]
    ], {
      'base_token': ['aab']
    });

    pattern = 'abababab';
    matches = matching.repeat_match(pattern);
    msg = 'identifies ab as repeat string, even though abab is also repeated';
    check_matches(msg, matches, 'repeat', [
      pattern
    ], [
      [0, pattern.length - 1]
    ], {
      'base_token': ['ab']
    });
  });
  test('regex matching', () {
    for (final testCase in [
      ['1922', 'recent_year'],
      ['2017', 'recent_year'],
    ]) {
      final pattern = testCase[0];
      final name = testCase[1];
      final matches = matching.regex_match(pattern);
      final msg = "matches ${pattern} as a ${name} pattern";
      check_matches(msg, matches, 'regex', [
        pattern
      ], [
        [0, pattern.length - 1]
      ], {
        'regex_name': [name]
      });
    }

    String password = '20041910';
    List<PasswordMatch> matches = matching.regex_match(password);
    String msg = "matches multiple recent_year patterns";
    check_matches(msg, matches, 'regex', [
      '2004',
      '1910'
    ], [
      [0, 3],
      [4, 7]
    ], {
      'regex_name': ['recent_year', 'recent_year']
    });
  });

  test('date matching', () {
    for (final sep in ['', ' ', '-', '/', '\\', '_', '.']) {
      final password = "13${sep}2${sep}1921";
      final matches = matching.date_match(password);
      final msg = "matches dates that use '${sep}' as a separator";
      check_matches(msg, matches, 'date', [
        password
      ], [
        [0, password.length - 1]
      ], {
        'separator': [sep],
        'year': [1921],
        'month': [2],
        'day': [13],
      });
    }

    for (final order in ['mdy', 'dmy', 'ymd', 'ydm']) {
      final d = 8;
      final m = 8;
      final y = 88;
      final password = order
          .replaceAll('y', '$y')
          .replaceAll('m', '$m')
          .replaceAll('d', '$d');
      final matches = matching.date_match(password);
      final msg = "matches dates with '${order}' format";
      check_matches(msg, matches, 'date', [
        password
      ], [
        [0, password.length - 1]
      ], {
        'separator': [''],
        'year': [1988],
        'month': [8],
        'day': [8],
      });
    }

    String password = '111504';
    List<PasswordMatch> matches = matching.date_match(password);
    String msg =
        "matches the date with year closest to REFERENCE_YEAR when ambiguous";
    check_matches(msg, matches, 'date', [
      password
    ], [
      [0, password.length - 1]
    ], {
      'separator': [''],
      'year': [2004], // picks '04' -> 2004 as year, not '1504',
      'month': [11],
      'day': [15],
    });

    for (final testCase in [
      [1, 1, 1999],
      [11, 8, 2000],
      [9, 12, 2005],
      [22, 11, 1551],
    ]) {
      final day = testCase[0];
      final month = testCase[1];
      final year = testCase[2];
      password = "${year}${month}${day}";
      List<PasswordMatch> matches = matching.date_match(password);
      String msg = "matches ${password}";
      check_matches(msg, matches, 'date', [
        password
      ], [
        [0, password.length - 1]
      ], {
        'separator': [''],
        'year': [year],
      });
      password = "${year}.${month}.${day}";
      matches = matching.date_match(password);
      msg = "matches ${password}";
      check_matches(msg, matches, 'date', [
        password
      ], [
        [0, password.length - 1]
      ], {
        'separator': ['.'],
        'year': [year],
      });
    }

    password = "02/02/02";
    matches = matching.date_match(password);
    msg = "matches zero-padded dates";
    check_matches(msg, matches, 'date', [
      password
    ], [
      [0, password.length - 1]
    ], {
      'separator': ['/'],
      'year': [2002],
      'month': [2],
      'day': [2],
    });

    final prefixes = ['a', 'ab'];
    final suffixes = ['!'];
    String pattern = '1/1/91';

    final genpwsresult = genpws(pattern, prefixes, suffixes);
    for (final testCase in genpwsresult) {
      password = testCase[0];
      final i = testCase[1];
      final j = testCase[2];

      final matches = matching.date_match(password);
      final msg = "matches embedded dates";
      check_matches(msg, matches, 'date', [
        pattern
      ], [
        [i, j]
      ], {
        'year': [1991],
        'month': [1],
        'day': [1],
      });
    }

    matches = matching.date_match('12/20/1991.12.20');
    msg = "matches overlapping dates";
    check_matches(msg, matches, 'date', [
      '12/20/1991',
      '1991.12.20'
    ], [
      [0, 9],
      [6, 15]
    ], {
      'separator': ['/', '.'],
      'year': [1991, 1991],
      'month': [12, 12],
      'day': [20, 20],
    });

    matches = matching.date_match('912/20/919');
    msg = "matches dates padded by non-ambiguous digits";
    check_matches(msg, matches, 'date', [
      '12/20/91'
    ], [
      [1, 8]
    ], {
      'separator': ['/'],
      'year': [1991],
      'month': [12],
      'day': [20],
    });
  });

  test('omnimatch', () {
    expect(matching.omnimatch(''), [], reason: "doesn't match ''");
    final password = 'r0sebudmaelstrom11/20/91aaaa';
    final matches = matching.omnimatch(password);

    for (final testCase in [
      [
        'dictionary',
        [0, 6]
      ],
      [
        'dictionary',
        [7, 15]
      ],
      [
        'date',
        [16, 23]
      ],
      [
        'repeat',
        [24, 27]
      ],
    ]) {
      final pattern_name = testCase[0];
      final List<int> ij = testCase[1] as List<int>;
      final i = ij[0];
      final j = ij[1];
      bool included = false;
      for (final match in matches) {
        if (match.i == i && match.j == j && match.pattern == pattern_name) {
          included = true;
        }
      }
      final msg =
          "for ${password}, matches a ${pattern_name} pattern at [${i}, ${j}]";
      expect(included, true, reason: msg);
    }
  });
}
