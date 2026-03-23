import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/date_time_utils.dart';

class ShareUtils {
  ShareUtils._();

  static String eventUrl(int eventId, {String? token}) {
    String base;
    if (kIsWeb) {
      base = Uri.base.resolve('/events/$eventId').toString();
    } else {
      base = '/events/$eventId';
    }
    return token != null ? '$base?token=$token' : base;
  }

  static String shareText(String title, int eventId, {String? token}) {
    return '$title\n${eventUrl(eventId, token: token)}';
  }

  // ── Gmail compose URL ──

  static Uri gmailUrl(String title, int eventId, {String? dateInfo, String? token}) {
    final url = eventUrl(eventId, token: token);
    final body = StringBuffer()
      ..writeln('Hey! I found this event and thought you might be interested:')
      ..writeln()
      ..writeln(title);
    if (dateInfo != null && dateInfo.isNotEmpty) {
      body.writeln(dateInfo);
    }
    body
      ..writeln()
      ..writeln(url);

    return Uri.parse('https://mail.google.com/mail/').replace(
      queryParameters: {
        'view': 'cm',
        'su': 'Check out: $title',
        'body': body.toString(),
      },
    );
  }

  // ── WhatsApp share URL ──

  static Uri whatsAppUrl(String title, int eventId, {String? token}) {
    final text = 'Check out $title!\n${eventUrl(eventId, token: token)}';
    return Uri.parse('https://wa.me/').replace(
      queryParameters: {'text': text},
    );
  }

  // ── Google Calendar URL ──

  static Uri? googleCalendarUrl({
    required String title,
    required DateTime? startTime,
    required DateTime? endTime,
    String? description,
    String? location,
  }) {
    if (startTime == null || endTime == null) return null;

    String gcalDt(DateTime dt) {
      final utc = dt.toUtc();
      return '${utc.year.toString().padLeft(4, '0')}'
          '${utc.month.toString().padLeft(2, '0')}'
          '${utc.day.toString().padLeft(2, '0')}'
          'T'
          '${utc.hour.toString().padLeft(2, '0')}'
          '${utc.minute.toString().padLeft(2, '0')}'
          '${utc.second.toString().padLeft(2, '0')}'
          'Z';
    }

    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${gcalDt(startTime)}/${gcalDt(endTime)}',
    };

    final desc = (description ?? '').trim();
    if (desc.isNotEmpty) {
      params['details'] = desc.length > 500 ? '${desc.substring(0, 497)}...' : desc;
    }
    if (location != null && location.isNotEmpty) {
      params['location'] = location;
    }

    return Uri.https('calendar.google.com', '/calendar/render', params);
  }

  // ── Helpers to extract data from Event ──

  static String? venueString(event) {
    final v = event.venue;
    if (v == null) return null;
    final parts = <String>[
      if (v.name.isNotEmpty) v.name,
      if (v.address.isNotEmpty) v.address,
      if (v.city.isNotEmpty) v.city,
    ];
    if (v.province != null && v.province!.isNotEmpty) {
      parts.add(v.province!);
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? dateInfoString(event) {
    if (event.startTime == null) return null;
    return AppDateFormat.eventCard(event.startTime!);
  }

  // ── Ticket share helpers ──

  static String ticketShareText({
    required String eventTitle,
    required int eventId,
    String? tierName,
    String? receiptNumber,
  }) {
    final buf = StringBuffer()
      ..writeln("I'm going to $eventTitle!")
      ..writeln('Ticket: ${tierName ?? "General"}');
    if (receiptNumber != null) buf.writeln('Receipt: $receiptNumber');
    buf.write(eventUrl(eventId));
    return buf.toString();
  }

  static Uri ticketGmailUrl({
    required String eventTitle,
    required int eventId,
    String? tierName,
  }) {
    final url = eventUrl(eventId);
    final body = StringBuffer()
      ..writeln("Hey! I'm going to $eventTitle and thought you might want to join!")
      ..writeln()
      ..writeln('Check it out: $url');

    return Uri.parse('https://mail.google.com/mail/').replace(
      queryParameters: {
        'view': 'cm',
        'su': "I'm going to $eventTitle!",
        'body': body.toString(),
      },
    );
  }

  static Uri ticketWhatsAppUrl({
    required String eventTitle,
    required int eventId,
  }) {
    final text = "I'm going to $eventTitle! Check it out: ${eventUrl(eventId)}";
    return Uri.parse('https://wa.me/').replace(
      queryParameters: {'text': text},
    );
  }
}
