import 'package:zxcvbn/src/match.dart';
import 'package:zxcvbn/src/result.dart';

import './src/feedback.dart';
import './src/matching.dart';
import './src/scoring.dart';
import './src/time_estimates.dart';

export 'package:zxcvbn/src/result.dart';

class Zxcvbn {
  Result evaluate(String password, {List<String> userInputs = const []}) {
    final start = _time;
    List<String> sanitized_inputs =
        userInputs.map((input) => input.toLowerCase()).toList();

    matching.set_user_input_dictionary(sanitized_inputs);
    final List<PasswordMatch> matches = matching.omnimatch(password);
    final Result result =
        scoring.most_guessable_match_sequence(password, matches);
    result.calc_time = _time - start;

    final attack_times = time_estimates.estimate_attack_times(result.guesses);
    attack_times.forEach((prop, val) {
      result[prop] = val;
    });
    result.feedback = feedback.get_feedback(result.score, result.sequence);
    return result;
  }

  int get _time => DateTime.now().millisecondsSinceEpoch;
}
