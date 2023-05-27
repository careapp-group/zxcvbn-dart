import 'dart:math' as Math;
import 'adjacency_graphs.dart';
import 'match.dart';
import 'result.dart';

//# on qwerty, 'g' has degree 6, being adjacent to 'ftyhbv'. '\' has degree 1.
//# this calculates the average over all keys.
double calc_average_degree(Map<String, List<String?>> graph) {
  num average;
  var k, key, n;
  List? neighbors;
  average = 0;
  for (key in graph.keys) {
    neighbors = graph[key];
    average += () {
      int l, len;
      final results = [];
      len = neighbors!.length;
      for (l = 0; l < len; l++) {
        n = neighbors[l];
        if (n != null) {
          results.add(n);
        }
      }
      return results;
    }()
        .length;
  }
  average /= () {
    final results = [];
    for (k in graph.keys) {
      //v = graph[k];
      results.add(k);
    }
    return results;
  }()
      .length;
  return average as double;
}

const BRUTEFORCE_CARDINALITY = 10.0;
const MIN_GUESSES_BEFORE_GROWING_SEQUENCE = 10000.0;
const MIN_SUBMATCH_GUESSES_SINGLE_CHAR = 10.0;
const MIN_SUBMATCH_GUESSES_MULTI_CHAR = 50.0;

class scoring {
  static double nCk(num n, num k) {
    // http://blog.plover.com/math/choose.html
    if (k > n) {
      return 0;
    }
    if (k == 0) {
      return 1;
    }
    double r = 1;
    for (int d = 1; d <= k; d++) {
      r *= n;
      r /= d;
      n -= 1;
    }
    return r;
  }

  static double log10(double n) => Math.log(n) / Math.log(10);
  static double log2(double n) => Math.log(n) / Math.log(2);

  static double factorial(double n) {
    // unoptimized, called only on small n
    if (n < 2) {
      return 1;
    }
    double f = 1;
    for (int i = 2; i <= n; i++) {
      f *= i;
    }
    return f;
  }

  // ------------------------------------------------------------------------------
  // search --- most guessable match sequence -------------------------------------
  // ------------------------------------------------------------------------------
  //
  // takes a sequence of overlapping matches, returns the non-overlapping sequence with
  // minimum guesses. the following is a O(l_max * (n + m)) dynamic programming algorithm
  // for a length-n password with m candidate matches. l_max is the maximum optimal
  // sequence length spanning each prefix of the password. In practice it rarely exceeds 5 and the
  // search terminates rapidly.
  //
  // the optimal "minimum guesses" sequence is here defined to be the sequence that
  // minimizes the following function:
  //
  //    g = l! * Product(m.guesses for m in sequence) + D^(l - 1)
  //
  // where l is the length of the sequence.
  //
  // the factorial term is the number of ways to order l patterns.
  //
  // the D^(l-1) term is another length penalty, roughly capturing the idea that an
  // attacker will try lower-length sequences first before trying length-l sequences.
  //
  // for example, consider a sequence that is date-repeat-dictionary.
  //  - an attacker would need to try other date-repeat-dictionary combinations,
  //    hence the product term.
  //  - an attacker would need to try repeat-date-dictionary, dictionary-repeat-date,
  //    ..., hence the factorial term.
  //  - an attacker would also likely try length-1 (dictionary) and length-2 (dictionary-date)
  //    sequences before length-3. assuming at minimum D guesses per pattern type,
  //    D^(l-1) approximates Sum(D^i for i in [1..l-1]
  //
  // ------------------------------------------------------------------------------

