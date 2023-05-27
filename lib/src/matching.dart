import 'adjacency_graphs.dart';
import 'frequency_lists.dart';
import 'match.dart';
import 'scoring.dart';

Map<String, int> build_ranked_dict(List<String> ordered_list) {
  final Map<String, int> result = {};
  int i = 1; // // rank starts at 1, not 0
  for (String word in ordered_list) {
    result[word] = i;
    i += 1;
  }
  return result;
}

final RANKED_DICTIONARIES = frequency_lists.map(
  (key, value) => MapEntry<String, Map<String, int>>(
    key,
    build_ranked_dict(value),
  ),
);

final GRAPHS = {
  'qwerty': adjacency_graphs['qwerty'],
  'dvorak': adjacency_graphs['dvorak'],
  'keypad': adjacency_graphs['keypad'],
  'mac_keypad': adjacency_graphs['mac_keypad'],
};

const L33T_TABLE = {
  'a': ['4', '@'],
  'b': ['8'],
  'c': ['(', '{', '[', '<'],
  'e': ['3'],
  'g': ['6', '9'],
  'i': ['1', '!', '|'],
  'l': ['1', '|', '7'],
  'o': ['0'],
  's': ['\$', '5'],
  't': ['+', '7'],
  'x': ['%'],
  'z': ['2'],
};

Map<String, RegExp> REGEXEN = {
  'recent_year': RegExp(r'19\d\d|200\d|201\d'),
};

const DATE_MAX_YEAR = 2050;
const DATE_MIN_YEAR = 1000;
const DATE_SPLITS = {
  4: [
    // // for length-4 strings, eg 1191 or 9111, two ways to split:
    [1, 2], // // 1 1 91 (2nd split starts at index 1, 3rd at index 2)
    [2, 3], // // 91 1 1
  ],
  5: [
    [1, 3], //// 1 11 91
    [2, 3], //// 11 1 91
  ],
  6: [
    [1, 2], //// 1 1 1991
    [2, 4], //// 11 11 91
    [4, 5], //// 1991 1 1
  ],
  7: [
    [1, 3], // // 1 11 1991
    [2, 3], // // 11 1 1991
    [4, 5], // // 1991 1 11
    [4, 6], // // 1991 11 1
  ],
  8: [
    [2, 4], // // 11 11 1991
    [4, 6], // // 1991 11 11
  ]
};

class matching {
  static empty(dynamic obj) => obj.isEmpty;
  static void extend(List lst, List lst2) => lst.addAll(lst2);

  static translate(String string, Map<String, String> chr_map) =>
      string.split('').map((chr) => chr_map[chr] ?? chr).join('');
  static mod(n, m) =>
      ((n % m) + m) % m; // mod impl that works for negative numbers

  static List<PasswordMatch> sorted(List<PasswordMatch> matches) {
    // // sort on i primary, j secondary
    matches
        .sort((m1, m2) => (m1.i! - m2.i!) != 0 ? (m1.i! - m2.i!) : (m1.j! - m2.j!));
    return matches;
  }

//  // ------------------------------------------------------------------------------
//  // omnimatch -- combine everything ----------------------------------------------
//  // ------------------------------------------------------------------------------
//
  static omnimatch(String? password) {
    List<PasswordMatch> matches = [];
    final matchers = [
      dictionary_match,
      reverse_dictionary_match,
      l33t_match,
      spatial_match,
      repeat_match,
      sequence_match,
      regex_match,
      date_match
    ];
    for (Function matcher in matchers) {
      matches = [...matches, ...matcher.call(password)];
    }
    return sorted(matches);
  }

  //-------------------------------------------------------------------------------
  // dictionary match (common passwords, english, last names, etc) ----------------
  //-------------------------------------------------------------------------------

