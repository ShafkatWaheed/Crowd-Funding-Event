class PollOptionResult {
  final int index;
  final String text;
  final int voteCount;
  final double percentage;

  const PollOptionResult({
    required this.index,
    required this.text,
    required this.voteCount,
    required this.percentage,
  });

  factory PollOptionResult.fromJson(Map<String, dynamic> json) {
    return PollOptionResult(
      index: json['index'] as int,
      text: json['text'] as String,
      voteCount: json['vote_count'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class EventPoll {
  final int id;
  final int eventId;
  final int organizerId;
  final String question;
  final List<String> options;
  final bool isActive;
  final bool isClosed;
  final bool showResultsWhileOpen;
  final DateTime createdAt;
  final DateTime? closedAt;
  final int? viewerVoteIndex;
  final List<PollOptionResult>? results;
  final int totalVotes;

  const EventPoll({
    required this.id,
    required this.eventId,
    required this.organizerId,
    required this.question,
    required this.options,
    this.isActive = true,
    this.isClosed = false,
    this.showResultsWhileOpen = true,
    required this.createdAt,
    this.closedAt,
    this.viewerVoteIndex,
    this.results,
    this.totalVotes = 0,
  });

  factory EventPoll.fromJson(Map<String, dynamic> json) {
    return EventPoll(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      organizerId: json['organizer_id'] as int,
      question: json['question'] as String,
      options: (json['options'] as List).map((e) => e as String).toList(),
      isActive: json['is_active'] as bool? ?? true,
      isClosed: json['is_closed'] as bool? ?? false,
      showResultsWhileOpen: json['show_results_while_open'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      viewerVoteIndex: json['viewer_vote_index'] as int?,
      results: json['results'] != null
          ? (json['results'] as List)
              .map((r) => PollOptionResult.fromJson(r as Map<String, dynamic>))
              .toList()
          : null,
      totalVotes: json['total_votes'] as int? ?? 0,
    );
  }
}

class CastVoteRequest {
  final int optionIndex;

  const CastVoteRequest({required this.optionIndex});

  Map<String, dynamic> toJson() => {'option_index': optionIndex};
}

class CreatePollRequest {
  final String question;
  final List<String> options;
  final bool showResultsWhileOpen;

  const CreatePollRequest({
    required this.question,
    required this.options,
    this.showResultsWhileOpen = true,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'show_results_while_open': showResultsWhileOpen,
      };
}
