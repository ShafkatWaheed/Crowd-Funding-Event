// Rating models for event and user reviews.

class Rating {
  final int id;
  final String raterName;
  final String direction;
  final int stars;
  final String? description;
  final String? createdAt;

  Rating({
    required this.id,
    required this.raterName,
    required this.direction,
    required this.stars,
    this.description,
    this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
        id: (json['id'] as num?)?.toInt() ?? 0,
        raterName: (json['rater_name'] as String?) ?? 'Anonymous',
        direction: (json['direction'] as String?) ?? '',
        stars: (json['stars'] as int?) ?? 0,
        description: json['description'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class MyRating {
  final int id;
  final int stars;
  final String? description;

  MyRating({
    required this.id,
    required this.stars,
    this.description,
  });

  factory MyRating.fromJson(Map<String, dynamic> json) => MyRating(
        id: (json['id'] as num?)?.toInt() ?? 0,
        stars: (json['stars'] as int?) ?? 0,
        description: json['description'] as String?,
      );
}

class RatingsSummary {
  final double? avgStars;
  final int count;
  final List<Rating> topReviews;
  final List<Rating> worstReviews;
  final MyRating? myRating;
  final MyRating? myOrganizerRating;

  RatingsSummary({
    this.avgStars,
    required this.count,
    this.topReviews = const [],
    this.worstReviews = const [],
    this.myRating,
    this.myOrganizerRating,
  });

  factory RatingsSummary.fromJson(Map<String, dynamic> json) => RatingsSummary(
        avgStars: (json['avg_stars'] as num?)?.toDouble(),
        count: (json['count'] as int?) ?? 0,
        topReviews: (json['top_reviews'] as List?)
                ?.map(
                    (e) => Rating.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        worstReviews: (json['worst_reviews'] as List?)
                ?.map(
                    (e) => Rating.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        myRating: json['my_rating'] != null
            ? MyRating.fromJson(
                Map<String, dynamic>.from(json['my_rating'] as Map))
            : null,
        myOrganizerRating: json['my_organizer_rating'] != null
            ? MyRating.fromJson(
                Map<String, dynamic>.from(json['my_organizer_rating'] as Map))
            : null,
      );
}
