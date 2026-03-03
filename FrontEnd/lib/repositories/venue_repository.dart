import '../models/venue.dart';
import 'base_repository.dart';

class VenueRepository extends BaseRepository {
  VenueRepository(super.dio);

  Future<List<Venue>> getVenues() async {
    final resp = await dio.get('/venues');
    return (resp.data as List).map((e) => Venue.fromJson(e)).toList();
  }

  Future<Venue> getVenue(int venueId) async {
    final resp = await dio.get('/venues/$venueId');
    return Venue.fromJson(resp.data);
  }

  Future<Venue> createVenue(Map<String, dynamic> data) async {
    final resp = await dio.post('/venues', data: data);
    return Venue.fromJson(resp.data);
  }

  Future<Venue> updateVenue(
      int venueId, Map<String, dynamic> data) async {
    final resp = await dio.patch('/venues/$venueId', data: data);
    return Venue.fromJson(resp.data);
  }

  Future<void> deleteVenue(int venueId) async {
    await dio.delete('/venues/$venueId');
  }
}
