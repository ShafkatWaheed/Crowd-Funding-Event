import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/poll.dart';
import '../repositories/base_repository.dart';
import '../repositories/poll_repository.dart';

class PollProvider extends ChangeNotifier {
  final PollRepository _repo;

  PollProvider(this._repo);

  EventPoll? activePoll;
  bool loading = false;
  String? error;

  Timer? _pollTimer;
  int? _pollingEventId;

  /// Start 5-second auto-polling for the active poll on [eventId].
  /// Immediately fetches once, then polls on interval.
  void startPolling(int eventId) {
    if (_pollingEventId == eventId && _pollTimer != null) return;
    _pollingEventId = eventId;
    _pollTimer?.cancel();
    _load(eventId);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(eventId));
  }

  /// Stop auto-polling.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingEventId = null;
  }

  Future<void> _load(int eventId) async {
    try {
      final poll = await _repo.getActivePoll(eventId);
      activePoll = poll;
      error = null;
    } catch (e) {
      error = ApiError.extractMessage(e);
    }
    notifyListeners();
  }

  /// Cast a vote — optimistic update first, then confirm from server.
  Future<void> vote(int eventId, int pollId, int optionIndex) async {
    // Optimistic update
    if (activePoll != null && activePoll!.id == pollId) {
      activePoll = EventPoll(
        id: activePoll!.id,
        eventId: activePoll!.eventId,
        organizerId: activePoll!.organizerId,
        question: activePoll!.question,
        options: activePoll!.options,
        isActive: activePoll!.isActive,
        isClosed: activePoll!.isClosed,
        showResultsWhileOpen: activePoll!.showResultsWhileOpen,
        createdAt: activePoll!.createdAt,
        closedAt: activePoll!.closedAt,
        viewerVoteIndex: optionIndex,
        results: activePoll!.results,
        totalVotes: activePoll!.totalVotes,
      );
      notifyListeners();
    }
    try {
      final updated = await _repo.castVote(
          eventId, pollId, CastVoteRequest(optionIndex: optionIndex));
      activePoll = updated;
    } catch (_) {
      // Revert optimistic update on error
      await _load(eventId);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> createPoll(int eventId, CreatePollRequest request) async {
    final poll = await _repo.createPoll(eventId, request);
    activePoll = poll;
    notifyListeners();
  }

  Future<void> closePoll(int eventId, int pollId) async {
    final poll = await _repo.closePoll(eventId, pollId);
    activePoll = poll;
    notifyListeners();
  }

  Future<List<EventPoll>> listPolls(int eventId) async {
    return _repo.listPolls(eventId);
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
