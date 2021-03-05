class time_estimates {
  static Map<String, dynamic> estimate_attack_times(int guesses) {
    final crack_times_seconds = {
      'online_throttling_100_per_hour': guesses / (100 / 3600),
      'online_no_throttling_10_per_second': guesses / 10,
      'offline_slow_hashing_1e4_per_second': guesses / 1e4,
      'offline_fast_hashing_1e10_per_second': guesses / 1e10
    };
    final crack_times_display = <String, String>{};
    for (final scenario in crack_times_seconds.keys) {
      final seconds = crack_times_seconds[scenario]!;
      crack_times_display[scenario] = display_time(seconds);
    }
    return {
      'crack_times_seconds': crack_times_seconds,
      'crack_times_display': crack_times_display,
      'score': guesses_to_score(guesses)
    };
  }

  static double guesses_to_score(int guesses) {
    final DELTA = 5;
    if (guesses < 1e3 + DELTA) {
      return 0;
    } else if (guesses < 1e6 + DELTA) {
      return 1;
    } else if (guesses < 1e8 + DELTA) {
      return 2;
    } else if (guesses < 1e10 + DELTA) {
      return 3;
    } else {
      return 4;
    }
  }

  static String display_time(double seconds) {
    int base;
    int? display_num;
    String display_str;
    const minute = 60;
    const hour = minute * 60;
    const day = hour * 24;
    const month = day * 31;
    const year = month * 12;
    const century = year * 100;

    if (seconds < 1) {
      display_str = 'less than a second';
    } else if (seconds < minute) {
      base = seconds.round();
      display_num = base;
      display_str = "$base seconds";
    } else if (seconds < hour) {
      base = (seconds / minute).round();
      display_num = base;
      display_str = "$base minute";
    } else if (seconds < day) {
      base = (seconds / hour).round();
      display_num = base;
      display_str = "$base hour";
    } else if (seconds < month) {
      base = (seconds / day).round();
      display_num = base;
      display_str = "$base day";
    } else if (seconds < year) {
      base = (seconds / month).round();
      display_num = base;
      display_str = "$base month";
    } else if (seconds < century) {
      base = (seconds / year).round();
      display_num = base;
      display_str = "$base year";
    } else {
      display_str = 'centuries';
    }

    if (display_num != null && display_num != 1 && display_str != 'centuries') {
      display_str += 's';
    }
    return display_str;
  }
}