  static List<PasswordMatch> dictionary_match(String password,
      {Map<String, Map<String, int>>? ranked_dictionaries}) {
    ranked_dictionaries ??= RANKED_DICTIONARIES;
    // _ranked_dictionaries variable is for unit testing purposes
    final List<PasswordMatch> matches = [];
    int len = password.length;
    final password_lower = password.toLowerCase();
    ranked_dictionaries.forEach((dictionary_name, ranked_dict) {
      for (int i = 0; i < len; i++) {
        for (int j = i; j < len; j++) {
          if (ranked_dict.containsKey(password_lower.substring(i, j + 1))) {
            final word = password_lower.substring(i, j + 1);
            final rank = ranked_dict[word];

            matches.add(
              PasswordMatch()
                ..pattern = 'dictionary'
                ..i = i
                ..j = j
                ..token = password.substring(i, j + 1)
                ..matched_word = word
                ..rank = rank
                ..dictionary_name = dictionary_name
                ..reversed = false
                ..l33t = false,
            );
          }
        }
      }
    });
    return sorted(matches);
  }

  static reverse_dictionary_match(
    String password, {
    Map<String, Map<String, int>>? ranked_dictionaries,
  }) {
    ranked_dictionaries ??= RANKED_DICTIONARIES;
    final reversed_password = password.split('').reversed.join('');
    final matches = dictionary_match(reversed_password,
        ranked_dictionaries: ranked_dictionaries);
    for (PasswordMatch match in matches) {
      match.token = match.token!.split('').reversed.join(''); //// reverse back
      match.reversed = true;
      //// map coordinates back to original string
      int tempI = password.length - 1 - match.j!;
      match.j = password.length - 1 - match.i!;
      match.i = tempI;
    }
    return sorted(matches);
  }

  static set_user_input_dictionary(List<String> ordered_list) {
    RANKED_DICTIONARIES['user_inputs'] = build_ranked_dict([...ordered_list]);
  }

  //-------------------------------------------------------------------------------
  // dictionary match with common l33t substitutions ------------------------------
  //-------------------------------------------------------------------------------

  // makes a pruned copy of l33t_table that only includes password's possible substitutions
  static Map<String, List<String>> relevant_l33t_subtable(
      String password, Map<String, List<String>> table) {
    final Map<String, bool> password_chars = {};
    for (final chr in password.split('')) {
      password_chars[chr] = true;
    }
    final Map<String, List<String>> subtable = {};
    table.forEach((letter, subs) {
      final relevant_subs =
          subs.where((sub) => password_chars.containsKey(sub));
      if (relevant_subs.length > 0) {
        subtable[letter] = relevant_subs.toList();
      }
    });
    return subtable;
  }

  /// not supported in dart
  /// in javascript, it compares the first element, if null put it at the end, if empty at the beginning
  /// it handles list recursively
  ///
  /// [[2, 3], [1, 2], null, [], 1, 3] => [[], 1, [1, 2], [2, 3], 3, null]
  /// @return the list itself
  static List<List> sortListOfList(List<List> lists) {
    int compareValue(v1, v2) {
      try {
        if (v1 == null) {
          if (v2 == null) {
            return 0;
          }
          return 1;
        } else if (v2 == null) {
          return -1;
        }
        if (v1 is String) return v1.compareTo(v2 as String);
        if (v1 is num) return v1.compareTo(v2 as num);
      } catch (e) {
        // Ignore
      }
      return 0;
    }

    //
    int compare(List l1, List l2) {
      // null at the end
      if (l1 == null) {
        if (l2 == null) {
          return 0;
        }
        return 1;
      } else if (l2 == null) {
        return -1;
      }

      // convert to list
      if (l1 is! List) {
        l1 = [l1];
      }
      if (l2 is! List) {
        l2 = [l2];
      }

      // empty at the beginning
      if (l1.isEmpty) {
        if (l2.isEmpty) {
          return 0;
        }
        return -1;
      } else if (l2.isEmpty) {
        return 1;
      }

      if (l1[0] is List) {
        return compare(l1[0] as List, l2[0] as List);
      }

      int result = 0;
      for (int i = 0; i < l1.length; i++) {
        // l1 bigger so exit
        if (i >= l2.length) {
          return 1;
        } else {
          result = compareValue(l1[i], l2[i]);
          if (result != 0) {
            break;
          }
        }
      }
      if (result == 0 && l2.length > l1.length) {
        return -1;
      }

      return result;
    }

    lists.sort(compare);
    return lists;
  }

