import 'base_repository.dart';

class VenueRepository extends BaseRepository {
  VenueRepository(super.dio);

  Future<List<dynamic>> getVenues() async {
    final resp = await dio.get('/venues');
    return resp.data;
  }

  Future<Map<String, dynamic>> getVenue(int venueId) async {
    final resp = await dio.get('/venues/$venueId');
    return resp.data;
  }

  Future<Map<String, dynamic>> createVenue(Map<String, dynamic> data) async {
    final resp = await dio.post('/venues', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateVenue(
      int venueId, Map<String, dynamic> data) async {
    final resp = await dio.patch('/venues/$venueId', data: data);
    return resp.data;
  }

  Future<void> deleteVenue(int venueId) async {
    await dio.delete('/venues/$venueId');
  }
}
