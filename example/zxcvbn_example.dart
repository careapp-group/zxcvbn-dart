import 'package:zxcvbn/zxcvbn.dart';

void main() {
  final zxcvbn = Zxcvbn();

  final result = zxcvbn.evaluate('P@ssw0rd');

  print('Password: ${result.password}');
  print('Score: ${result.score}');
  print(result.feedback.warning);
  for (final suggestion in result.feedback.suggestions!) {
    print(suggestion);
  }
}
