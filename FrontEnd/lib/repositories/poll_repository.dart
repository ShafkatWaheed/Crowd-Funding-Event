import '../models/poll.dart';
import 'base_repository.dart';

class PollRepository extends BaseRepository {
  PollRepository(super.dio);

  /// GET /events/:eventId/polls/active — returns null if no active poll.
  Future<EventPoll?> getActivePoll(int eventId) async {
    final r = await dio.get('/events/$eventId/polls/active');
    if (r.data == null) return null;
    return EventPoll.fromJson(r.data as Map<String, dynamic>);
  }

  /// GET /events/:eventId/polls — organizer list of all polls.
  Future<List<EventPoll>> listPolls(int eventId) async {
    final r = await dio.get('/events/$eventId/polls');
    return (r.data as List)
        .map((j) => EventPoll.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// POST /events/:eventId/polls — create a new poll.
  Future<EventPoll> createPoll(int eventId, CreatePollRequest request) async {
    final r = await dio.post('/events/$eventId/polls', data: request.toJson());
    return EventPoll.fromJson(r.data as Map<String, dynamic>);
  }

  /// POST /events/:eventId/polls/:pollId/vote — cast a vote.
  Future<EventPoll> castVote(
      int eventId, int pollId, CastVoteRequest request) async {
    final r = await dio.post(
      '/events/$eventId/polls/$pollId/vote',
      data: request.toJson(),
    );
    return EventPoll.fromJson(r.data as Map<String, dynamic>);
  }

  /// POST /events/:eventId/polls/:pollId/close — close the poll.
  Future<EventPoll> closePoll(int eventId, int pollId) async {
    final r = await dio.post('/events/$eventId/polls/$pollId/close');
    return EventPoll.fromJson(r.data as Map<String, dynamic>);
  }
}