  static List<List<List<String>>> dedup(List<List<List<String>>> subs) {
    List<List<List<String>>> deduped = [];

    final members = {};
    for (final sub in subs) {
      final assoc = <List>[];
      for (int v = 0; v < sub.length; v++) {
        var k = sub[v];
        assoc.add([k, v]);
      }
      sortListOfList(assoc);

      final label = assoc.map((kv) => '${kv[0]},${kv[1]}').join('-');

      if (!members.containsKey(label)) {
        members[label] = true;
        deduped.add(sub);
      }
    }
    return deduped;
  }

  // returns the list of possible 1337 replacement dictionaries for a given password
  static List<Map<String, String>> enumerate_l33t_subs(
    Map<String, List<String>> table,
  ) {
    final keys = table.keys.toList();
    List<List<List<String>>> subs = [[]];

    helper(List<String> keys) {
      if (keys.isEmpty) {
        return;
      }
      final String first_key = keys[0];
      List<String> rest_keys = keys.sublist(1);
      final next_subs = <List<List<String>>>[];

      for (final l33t_chr in table[first_key]!) {
        for (final sub in subs) {
          int dup_l33t_index = -1;
          for (int i = 0; i < sub.length; i++) {
            if (sub[i][0] == l33t_chr) {
              dup_l33t_index = i;
              break;
            }
          }
          if (dup_l33t_index == -1) {
            var sub_extension = new List<List<String>>.from(sub);
            sub_extension.addAll([
              [l33t_chr, first_key]
            ]);

            next_subs.add(sub_extension);
          } else {
            final sub_alternative = [...sub];
            sub_alternative.removeRange(dup_l33t_index, dup_l33t_index + 1);
            sub_alternative.add([l33t_chr, first_key]);
            next_subs.add(sub);
            next_subs.add(sub_alternative);
          }
        }
      }
      subs = dedup(next_subs);
      helper(rest_keys);
    }

    helper(keys);

    final sub_dicts =
        <Map<String, String>>[]; // // convert from assoc lists to dicts

    for (final sub in subs) {
      final sub_dict = <String, String>{};
      sub.forEach((List data) {
        String l33tChr = data[0];
        String chr = data[1];
        sub_dict[l33tChr] = chr;
      });
      ;
      sub_dicts.add(sub_dict);
    }
    return sub_dicts;
  }

  static List<PasswordMatch> l33t_match(String password,
      {ranked_dictionaries, l33t_table}) {
    ranked_dictionaries ??= RANKED_DICTIONARIES;
    l33t_table ??= L33T_TABLE;

    final matches = <PasswordMatch>[];

    for (final sub
        in enumerate_l33t_subs(relevant_l33t_subtable(password, l33t_table))) {
      if (empty(sub)) {
        // corner case: password has no relevant subs.
        break;
      }

      final subbed_password = translate(password, sub);
      for (final PasswordMatch match in dictionary_match(subbed_password,
          ranked_dictionaries: ranked_dictionaries)) {
        final String token = password.substring(match.i!, match.j! + 1);
        if (token.toLowerCase() == match.matched_word) {
          continue; // only return the matches that contain an actual substitution
        }

        final match_sub =
            {}; //  subset of mappings in sub that are in use for this match
        sub.forEach((subbed_chr, chr) {
          if (token.indexOf(subbed_chr) != -1) {
            match_sub[subbed_chr] = chr;
          }
        });

        match.l33t = true;
        match.token = token;
        match.sub = match_sub;
        match.sub_display = match_sub
            .map((k, v) => MapEntry(k, "${k} -> ${v}"))
            .values
            .join(', ');
        matches.add(match);
      }
    }

    return sorted(matches
        .where((match) =>
            // filter single-character l33t matches to reduce noise.
            // otherwise '1' matches 'i', '4' matches 'a', both very common English words
            // with low dictionary rank.
            match.token!.length > 1)
        .toList());
  }
  // ------------------------------------------------------------------------------
  // spatial match (qwerty/dvorak/keypad) -----------------------------------------
  // ------------------------------------------------------------------------------

