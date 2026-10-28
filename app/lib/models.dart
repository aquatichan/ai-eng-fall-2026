class Group {
  Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.isOwner,
  });

  final String id;
  final String name;
  final String joinCode;
  final bool isOwner;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        isOwner: json['is_owner'] as bool? ?? false,
      );

  /// "ABCDEFGHJKMN" -> "ABCD-EFGH-JKMN", for reading aloud and typing.
  String get displayCode => formatJoinCode(joinCode);
}

String formatJoinCode(String code) {
  final parts = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    parts.add(code.substring(i, i + 4 > code.length ? code.length : i + 4));
  }
  return parts.join('-');
}
