/// How long one kind of data is kept (retention_settings, migration
/// 20261008150000). [keepDays] null = kept until deleted by hand.
class RetentionSetting {
  const RetentionSetting({required this.key, required this.label, this.keepDays});

  factory RetentionSetting.fromMap(Map<String, dynamic> map) => RetentionSetting(
        key: map['key'] as String,
        label: map['label'] as String,
        keepDays: (map['keep_days'] as num?)?.toInt(),
      );

  final String key;
  final String label;
  final int? keepDays;
}
