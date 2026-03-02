import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/star_rating.dart';
import '../helpers/pump_app.dart';

void main() {
  group('StarRating (interactive)', () {
    testWidgets('renders 5 stars', (tester) async {
      await pumpApp(tester, const Scaffold(body: StarRating(rating: 0)));
      await tester.pump();

      // All 5 should be outline when rating is 0
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('fills stars up to rating value', (tester) async {
      await pumpApp(tester, const Scaffold(body: StarRating(rating: 3)));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('fills all 5 stars for rating 5', (tester) async {
      await pumpApp(tester, const Scaffold(body: StarRating(rating: 5)));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    testWidgets('tapping a star fires onChanged with correct value', (tester) async {
      int? tappedValue;
      await pumpApp(
        tester,
        Scaffold(
          body: StarRating(
            rating: 0,
            onChanged: (v) => tappedValue = v,
          ),
        ),
      );
      await tester.pump();

      // Tap the 4th star (index 3 → value 4)
      final stars = find.byIcon(Icons.star_outline_rounded);
      await tester.tap(stars.at(3));
      await tester.pump();

      expect(tappedValue, 4);
    });

    testWidgets('tapping first star fires onChanged with 1', (tester) async {
      int? tappedValue;
      await pumpApp(
        tester,
        Scaffold(
          body: StarRating(
            rating: 0,
            onChanged: (v) => tappedValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
      await tester.pump();

      expect(tappedValue, 1);
    });

    testWidgets('stars are not tappable when onChanged is null', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRating(rating: 3)),
      );
      await tester.pump();

      // Tapping should not throw — just verifying it's safe
      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pump();
    });

    testWidgets('respects custom size', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRating(rating: 1, size: 40)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded).first);
      expect(icon.size, 40);
    });
  });

  group('StarRatingDisplay', () {
    testWidgets('renders average, count, and filled stars', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRatingDisplay(avgStars: 4.2, count: 15)),
      );
      await tester.pump();

      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('(15)'), findsOneWidget);
      // 4 full + 1 half (4.2 rounds down to 4 full, 0.2 < 0.3 so outline)
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('shows half star for fractional >= 0.3', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRatingDisplay(avgStars: 3.5, count: 10)),
      );
      await tester.pump();

      expect(find.text('3.5'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('shows dash when avgStars is null', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRatingDisplay(avgStars: null, count: 0)),
      );
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('(0)'), findsOneWidget);
      // All outline stars
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
    });

    testWidgets('shows all filled stars for 5.0', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRatingDisplay(avgStars: 5.0, count: 100)),
      );
      await tester.pump();

      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('(100)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('respects custom size', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: StarRatingDisplay(avgStars: 3.0, count: 5, size: 24)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded).first);
      expect(icon.size, 24);
    });
  });
}