  static Result most_guessable_match_sequence(
      String password, List<PasswordMatch> matches,
      {exclude_additive = false}) {
    final n = password.length;

    // partition matches into sublists according to ending index j
    final matches_by_j = List<List<PasswordMatch>>.generate(n, (index) => []);

    for (final m in matches) {
      matches_by_j[m.j!].add(m);
    }
    // small detail: for deterministic output, sort each sublist by i.
    for (final lst in matches_by_j) {
      lst.sort((m1, m2) => m1.i! - m2.i!);
    }

    final optimal = {
      // optimal.m[k][l] holds final match in the best length-l match sequence covering the
      // password prefix up to k, inclusive.
      // if there is no length-l sequence that scores better (fewer guesses) than
      // a shorter match sequence spanning the same prefix, optimal.m[k][l] is undefined.
      'm': List.generate(n, (index) => {}),
      // same structure as optimal.m -- holds the product term Prod(m.guesses for m in sequence).
      // optimal.pi allows for fast (non-looping) updates to the minimization function.
      'pi': List.generate(n, (index) => {}),
      // same structure as optimal.m -- holds the overall metric.
      'g': List.generate(n, (index) => {}),
    };

    // helper: considers whether a length-l sequence ending at match m is better (fewer guesses)
    // than previously encountered sequences, updating state if so.
    final update = (PasswordMatch m, double? l) {
      final k = m.j!;
      double pi = estimate_guesses(m, password)!.toDouble();
      if (l! > 1) {
        // we're considering a length-l sequence ending with match m:
        // obtain the product term in the minimization function by multiplying m's guesses
        // by the product of the length-(l-1) sequence ending just before m, at m.i - 1.
        pi *= optimal['pi']![m.i! - 1][l - 1];
      }
      // calculate the minimization func
      double g = factorial(l) * pi;
      if (!exclude_additive) {
        g += Math.pow(MIN_GUESSES_BEFORE_GROWING_SEQUENCE, l - 1);
      }
      // update state if new best.
      // first see if any competing sequences covering this prefix, with l or fewer matches,
      // fare better than this sequence. if so, skip it and return.
      final _ref = optimal['g']![k];
      for (final competing_l in _ref.keys) {
        final competing_g = _ref[competing_l];
        if (competing_l > l) {
          continue;
        }
        if (competing_g <= g) {
          return;
        }
      }

      // this sequence might be part of the final optimal sequence.
      optimal['g']![k][l] = g;
      optimal['m']![k][l] = m;
      optimal['pi']![k][l] = pi;
    };

    // helper: make bruteforce match objects spanning i to j, inclusive.
    final make_bruteforce_match = (int i, int j) => PasswordMatch()
      ..pattern = 'bruteforce'
      ..token = password.substring(i, j + 1)
      ..i = i
      ..j = j;

    // helper: evaluate bruteforce matches ending at k.
    final bruteforce_update = (k) {
      // see if a single bruteforce match spanning the k-prefix is optimal.
      final m = make_bruteforce_match(0, k);
      update(m, 1);
      for (int i = 1; i <= k; i++) {
        // generate k bruteforce matches, spanning from (i=1, j=k) up to (i=k, j=k).
        // see if adding these new matches to any of the sequences in optimal[i-1]
        // leads to new bests.
        final m = make_bruteforce_match(i, k);
        for (var l in optimal['m']![i - 1].keys) {
          final PasswordMatch last_m = optimal['m']![i - 1][l];
          // corner: an optimal sequence will never have two adjacent bruteforce matches.
          // it is strictly better to have a single bruteforce match spanning the same region:
          // same contribution to the guess product with a lower length.
          // --> safe to skip those cases.
          if (last_m.pattern == 'bruteforce') {
            continue;
          }
          // try adding m to this length-l sequence.
          update(m, l + 1);
        }
      }
    };
    // helper: step backwards through optimal.m starting at the end,
    // constructing the final optimal match sequence.
    final unwind = (n) {
      final List<PasswordMatch> optimal_match_sequence = [];
      var k = n - 1;
      // find the final best sequence length and score
      dynamic l = null;
      double g = double.infinity;
      if (k >= 0) {
        optimal['g']![k].forEach((candidate_l, candidate_g) {
          if (candidate_g < g) {
            l = candidate_l;
            g = candidate_g;
          }
        });
      }

      while (k >= 0) {
        var m = optimal['m']![k][l];
        optimal_match_sequence.insert(0, m);
        k = m.i - 1;
        l--;
      }
      return optimal_match_sequence;
    };

    for (int k = 0; k < n; k++) {
      for (final m in matches_by_j[k]) {
        if (m.i! > 0) {
          for (var l in optimal['m']![m.i! - 1].keys) {
            update(m, l + 1);
          }
        } else {
          update(m, 1);
        }
      }
      bruteforce_update(k);
    }
    final optimal_match_sequence = unwind(n);
    final optimal_l = optimal_match_sequence.length;

    // corner: empty password
    double? guesses;
    if (password.length == 0) {
      guesses = 1;
    } else {
      guesses = optimal['g']![n - 1][optimal_l];
    }

    // final result object
    return Result()
      ..password = password
      ..guesses = guesses!.round()
      ..guesses_log10 = log10(guesses)
      ..sequence = optimal_match_sequence;
  }

