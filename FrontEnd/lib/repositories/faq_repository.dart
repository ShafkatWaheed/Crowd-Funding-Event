import '../models/faq.dart';
import 'base_repository.dart';

class FaqRepository extends BaseRepository {
  FaqRepository(super.dio);

  Future<List<OrganizerFaq>> getMyFaqs() async {
    final r = await dio.get('/me/faqs');
    return (r.data as List).map((j) => OrganizerFaq.fromJson(j)).toList();
  }

  Future<OrganizerFaq> createFaq(CreateFaqRequest request) async {
    final r = await dio.post('/me/faqs', data: request.toJson());
    return OrganizerFaq.fromJson(r.data);
  }

  Future<OrganizerFaq> updateFaq(int id, UpdateFaqRequest request) async {
    final r = await dio.patch('/me/faqs/$id', data: request.toJson());
    return OrganizerFaq.fromJson(r.data);
  }

  Future<void> deleteFaq(int id) async {
    await dio.delete('/me/faqs/$id');
  }

  Future<List<OrganizerFaq>> getEventFaqs(int eventId) async {
    final r = await dio.get('/events/$eventId/faqs');
    return (r.data as List).map((j) => OrganizerFaq.fromJson(j)).toList();
  }
}
