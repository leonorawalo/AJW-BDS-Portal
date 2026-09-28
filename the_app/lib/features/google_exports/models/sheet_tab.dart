/// One tab of an exported Google Sheet. The first row is the header.
/// Cells are String, num or null.
class SheetTab {
  const SheetTab({required this.name, required this.rows});

  final String name;
  final List<List<Object?>> rows;

  Map<String, dynamic> toJson() => {'name': name, 'rows': rows};
}