  static List<PasswordMatch> spatial_match(String password,
      [Map<String, Map<String, List<String?>>?>? graphs]) {
    graphs ??= GRAPHS;
    final List<PasswordMatch> matches = [];

    graphs.forEach((graph_name, graph) {
      extend(matches, spatial_match_helper(password, graph, graph_name));
    });
    return (sorted(matches));
  }

  static RegExp SHIFTED_RX =
      RegExp(r'[~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?]');

  static List<PasswordMatch> spatial_match_helper(
      String password, Map<String, List<String?>>? graph, graph_name) {
    final List<PasswordMatch> matches = [];
    int i = 0;
    while (i < password.length - 1) {
      int j = i + 1;
      dynamic last_direction = null;
      int turns = 0;

      int shifted_count;

      if (['qwerty', 'dvorak'].contains(graph_name) &&
          SHIFTED_RX.hasMatch(password[i])) {
        // initial character is shifted
        shifted_count = 1;
      } else {
        shifted_count = 0;
      }
      while (true) {
        String prev_char = password[j - 1];
        bool found = false;
        int found_direction = -1;
        int cur_direction = -1;
        final adjacents = graph![prev_char] ?? [];
        // consider growing pattern by one character if j hasn't gone over the edge.
        if (j < password.length) {
          String cur_char = password[j];
          for (final adj in adjacents) {
            cur_direction += 1;
            if (adj != null && adj.indexOf(cur_char) != -1) {
              found = true;
              found_direction = cur_direction;
              if (adj.indexOf(cur_char) == 1) {
                // index 1 in the adjacency means the key is shifted,
                // 0 means unshifted: A vs a, % vs 5, etc.
                // for example, 'q' is adjacent to the entry '2@'.
                // @ is shifted w/ index 1, 2 is unshifted.
                shifted_count += 1;
              }
              if (last_direction != found_direction) {
                // adding a turn is correct even in the initial case when last_direction is null:
                // every spatial pattern starts with a turn.
                turns += 1;
                last_direction = found_direction;
              }
              break;
            }
          }
        }
        // if the current pattern continued, extend j and try to grow again
        if (found) {
          j += 1;
        }
        // otherwise push the pattern discovered so far, if any...
        else {
          if (j - i > 2) {
            //// don't consider length 1 or 2 chains.
            matches.add(PasswordMatch()
              ..pattern = 'spatial'
              ..i = i
              ..j = j - 1
              ..token = password.substring(i, j)
              ..graph = graph_name
              ..turns = turns
              ..shifted_count = shifted_count);
          }
          // ...and then start a new search for the rest of the password.
          i = j;
          break;
        }
      }
    }
    return matches;
  }

  //-------------------------------------------------------------------------------
  // repeats (aaa, abcabcabc) and sequences (abcdef) ------------------------------
  //-------------------------------------------------------------------------------