  // ------------------------------------------------------------------------------
  // guess estimation -- one function per match pattern ---------------------------
  // ------------------------------------------------------------------------------
  static double? estimate_guesses(PasswordMatch match, String password) {
    // a match's guess estimate doesn't change. cache it.
    if (match.guesses != null) {
      return match.guesses;
    }
    double min_guesses = 1;
    if (match.token!.length < password.length) {
      if (match.token!.length == 1) {
        min_guesses = MIN_SUBMATCH_GUESSES_SINGLE_CHAR;
      } else {
        min_guesses = MIN_SUBMATCH_GUESSES_MULTI_CHAR;
      }
    }
    final estimation_functions = {
      'bruteforce': bruteforce_guesses,
      'dictionary': dictionary_guesses,
      'spatial': spatial_guesses,
      'repeat': repeat_guesses,
      'sequence': sequence_guesses,
      'regex': regex_guesses,
      'date': date_guesses,
    };
    final double guesses = estimation_functions[match.pattern!]!.call(match)!;
    match.guesses = Math.max<double>(guesses, min_guesses);
    match.guesses_log10 = log10(match.guesses!);
    return match.guesses;
  }

  static double bruteforce_guesses(PasswordMatch match) {
    double guesses = Math.pow(BRUTEFORCE_CARDINALITY, match.token!.length) as double;
    // small detail: make bruteforce matches at minimum one guess bigger than smallest allowed
    // submatch guesses, such that non-bruteforce submatches over the same [i..j] take precedence.
    double min_guesses;
    if (match.token!.length == 1) {
      min_guesses = MIN_SUBMATCH_GUESSES_SINGLE_CHAR + 1;
    } else {
      min_guesses = MIN_SUBMATCH_GUESSES_MULTI_CHAR + 1;
    }
    return Math.max<double>(guesses, min_guesses);
  }

  static double repeat_guesses(PasswordMatch match) {
    return 1.0 * match.base_guesses! * match.repeat_count!;
  }

  static double sequence_guesses(PasswordMatch match) {
    final first_chr = match.token![0];
    double base_guesses;
    // lower guesses for obvious starting points
    if (['a', 'A', 'z', 'Z', '0', '1', '9'].contains(first_chr)) {
      base_guesses = 4;
    } else {
      RegExp digit = RegExp(r'\d');
      if (digit.hasMatch(first_chr)) {
        base_guesses = 10; // digits
      } else {
        // could give a higher base for uppercase,
        // assigning 26 to both upper and lower sequences is more conservative.
        base_guesses = 26;
      }
    }
    if (!match.ascending!) {
      // need to try a descending sequence in addition to every ascending sequence ->
      // 2x guesses
      base_guesses *= 2;
    }
    return base_guesses * match.token!.length;
  }

  static final MIN_YEAR_SPACE = 20;
  static final REFERENCE_YEAR = DateTime.now().year;

  static double? regex_guesses(PasswordMatch match) {
    final char_class_bases = {
      'alpha_lower': 26,
      'alpha_upper': 26,
      'alpha': 52,
      'alphanumeric': 62,
      'digits': 10,
      'symbols': 33,
    };
    if (char_class_bases[match.regex_name!] != null) {
      return Math.pow(char_class_bases[match.regex_name!]!, match.token!.length)
          .toDouble();
    } else {
      switch (match.regex_name) {
        case 'recent_year':
          // conservative estimate of year space: num years from REFERENCE_YEAR.
          // if year is close to REFERENCE_YEAR, estimate a year space of MIN_YEAR_SPACE.
          int year_space =
              (int.parse(match.regex_match[0]) - REFERENCE_YEAR).abs();
          year_space = Math.max(year_space, MIN_YEAR_SPACE);
          return 1.0 * year_space;
      }
    }
    return null;
  }

  static double date_guesses(PasswordMatch match) {
    // base guesses: (year distance from REFERENCE_YEAR) * num_days * num_years
    final year_space =
        Math.max<int>((match.year! - REFERENCE_YEAR).abs(), MIN_YEAR_SPACE);
    double guesses = year_space * 365.0;
    // add factor of 4 for separator selection (one of ~4 choices)
    if (match.separator != null && match.separator!.isNotEmpty) {
      guesses *= 4;
    }
    return guesses;
  }

  static final KEYBOARD_AVERAGE_DEGREE =
      calc_average_degree(adjacency_graphs['qwerty']!);
  // slightly different for keypad/mac keypad, but close enough
  static final KEYPAD_AVERAGE_DEGREE =
      calc_average_degree(adjacency_graphs['keypad']!);

  static final KEYBOARD_STARTING_POSITIONS =
      adjacency_graphs['qwerty']!.keys.length;
  static final KEYPAD_STARTING_POSITIONS =
      adjacency_graphs['keypad']!.keys.length;

