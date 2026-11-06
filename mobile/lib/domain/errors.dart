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
  static const categoryNameEmpty = 'category_name_empty';
  static const categoryNameTooLong = 'category_name_too_long';
  static const categoryNameExists = 'category_name_exists';
  static const categoryNotFound = 'category_not_found';
  static const medicationNotFound = 'medication_not_found';
  static const conditionNameEmpty = 'condition_name_empty';
  static const conditionNameTooLong = 'condition_name_too_long';
  static const conditionNameExists = 'condition_name_exists';
  static const conditionNotFound = 'condition_not_found';
}