  static List<PasswordMatch> repeat_match(String password) {
    List<PasswordMatch> matches = [];
    RegExp greedy = RegExp(r'(.+)\1+');
    RegExp lazy = RegExp(r'(.+?)\1+');
    RegExp lazy_anchored = RegExp(r'^(.+?)\1+$');
    int lastIndex = 0;
    RegExpMatch? match;
    String? base_token;

    while (lastIndex < password.length) {
      String pattern = password.substring(lastIndex);
      final greedy_match = greedy.firstMatch(pattern);
      final lazy_match = lazy.firstMatch(pattern);
      if (greedy_match == null) {
        break;
      }
      final greedyLength = greedy_match.end - greedy_match.start;
      final lazyLength = lazy_match!.end - lazy_match.start;
      if (greedyLength > lazyLength) {
        // greedy beats lazy for 'aabaab'
        //   greedy: [aabaab, aab]
        //   lazy:   [aa,     a]
        match = greedy_match;
        // greedy's repeated string might itself be repeated, eg.
        // aabaab in aabaabaabaab.
        // run an anchored lazy match on greedy's repeated string
        // to find the shortest repeated string
        base_token = lazy_anchored.firstMatch(match.group(0)!)!.group(1);
      } else {
        // lazy beats greedy for 'aaaaa'
        //   greedy: [aaaa,  aa]
        //   lazy:   [aaaaa, a]
        match = lazy_match;
        base_token = match.group(1);
      }
      int i = lastIndex + match.start;
      int j = lastIndex + match.start + match.group(0)!.length - 1;

      // recursively match and score the base string
      final base_analysis = scoring.most_guessable_match_sequence(
          base_token!, omnimatch(base_token));

      final base_matches = base_analysis.sequence;
      final base_guesses = base_analysis.guesses;
      matches.add(PasswordMatch()
        ..pattern = 'repeat'
        ..i = i
        ..j = j
        ..token = match[0]
        ..base_token = base_token
        ..base_guesses = base_guesses.round()
        ..base_matches = base_matches
        ..repeat_count = (match[0]!.length / base_token.length).round());
      lastIndex = j + 1;
    }
    return matches;
  }

  static const MAX_DELTA = 5;
  static List<PasswordMatch> sequence_match(String password) {
    // Identifies sequences by looking for repeated differences in unicode codepoint.
    // this allows skipping, such as 9753, and also matches some extended unicode sequences
    // such as Greek and Cyrillic alphabets.
    //
    // for example, consider the input 'abcdb975zy'
    //
    // password: a   b   c   d   b    9   7   5   z   y
    // index:    0   1   2   3   4    5   6   7   8   9
    // delta:      1   1   1  -2  -41  -2  -2  69   1
    //
    // expected result:
    // [(i, j, delta), ...] = [(0, 3, 1), (5, 7, -2), (8, 9, 1)]

    if (password.length == 1) {
      return <PasswordMatch>[];
    }
    List<PasswordMatch> result = [];
    int i = 0;
    int j;
    int? last_delta = null;

    void update(i, j, num? delta) {
      if (j - i > 1 || (delta?.abs() ?? 0) == 1) {
        if (0 < delta!.abs() && delta.abs() <= MAX_DELTA) {
          String token = password.substring(i, j + 1);

          String sequence_name;
          int sequence_space;

          if (RegExp(r'^[a-z]+$').hasMatch(token)) {
            sequence_name = 'lower';
            sequence_space = 26;
          } else if (RegExp(r'^[A-Z]+$').hasMatch(token)) {
            sequence_name = 'upper';
            sequence_space = 26;
          } else if (RegExp(r'^\d+$').hasMatch(token)) {
            sequence_name = 'digits';
            sequence_space = 10;
          } else {
            // conservatively stick with roman alphabet size.
            // (this could be improved)
            sequence_name = 'unicode';
            sequence_space = 26;
          }
          result.add(PasswordMatch()
            ..pattern = 'sequence'
            ..i = i
            ..j = j
            ..token = password.substring(i, j + 1)
            ..sequence_name = sequence_name
            ..sequence_space = sequence_space
            ..ascending = delta > 0);
        }
      }
    }

    for (int k = 1; k < password.length; k++) {
      int delta = password.codeUnitAt(k) - password.codeUnitAt(k - 1);
      if (last_delta == null) {
        last_delta = delta;
      }
      if (delta == last_delta) {
        continue;
      }

      j = k - 1;
      update(i, j, last_delta);
      i = j;
      last_delta = delta;
    }
    update(i, password.length - 1, last_delta);
    return result;
  }

  //-------------------------------------------------------------------------------
  // regex matching ---------------------------------------------------------------
  //-------------------------------------------------------------------------------

  static List<PasswordMatch> regex_match(String password,
      [Map<String, RegExp>? _regexen]) {
    _regexen ??= REGEXEN;
    final List<PasswordMatch> matches = [];
    _regexen.forEach((name, regex) {
      regex.allMatches(password).forEach((rx_match) {
        String? token = rx_match[0];
        matches.add(PasswordMatch()
          ..pattern = 'regex'
          ..token = token
          ..i = rx_match.start
          ..j = rx_match.start + rx_match[0]!.length - 1
          ..regex_name = name
          ..regex_match = rx_match);
      });
    });
    return sorted(matches);
  }

