import 'package:flutter/foundation.dart';

import '../models/faq.dart';
import '../repositories/faq_repository.dart';

class FaqProvider extends ChangeNotifier {
  final FaqRepository _repo;

  FaqProvider(this._repo);

  List<OrganizerFaq> faqs = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      faqs = await _repo.getMyFaqs();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> create(CreateFaqRequest request) async {
    await _repo.createFaq(request);
    await load();
  }

  Future<void> update(int id, UpdateFaqRequest request) async {
    await _repo.updateFaq(id, request);
    await load();
  }

  Future<void> delete(int id) async {
    await _repo.deleteFaq(id);
    faqs.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  Future<void> toggleActive(OrganizerFaq faq) async {
    await _repo.updateFaq(faq.id, UpdateFaqRequest(isActive: !faq.isActive));
    await load();
  }
}
