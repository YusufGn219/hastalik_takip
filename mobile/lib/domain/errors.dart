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
  static const routineTimeInvalid = 'routine_time_invalid';
  static const routineTimesEmpty = 'routine_times_empty';
  static const routineTooManyTimes = 'routine_too_many_times';
  static const routineDaysEmpty = 'routine_days_empty';
  static const doseNotScheduled = 'dose_not_scheduled';
  static const doseAlreadyTaken = 'dose_already_taken';
  static const doseAlreadySkipped = 'dose_already_skipped';
  static const heightOutOfRange = 'height_out_of_range';
  static const weightOutOfRange = 'weight_out_of_range';
  static const measurementDayInvalid = 'measurement_day_invalid';
  static const measurementDayInFuture = 'measurement_day_in_future';
  static const dailyFieldNameEmpty = 'daily_field_name_empty';
  static const dailyFieldNameTooLong = 'daily_field_name_too_long';
  static const dailyFieldNameExists = 'daily_field_name_exists';
  static const dailyFieldKindInvalid = 'daily_field_kind_invalid';
  static const dailyFieldUnitTooLong = 'daily_field_unit_too_long';
  static const dailyFieldRangeInvalid = 'daily_field_range_invalid';
  static const dailyFieldTooMany = 'daily_field_too_many';
  static const dailyFieldNotFound = 'daily_field_not_found';
  static const dailyFieldBuiltin = 'daily_field_builtin';
  static const dailyFieldInactive = 'daily_field_inactive';
  static const dailyFieldValueInvalid = 'daily_field_value_invalid';
}