  //-------------------------------------------------------------------------------
  // date matching ----------------------------------------------------------------
  //-------------------------------------------------------------------------------

  static List<PasswordMatch> date_match(String password) {
    // a "date" is recognized as:
    //   any 3-tuple that starts or ends with a 2- or 4-digit year,
    //   with 2 or 0 separator chars (1.1.91 or 1191),
    //   maybe zero-padded (01-01-91 vs 1-1-91),
    //   a month between 1 and 12,
    //   a day between 1 and 31.
    //
    // note: this isn't true date parsing in that "feb 31st" is allowed,
    // this doesn't check for leap years, etc.
    //
    // recipe:
    // start with regex to find maybe-dates, then attempt to map the integers
    // onto month-day-year to filter the maybe-dates into dates.
    // finally, remove matches that are substrings of other matches to reduce noise.
    //
    // note: instead of using a lazy or greedy regex to find many dates over the full string,
    // this uses a ^...$ regex against every substring of the password -- less performant but leads
    // to every possible date match.
    final List<PasswordMatch> matches = [];
    final RegExp maybe_date_no_separator = RegExp(r'^\d{4,8}$');

    //  ^
    //  ( \d{1,4} )    // day, month, year
    //  ( [\s/\\_.-] ) // separator
    //  ( \d{1,2} )    // day, month
    //  \2             // same separator
    //  ( \d{1,4} )    // day, month, year
    //  \$
    final RegExp maybe_date_with_separator =
        RegExp(r'^(\d{1,4})([\s/\\_.-])(\d{1,2})\2(\d{1,4})$');

    // dates without separators are between length 4 '1191' and 8 '11111991'
    for (int i = 0; i <= password.length - 4; i++) {
      for (int j = i + 3; j <= i + 7; j++) {
        if (j >= password.length) {
          break;
        }
        String token = password.substring(i, j + 1);
        if (!maybe_date_no_separator.hasMatch(token)) {
          continue;
        }
        List candidates = [];
        for (final split in DATE_SPLITS[token.length]!) {
          int k = split[0];
          int l = split[1];
          final dmy = map_ints_to_dmy([
            int.parse(token.substring(0, k)),
            int.parse(token.substring(k, l)),
            int.parse(token.substring(l))
          ]);
          if (dmy != null) {
            candidates.add(dmy);
          }
        }
        if (!(candidates.length > 0)) {
          continue;
        }
        // at this point: different possible dmy mappings for the same i,j substring.
        // match the candidate date that likely takes the fewest guesses: a year closest to 2000.
        // (scoring.REFERENCE_YEAR).
        //
        // ie, considering '111504', prefer 11-15-04 to 1-1-1504
        // (interpreting '04' as 2004)
        var best_candidate = candidates[0];

        Function metric =
            (candidate) => (candidate['year'] - scoring.REFERENCE_YEAR).abs();

        int? min_distance = metric(candidates[0]);
        for (final candidate in candidates.sublist(1)) {
          int distance = metric(candidate);
          if (distance < min_distance!) {
            best_candidate = candidate;
            min_distance = distance;
          }
        }
        matches.add(PasswordMatch()
          ..pattern = 'date'
          ..token = token
          ..i = i
          ..j = j
          ..separator = ''
          ..year = best_candidate['year']
          ..month = best_candidate['month']
          ..day = best_candidate['day']);
      }
    }

    // dates with separators are between length 6 '1/1/91' and 10 '11/11/1991'
    for (int i = 0; i <= password.length - 6; i++) {
      for (int j = i + 5; j <= i + 9; j++) {
        if (j >= password.length) {
          break;
        }
        String token = password.substring(i, j + 1);
        final rx_match = maybe_date_with_separator.firstMatch(token);
        if (rx_match == null) {
          continue;
        }
        final Map<String, int?>? dmy = map_ints_to_dmy([
          int.parse(rx_match[1]!),
          int.parse(rx_match[3]!),
          int.parse(rx_match[4]!),
        ]);
        if (dmy == null) {
          continue;
        }
        matches.add(PasswordMatch()
          ..pattern = 'date'
          ..token = token
          ..i = i
          ..j = j
          ..separator = rx_match[2]
          ..year = dmy['year']
          ..month = dmy['month']
          ..day = dmy['day']);
      }
    }

    // matches now contains all valid date strings in a way that is tricky to capture
    // with regexes only. while thorough, it will contain some unintuitive noise:
    //
    // '2015_06_04', in addition to matching 2015_06_04, will also contain
    // 5(!) other date matches: 15_06_04, 5_06_04, ..., even 2015 (matched as 5/1/2020)
    //
    // to reduce noise, remove date matches that are strict substrings of others
    return sorted(matches.where((match) {
      bool is_submatch = false;
      for (final other_match in matches) {
        if (match == other_match) {
          continue;
        }
        if (other_match.i! <= match.i! && other_match.j! >= match.j!) {
          is_submatch = true;
          break;
        }
      }
      return !is_submatch;
    }).toList());
  }

