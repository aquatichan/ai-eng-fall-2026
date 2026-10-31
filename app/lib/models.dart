class Group {
  Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.isOwner,
    this.ownerId,
  });

  final String id;
  final String name;
  final String joinCode;
  final bool isOwner;
  final String? ownerId;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        isOwner: json['is_owner'] as bool? ?? false,
        ownerId: json['owner_id'] as String?,
      );

  /// "ABC123" -> "ABC-123", for reading aloud and typing.
  String get displayCode => formatJoinCode(joinCode);
}

/// Labels shared by iOS and Android Contacts. Must match api/lib/card.ts.
const phoneLabels = ['mobile', 'iphone', 'home', 'work', 'main', 'pager', 'other'];
const emailLabels = ['home', 'work', 'school', 'icloud', 'other'];

String labelName(String label) => switch (label) {
      'iphone' => 'iPhone',
      'icloud' => 'iCloud',
      _ => label.isEmpty ? label : label[0].toUpperCase() + label.substring(1),
    };

class LabeledValue {
  const LabeledValue(this.label, this.value);

  final String label;
  final String value;

  @override
  bool operator ==(Object other) => other is LabeledValue && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

/// A person's contact card: one per user, shown in every group they're in.
class ContactCard {
  const ContactCard({
    required this.firstName,
    this.lastName,
    this.phones = const [],
    this.emails = const [],
    this.company,
    this.jobTitle,
    this.website,
    this.address,
    this.birthday,
  });

  final String firstName;
  final String? lastName;
  final List<LabeledValue> phones;
  final List<LabeledValue> emails;
  final String? company;
  final String? jobTitle;
  final String? website;
  final String? address;
  final DateTime? birthday;

  String get fullName => [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory ContactCard.fromJson(Map<String, dynamic> json) => ContactCard(
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String?,
        phones: [
          for (final p in json['phones'] as List? ?? const [])
            LabeledValue(p['label'] as String? ?? 'other', p['number'] as String),
        ],
        emails: [
          for (final e in json['emails'] as List? ?? const [])
            LabeledValue(e['label'] as String? ?? 'other', e['address'] as String),
        ],
        company: json['company'] as String?,
        jobTitle: json['job_title'] as String?,
        website: json['website'] as String?,
        address: json['address'] as String?,
        birthday: json['birthday'] == null ? null : DateTime.parse(json['birthday'] as String),
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'phones': [for (final p in phones) {'label': p.label, 'number': p.value}],
        'emails': [for (final e in emails) {'label': e.label, 'address': e.value}],
        'company': company,
        'job_title': jobTitle,
        'website': website,
        'address': address,
        'birthday': birthday == null ? null : _isoDate(birthday!),
      };
}

/// Someone in a group: their card plus who they are in it.
class Member {
  Member({required this.userId, required this.card, this.isOwner = false, this.updatedAt});

  final String userId;
  final ContactCard card;
  final bool isOwner;
  final DateTime? updatedAt;

  String get name => card.fullName;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        userId: json['user_id'] as String,
        card: ContactCard.fromJson(json),
        isOwner: json['is_owner'] as bool? ?? false,
        updatedAt: json['updated_at'] == null ? null : DateTime.tryParse(json['updated_at'] as String),
      );
}

class GroupDetail {
  GroupDetail({required this.group, required this.members, required this.meId});

  final Group group;
  final List<Member> members;

  /// Your user ID, to pick yourself out of [members].
  final String meId;

  factory GroupDetail.fromJson(Map<String, dynamic> json) => GroupDetail(
        group: Group.fromJson(json['group'] as Map<String, dynamic>),
        members: (json['members'] as List).map((m) => Member.fromJson(m as Map<String, dynamic>)).toList(),
        meId: json['me_id'] as String,
      );
}

String formatJoinCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
