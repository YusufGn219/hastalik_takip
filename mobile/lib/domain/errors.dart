/// İş kuralı ihlali. Ekranlar [code] ile kullanıcıya çevrilmiş metni seçer
/// (çeviri altyapısı Sprint 3'te gelir); [message] geliştirici içindir.
class RuleViolation implements Exception {
  const RuleViolation(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RuleViolation($code): $message';
}

abstract final class RuleCodes {
  static const episodeAlreadyClosed = 'episode_already_closed';
  static const episodeEndBeforeStart = 'episode_end_before_start';
  static const episodeAndConditionBoth = 'episode_and_condition_both';
  static const invalidRecurringDay = 'invalid_recurring_day';
}