  static Map<String, int?>? map_ints_to_dmy(List<int> ints) {
    // given a 3-tuple, discard if:
    //   middle int is over 31 (for all dmy formats, years are never allowed in the middle)
    //   middle int is zero
    //   any int is over the max allowable year
    //   any int is over two digits but under the min allowable year
    //   2 ints are over 31, the max allowable day
    //   2 ints are zero
    //   all ints are over 12, the max allowable month
    if (ints[1] > 31 || ints[1] <= 0) {
      return null;
    }
    int over_12 = 0;
    int over_31 = 0;
    int under_1 = 0;
    for (int i in ints) {
      if ((99 < i && i < DATE_MIN_YEAR) || i > DATE_MAX_YEAR) {
        return null;
      }
      if (i > 31) {
        over_31 += 1;
      }
      if (i > 12) {
        over_12 += 1;
      }
      if (i <= 0) {
        under_1 += 1;
      }
    }
    if (over_31 >= 2 || over_12 == 3 || under_1 >= 2) {
      return null;
    }

    // first look for a four digit year: yyyy + daymonth or daymonth + yyyy
    final possible_year_splits = [
      [ints[2], ints.sublist(0, 1 + 1)], // year last
      [ints[0], ints.sublist(0, 2 + 1)] // year first
    ];

    for (final split in possible_year_splits) {
      int y = split[0] as int;
      final rest = split[1];
      if (DATE_MIN_YEAR <= y && y <= DATE_MAX_YEAR) {
        final dm = map_ints_to_dm(rest as List<int>);
        if (dm != null) {
          return {
            'year': y,
            'month': dm['month'],
            'day': dm['day'],
          };
        } else
          // for a candidate that includes a four-digit year,
          // when the remaining ints don't match to a day and month,
          // it is not a date.
          return null;
      }
    }

    // given no four-digit year, two digit years are the most flexible int to match, so
    // try to parse a day-month out of ints[0..1] or ints[1..0]
    for (final split in possible_year_splits) {
      int y = split[0] as int;
      final rest = split[1];
      final dm = map_ints_to_dm(rest as List<int>);
      if (dm != null) {
        y = two_to_four_digit_year(y);
        return {
          'year': y,
          'month': dm['month'],
          'day': dm['day'],
        };
      } else {
        return null;
      }
    }
  }

  static Map<String, int>? map_ints_to_dm(List<int> ints) {
    for (List row in [ints, ints.reversed.toList()]) {
      int d = row[0];
      int m = row[1];
      if (1 <= d && d <= 31 && 1 <= m && m <= 12) {
        return {'day': d, 'month': m};
      }
    }
    return null;
  }

  static int two_to_four_digit_year(int year) {
    if (year > 99) {
      return year;
    } else if (year > 50)
      // 87 -> 1987
      return year + 1900;
    else
      // 15 -> 2015
      return year + 2000;
  }
}
