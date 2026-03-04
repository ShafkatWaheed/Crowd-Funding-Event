import 'package:flutter/foundation.dart';

import '../models/venue.dart';
import '../repositories/venue_repository.dart';

class VenueProvider extends ChangeNotifier {
  final VenueRepository _repo;
  VenueProvider(this._repo);

  Future<List<Venue>> getVenues() => _repo.getVenues();

  Future<Venue> getVenue(int venueId) => _repo.getVenue(venueId);

  Future<Venue> createVenue(CreateVenueRequest data) =>
      _repo.createVenue(data);

  Future<Venue> updateVenue(int venueId, UpdateVenueRequest data) =>
      _repo.updateVenue(venueId, data);

  Future<void> deleteVenue(int venueId) => _repo.deleteVenue(venueId);
}