  static double spatial_guesses(PasswordMatch match) {
    int s;
    double d;
    if (['qwerty', 'dvorak'].contains(match.graph)) {
      s = KEYBOARD_STARTING_POSITIONS;
      d = KEYBOARD_AVERAGE_DEGREE;
    } else {
      s = KEYPAD_STARTING_POSITIONS;
      d = KEYPAD_AVERAGE_DEGREE;
    }
    double guesses = 0;
    int L = match.token!.length;
    int? t = match.turns;
    int possible_turns;
    // estimate the number of possible patterns w/ length L or less with t turns or less.
    for (int i = 2; i <= L; i++) {
      possible_turns = Math.min(t!, i - 1);
      for (int j = 1; j <= possible_turns; j++) {
        guesses += nCk(i - 1, j - 1) * s * Math.pow(d, j);
      }
    }
    // add extra guesses for shifted keys. (% instead of 5, A instead of a.)
    // math is similar to extra guesses of l33t substitutions in dictionary matches.
    if (match.shifted_count != null && match.shifted_count! > 0) {
      var S = match.shifted_count;
      var U = match.token!.length - match.shifted_count!; // # unshifted count
      if (S == 0 || U == 0) {
        guesses *= 2;
      } else {
        int shifted_variations = 0;
        for (int i = 1; i <= Math.min(S!, U); i++) {
          shifted_variations += nCk(S + U, i).round();
        }
        guesses *= shifted_variations;
      }
    }
    return guesses;
  }

  static double dictionary_guesses(PasswordMatch match) {
    match.base_guesses =
        match.rank; //# keep these as properties for display purposes
    match.uppercase_variations = uppercase_variations(match).round();
    match.l33t_variations = l33t_variations(match);
    var reversed_variations = (match.reversed ?? false) ? 2 : 1;
    return 1.0 *
        match.base_guesses! *
        match.uppercase_variations! *
        match.l33t_variations! *
        reversed_variations;
  }

  static final RegExp START_UPPER = RegExp(r'^[A-Z][^A-Z]+$');
  static final RegExp END_UPPER = RegExp(r'^[^A-Z]+[A-Z]$');
  static final RegExp ALL_UPPER = RegExp(r'^[^a-z]+$');
  static final RegExp ALL_LOWER = RegExp(r'^[^A-Z]+$');

  static num uppercase_variations(PasswordMatch match) {
    final word = match.token!;
    if (ALL_LOWER.hasMatch(word) || word.toLowerCase() == word) {
      return 1;
    }
    //  a capitalized word is the most common capitalization scheme,
    //  so it only doubles the search space (uncapitalized + capitalized).
    //  allcaps and end-capitalized are common enough too, underestimate as 2x factor to be safe.
    for (final regex in [START_UPPER, END_UPPER, ALL_UPPER]) {
      if (regex.hasMatch(word)) {
        return 2;
      }
    }
    // otherwise calculate the number of ways to capitalize U+L uppercase+lowercase letters
    // with U uppercase letters or less. or, if there's more uppercase than lower (for eg. PASSwORD),
    // the number of ways to lowercase U+L letters with L lowercase letters or less.
    final U = word
        .split('')
        .where((element) => RegExp(r'[A-Z]').hasMatch(element))
        .length;
    final L = word
        .split('')
        .where((element) => RegExp(r'[a-z]').hasMatch(element))
        .length;
    num variations = 0;
    for (int i = 1; i <= Math.min(U, L); i++) {
      variations += nCk(U + L, i);
    }
    return variations;
  }

  static int l33t_variations(PasswordMatch match) {
    if (!(match.l33t ?? false)) {
      return 1;
    }
    int variations = 1;
    match.sub!.forEach((subbed, unsubbed) {
      // lower-case match.token before calculating: capitalization shouldn't affect l33t calc.
      final chrs = match.token!.toLowerCase().split('');
      final S =
          chrs.where((chr) => chr == subbed).length; // num of subbed chars
      final U =
          chrs.where((chr) => chr == unsubbed).length; // num of unsubbed chars
      if (S == 0 || U == 0) {
        // for this sub, password is either fully subbed (444) or fully unsubbed (aaa)
        // treat that as doubling the space (attacker needs to try fully subbed chars in addition to
        // unsubbed.)
        variations *= 2;
      } else {
        // this case is similar to capitalization:
        // with aa44a, U = 3, S = 2, attacker needs to try unsubbed + one sub + two subs
        final p = Math.min(U, S);
        int possibilities = 0;
        for (int i = 1; i <= p; i++) {
          possibilities += nCk(U + S, i).round();
        }
        variations *= possibilities;
      }
    });
    return variations;
  }
}
