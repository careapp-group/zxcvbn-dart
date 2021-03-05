import './match.dart';
import './scoring.dart';

class Feedback {
  Feedback({this.warning, this.suggestions});
  String? warning;
  List<String>? suggestions;
}

class feedback {
  static Feedback default_feedback = Feedback()
    ..warning = ''
    ..suggestions = [
      "Use a few words, avoid common phrases"
          "No need for symbols, digits, or uppercase letters"
    ];

  static Feedback get_feedback(score, List<PasswordMatch> sequence) {
    // starting feedback
    if (sequence.length == 0) {
      return default_feedback;
    }

    // no feedback if score is good or great.
    if (score > 2) {
      return Feedback(warning: '', suggestions: []);
    }

    //# tie feedback to the longest match for longer sequences
    PasswordMatch longest_match = sequence[0];
    Feedback feedback = Feedback();
    for (final match in sequence.sublist(1)) {
      if (match.token!.length > longest_match.token!.length) {
        longest_match = match;
      }
    }
    feedback = get_match_feedback(longest_match, sequence.length == 1);
    final extra_feedback =
        'Add another word or two. Uncommon words are better.';
    if (feedback != null) {
      feedback.suggestions!.insert(0, extra_feedback);
      if (feedback.warning == null) {
        feedback.warning = '';
      }
    } else
      feedback = Feedback(
        warning: '',
        suggestions: [extra_feedback],
      );
    return feedback;
  }

  static Feedback get_match_feedback(PasswordMatch match, bool is_sole_match) {
    String? warning;
    switch (match.pattern) {
      case 'dictionary':
        return get_dictionary_match_feedback(match, is_sole_match);

      case 'spatial':
        String layout = match.graph!.toUpperCase();
        if (match.turns == 1) {
          warning = 'Straight rows of keys are easy to guess';
        } else {
          warning = 'Short keyboard patterns are easy to guess';
        }
        return Feedback(
            warning: warning,
            suggestions: ['Use a longer keyboard pattern with more turns']);

      case 'repeat':
        if (match.base_token!.length == 1) {
          warning = 'Repeats like "aaa" are easy to guess';
        } else {
          'Repeats like "abcabcabc" are only slightly harder to guess than "abc"';
        }
        return Feedback(
            warning: warning,
            suggestions: ['Avoid repeated words and characters']);

      case 'sequence':
        return Feedback(
          warning: "Sequences like abc or 6543 are easy to guess",
          suggestions: ['Avoid sequences'],
        );

      case 'regex':
        if (match.regex_name == 'recent_year') {
          return Feedback(
              warning: "Recent years are easy to guess",
              suggestions: [
                'Avoid recent years'
                    'Avoid years that are associated with you'
              ]);
        }
        break;

      case 'date':
        return Feedback(warning: "Dates are often easy to guess", suggestions: [
          'Avoid dates and years that are associated with you'
        ]);
    }
    return default_feedback;
  }

  static Feedback get_dictionary_match_feedback(
      PasswordMatch match, is_sole_match) {
    String? warning;
    if (match.dictionary_name == 'passwords') {
      if (is_sole_match && !match.l33t! && !match.reversed!) {
        if (match.rank <= 10) {
          warning = 'This is a top-10 common password';
        } else if (match.rank <= 100) {
          warning = 'This is a top-100 common password';
        } else {
          warning = 'This is a very common password';
        }
      } else if (match.guesses_log10! <= 4) {
        warning = 'This is similar to a commonly used password';
      }
    } else if (match.dictionary_name == 'english_wikipedia') {
      if (is_sole_match) {
        warning = 'A word by itself is easy to guess';
      }
    } else if (['surnames', 'male_names', 'female_names']
        .contains(match.dictionary_name)) {
      if (is_sole_match) {
        warning = 'Names and surnames by themselves are easy to guess';
      } else {
        warning = 'Common names and surnames are easy to guess';
      }
    } else {
      warning = '';
    }

    final suggestions = <String>[];
    final word = match.token!;
    if (scoring.START_UPPER.hasMatch(word)) {
      suggestions.add("Capitalization doesn't help very much");
    } else if (scoring.ALL_UPPER.hasMatch(word) && word.toLowerCase() != word) {
      suggestions
          .add("All-uppercase is almost as easy to guess as all-lowercase");
    }

    if (match.reversed! && match.token!.length >= 4) {
      suggestions.add("Reversed words aren't much harder to guess");
    }
    if (match.l33t!) {
      suggestions.add(
          "Predictable substitutions like '@' instead of 'a' don't help very much");
    }

    return Feedback(
      warning: warning,
      suggestions: suggestions,
    );
  }
}
