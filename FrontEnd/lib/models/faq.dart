class OrganizerFaq {
  final int id;
  final int organizerId;
  final String question;
  final String answer;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizerFaq({
    required this.id,
    required this.organizerId,
    required this.question,
    required this.answer,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizerFaq.fromJson(Map<String, dynamic> json) {
    return OrganizerFaq(
      id: json['id'] as int,
      organizerId: json['organizer_id'] as int,
      question: json['question'] as String,
      answer: json['answer'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CreateFaqRequest {
  final String question;
  final String answer;
  final int displayOrder;

  const CreateFaqRequest({
    required this.question,
    required this.answer,
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'display_order': displayOrder,
      };
}

class UpdateFaqRequest {
  final String? question;
  final String? answer;
  final int? displayOrder;
  final bool? isActive;

  const UpdateFaqRequest({
    this.question,
    this.answer,
    this.displayOrder,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (question != null) m['question'] = question;
    if (answer != null) m['answer'] = answer;
    if (displayOrder != null) m['display_order'] = displayOrder;
    if (isActive != null) m['is_active'] = isActive;
    return m;
  }
}
