// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedEventsTable extends CachedEvents
    with TableInfo<$CachedEventsTable, CachedEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
      'end_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _venueNameMeta =
      const VerificationMeta('venueName');
  @override
  late final GeneratedColumn<String> venueName = GeneratedColumn<String>(
      'venue_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firstImageUrlMeta =
      const VerificationMeta('firstImageUrl');
  @override
  late final GeneratedColumn<String> firstImageUrl = GeneratedColumn<String>(
      'first_image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fundingGoalCentsMeta =
      const VerificationMeta('fundingGoalCents');
  @override
  late final GeneratedColumn<int> fundingGoalCents = GeneratedColumn<int>(
      'funding_goal_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _totalPledgedCentsMeta =
      const VerificationMeta('totalPledgedCents');
  @override
  late final GeneratedColumn<int> totalPledgedCents = GeneratedColumn<int>(
      'total_pledged_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ticketsSoldCountMeta =
      const VerificationMeta('ticketsSoldCount');
  @override
  late final GeneratedColumn<int> ticketsSoldCount = GeneratedColumn<int>(
      'tickets_sold_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        genre,
        status,
        startTime,
        endTime,
        lat,
        lng,
        venueName,
        city,
        firstImageUrl,
        fundingGoalCents,
        totalPledgedCents,
        ticketsSoldCount,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_events';
  @override
  VerificationContext validateIntegrity(Insertable<CachedEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    }
    if (data.containsKey('venue_name')) {
      context.handle(_venueNameMeta,
          venueName.isAcceptableOrUnknown(data['venue_name']!, _venueNameMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('first_image_url')) {
      context.handle(
          _firstImageUrlMeta,
          firstImageUrl.isAcceptableOrUnknown(
              data['first_image_url']!, _firstImageUrlMeta));
    }
    if (data.containsKey('funding_goal_cents')) {
      context.handle(
          _fundingGoalCentsMeta,
          fundingGoalCents.isAcceptableOrUnknown(
              data['funding_goal_cents']!, _fundingGoalCentsMeta));
    }
    if (data.containsKey('total_pledged_cents')) {
      context.handle(
          _totalPledgedCentsMeta,
          totalPledgedCents.isAcceptableOrUnknown(
              data['total_pledged_cents']!, _totalPledgedCentsMeta));
    }
    if (data.containsKey('tickets_sold_count')) {
      context.handle(
          _ticketsSoldCountMeta,
          ticketsSoldCount.isAcceptableOrUnknown(
              data['tickets_sold_count']!, _ticketsSoldCountMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time']),
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_time']),
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng']),
      venueName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_name']),
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      firstImageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}first_image_url']),
      fundingGoalCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}funding_goal_cents']),
      totalPledgedCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_pledged_cents']),
      ticketsSoldCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tickets_sold_count']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedEventsTable createAlias(String alias) {
    return $CachedEventsTable(attachedDatabase, alias);
  }
}

class CachedEvent extends DataClass implements Insertable<CachedEvent> {
  final int id;
  final String title;
  final String? description;
  final String? genre;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? lat;
  final double? lng;
  final String? venueName;
  final String? city;
  final String? firstImageUrl;
  final int? fundingGoalCents;
  final int? totalPledgedCents;
  final int? ticketsSoldCount;
  final DateTime syncedAt;
  const CachedEvent(
      {required this.id,
      required this.title,
      this.description,
      this.genre,
      required this.status,
      this.startTime,
      this.endTime,
      this.lat,
      this.lng,
      this.venueName,
      this.city,
      this.firstImageUrl,
      this.fundingGoalCents,
      this.totalPledgedCents,
      this.ticketsSoldCount,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<DateTime>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || venueName != null) {
      map['venue_name'] = Variable<String>(venueName);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || firstImageUrl != null) {
      map['first_image_url'] = Variable<String>(firstImageUrl);
    }
    if (!nullToAbsent || fundingGoalCents != null) {
      map['funding_goal_cents'] = Variable<int>(fundingGoalCents);
    }
    if (!nullToAbsent || totalPledgedCents != null) {
      map['total_pledged_cents'] = Variable<int>(totalPledgedCents);
    }
    if (!nullToAbsent || ticketsSoldCount != null) {
      map['tickets_sold_count'] = Variable<int>(ticketsSoldCount);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedEventsCompanion toCompanion(bool nullToAbsent) {
    return CachedEventsCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      status: Value(status),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      venueName: venueName == null && nullToAbsent
          ? const Value.absent()
          : Value(venueName),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      firstImageUrl: firstImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(firstImageUrl),
      fundingGoalCents: fundingGoalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(fundingGoalCents),
      totalPledgedCents: totalPledgedCents == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPledgedCents),
      ticketsSoldCount: ticketsSoldCount == null && nullToAbsent
          ? const Value.absent()
          : Value(ticketsSoldCount),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedEvent(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      genre: serializer.fromJson<String?>(json['genre']),
      status: serializer.fromJson<String>(json['status']),
      startTime: serializer.fromJson<DateTime?>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      venueName: serializer.fromJson<String?>(json['venueName']),
      city: serializer.fromJson<String?>(json['city']),
      firstImageUrl: serializer.fromJson<String?>(json['firstImageUrl']),
      fundingGoalCents: serializer.fromJson<int?>(json['fundingGoalCents']),
      totalPledgedCents: serializer.fromJson<int?>(json['totalPledgedCents']),
      ticketsSoldCount: serializer.fromJson<int?>(json['ticketsSoldCount']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'genre': serializer.toJson<String?>(genre),
      'status': serializer.toJson<String>(status),
      'startTime': serializer.toJson<DateTime?>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'venueName': serializer.toJson<String?>(venueName),
      'city': serializer.toJson<String?>(city),
      'firstImageUrl': serializer.toJson<String?>(firstImageUrl),
      'fundingGoalCents': serializer.toJson<int?>(fundingGoalCents),
      'totalPledgedCents': serializer.toJson<int?>(totalPledgedCents),
      'ticketsSoldCount': serializer.toJson<int?>(ticketsSoldCount),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedEvent copyWith(
          {int? id,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> genre = const Value.absent(),
          String? status,
          Value<DateTime?> startTime = const Value.absent(),
          Value<DateTime?> endTime = const Value.absent(),
          Value<double?> lat = const Value.absent(),
          Value<double?> lng = const Value.absent(),
          Value<String?> venueName = const Value.absent(),
          Value<String?> city = const Value.absent(),
          Value<String?> firstImageUrl = const Value.absent(),
          Value<int?> fundingGoalCents = const Value.absent(),
          Value<int?> totalPledgedCents = const Value.absent(),
          Value<int?> ticketsSoldCount = const Value.absent(),
          DateTime? syncedAt}) =>
      CachedEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        genre: genre.present ? genre.value : this.genre,
        status: status ?? this.status,
        startTime: startTime.present ? startTime.value : this.startTime,
        endTime: endTime.present ? endTime.value : this.endTime,
        lat: lat.present ? lat.value : this.lat,
        lng: lng.present ? lng.value : this.lng,
        venueName: venueName.present ? venueName.value : this.venueName,
        city: city.present ? city.value : this.city,
        firstImageUrl:
            firstImageUrl.present ? firstImageUrl.value : this.firstImageUrl,
        fundingGoalCents: fundingGoalCents.present
            ? fundingGoalCents.value
            : this.fundingGoalCents,
        totalPledgedCents: totalPledgedCents.present
            ? totalPledgedCents.value
            : this.totalPledgedCents,
        ticketsSoldCount: ticketsSoldCount.present
            ? ticketsSoldCount.value
            : this.ticketsSoldCount,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedEvent copyWithCompanion(CachedEventsCompanion data) {
    return CachedEvent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      genre: data.genre.present ? data.genre.value : this.genre,
      status: data.status.present ? data.status.value : this.status,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      venueName: data.venueName.present ? data.venueName.value : this.venueName,
      city: data.city.present ? data.city.value : this.city,
      firstImageUrl: data.firstImageUrl.present
          ? data.firstImageUrl.value
          : this.firstImageUrl,
      fundingGoalCents: data.fundingGoalCents.present
          ? data.fundingGoalCents.value
          : this.fundingGoalCents,
      totalPledgedCents: data.totalPledgedCents.present
          ? data.totalPledgedCents.value
          : this.totalPledgedCents,
      ticketsSoldCount: data.ticketsSoldCount.present
          ? data.ticketsSoldCount.value
          : this.ticketsSoldCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedEvent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genre: $genre, ')
          ..write('status: $status, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('venueName: $venueName, ')
          ..write('city: $city, ')
          ..write('firstImageUrl: $firstImageUrl, ')
          ..write('fundingGoalCents: $fundingGoalCents, ')
          ..write('totalPledgedCents: $totalPledgedCents, ')
          ..write('ticketsSoldCount: $ticketsSoldCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      description,
      genre,
      status,
      startTime,
      endTime,
      lat,
      lng,
      venueName,
      city,
      firstImageUrl,
      fundingGoalCents,
      totalPledgedCents,
      ticketsSoldCount,
      syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedEvent &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.genre == this.genre &&
          other.status == this.status &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.venueName == this.venueName &&
          other.city == this.city &&
          other.firstImageUrl == this.firstImageUrl &&
          other.fundingGoalCents == this.fundingGoalCents &&
          other.totalPledgedCents == this.totalPledgedCents &&
          other.ticketsSoldCount == this.ticketsSoldCount &&
          other.syncedAt == this.syncedAt);
}

class CachedEventsCompanion extends UpdateCompanion<CachedEvent> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> genre;
  final Value<String> status;
  final Value<DateTime?> startTime;
  final Value<DateTime?> endTime;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> venueName;
  final Value<String?> city;
  final Value<String?> firstImageUrl;
  final Value<int?> fundingGoalCents;
  final Value<int?> totalPledgedCents;
  final Value<int?> ticketsSoldCount;
  final Value<DateTime> syncedAt;
  const CachedEventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.genre = const Value.absent(),
    this.status = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.venueName = const Value.absent(),
    this.city = const Value.absent(),
    this.firstImageUrl = const Value.absent(),
    this.fundingGoalCents = const Value.absent(),
    this.totalPledgedCents = const Value.absent(),
    this.ticketsSoldCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedEventsCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.genre = const Value.absent(),
    this.status = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.venueName = const Value.absent(),
    this.city = const Value.absent(),
    this.firstImageUrl = const Value.absent(),
    this.fundingGoalCents = const Value.absent(),
    this.totalPledgedCents = const Value.absent(),
    this.ticketsSoldCount = const Value.absent(),
    required DateTime syncedAt,
  }) : syncedAt = Value(syncedAt);
  static Insertable<CachedEvent> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? genre,
    Expression<String>? status,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? venueName,
    Expression<String>? city,
    Expression<String>? firstImageUrl,
    Expression<int>? fundingGoalCents,
    Expression<int>? totalPledgedCents,
    Expression<int>? ticketsSoldCount,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (venueName != null) 'venue_name': venueName,
      if (city != null) 'city': city,
      if (firstImageUrl != null) 'first_image_url': firstImageUrl,
      if (fundingGoalCents != null) 'funding_goal_cents': fundingGoalCents,
      if (totalPledgedCents != null) 'total_pledged_cents': totalPledgedCents,
      if (ticketsSoldCount != null) 'tickets_sold_count': ticketsSoldCount,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedEventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? genre,
      Value<String>? status,
      Value<DateTime?>? startTime,
      Value<DateTime?>? endTime,
      Value<double?>? lat,
      Value<double?>? lng,
      Value<String?>? venueName,
      Value<String?>? city,
      Value<String?>? firstImageUrl,
      Value<int?>? fundingGoalCents,
      Value<int?>? totalPledgedCents,
      Value<int?>? ticketsSoldCount,
      Value<DateTime>? syncedAt}) {
    return CachedEventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      venueName: venueName ?? this.venueName,
      city: city ?? this.city,
      firstImageUrl: firstImageUrl ?? this.firstImageUrl,
      fundingGoalCents: fundingGoalCents ?? this.fundingGoalCents,
      totalPledgedCents: totalPledgedCents ?? this.totalPledgedCents,
      ticketsSoldCount: ticketsSoldCount ?? this.ticketsSoldCount,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (venueName.present) {
      map['venue_name'] = Variable<String>(venueName.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (firstImageUrl.present) {
      map['first_image_url'] = Variable<String>(firstImageUrl.value);
    }
    if (fundingGoalCents.present) {
      map['funding_goal_cents'] = Variable<int>(fundingGoalCents.value);
    }
    if (totalPledgedCents.present) {
      map['total_pledged_cents'] = Variable<int>(totalPledgedCents.value);
    }
    if (ticketsSoldCount.present) {
      map['tickets_sold_count'] = Variable<int>(ticketsSoldCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedEventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genre: $genre, ')
          ..write('status: $status, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('venueName: $venueName, ')
          ..write('city: $city, ')
          ..write('firstImageUrl: $firstImageUrl, ')
          ..write('fundingGoalCents: $fundingGoalCents, ')
          ..write('totalPledgedCents: $totalPledgedCents, ')
          ..write('ticketsSoldCount: $ticketsSoldCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedVenuesTable extends CachedVenues
    with TableInfo<$CachedVenuesTable, CachedVenue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVenuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, address, city, lat, lng];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_venues';
  @override
  VerificationContext validateIntegrity(Insertable<CachedVenue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedVenue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVenue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng']),
    );
  }

  @override
  $CachedVenuesTable createAlias(String alias) {
    return $CachedVenuesTable(attachedDatabase, alias);
  }
}

class CachedVenue extends DataClass implements Insertable<CachedVenue> {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final double? lat;
  final double? lng;
  const CachedVenue(
      {required this.id,
      required this.name,
      this.address,
      this.city,
      this.lat,
      this.lng});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    return map;
  }

  CachedVenuesCompanion toCompanion(bool nullToAbsent) {
    return CachedVenuesCompanion(
      id: Value(id),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
    );
  }

  factory CachedVenue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVenue(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      city: serializer.fromJson<String?>(json['city']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'city': serializer.toJson<String?>(city),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
    };
  }

  CachedVenue copyWith(
          {int? id,
          String? name,
          Value<String?> address = const Value.absent(),
          Value<String?> city = const Value.absent(),
          Value<double?> lat = const Value.absent(),
          Value<double?> lng = const Value.absent()}) =>
      CachedVenue(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address.present ? address.value : this.address,
        city: city.present ? city.value : this.city,
        lat: lat.present ? lat.value : this.lat,
        lng: lng.present ? lng.value : this.lng,
      );
  CachedVenue copyWithCompanion(CachedVenuesCompanion data) {
    return CachedVenue(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      city: data.city.present ? data.city.value : this.city,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVenue(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, address, city, lat, lng);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVenue &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.city == this.city &&
          other.lat == this.lat &&
          other.lng == this.lng);
}

class CachedVenuesCompanion extends UpdateCompanion<CachedVenue> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> city;
  final Value<double?> lat;
  final Value<double?> lng;
  const CachedVenuesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
  });
  CachedVenuesCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
  });
  static Insertable<CachedVenue> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? city,
    Expression<double>? lat,
    Expression<double>? lng,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
  }

  CachedVenuesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? address,
      Value<String?>? city,
      Value<double?>? lat,
      Value<double?>? lng}) {
    return CachedVenuesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVenuesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng')
          ..write(')'))
        .toString();
  }
}

class $CachedTicketTiersTable extends CachedTicketTiers
    with TableInfo<$CachedTicketTiersTable, CachedTicketTier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTicketTiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _priceCentsMeta =
      const VerificationMeta('priceCents');
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
      'price_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _maxReservedSpotsMeta =
      const VerificationMeta('maxReservedSpots');
  @override
  late final GeneratedColumn<int> maxReservedSpots = GeneratedColumn<int>(
      'max_reserved_spots', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _displayOrderMeta =
      const VerificationMeta('displayOrder');
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
      'display_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, eventId, name, priceCents, maxReservedSpots, displayOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_ticket_tiers';
  @override
  VerificationContext validateIntegrity(Insertable<CachedTicketTier> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('price_cents')) {
      context.handle(
          _priceCentsMeta,
          priceCents.isAcceptableOrUnknown(
              data['price_cents']!, _priceCentsMeta));
    }
    if (data.containsKey('max_reserved_spots')) {
      context.handle(
          _maxReservedSpotsMeta,
          maxReservedSpots.isAcceptableOrUnknown(
              data['max_reserved_spots']!, _maxReservedSpotsMeta));
    }
    if (data.containsKey('display_order')) {
      context.handle(
          _displayOrderMeta,
          displayOrder.isAcceptableOrUnknown(
              data['display_order']!, _displayOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTicketTier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTicketTier(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      priceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_cents'])!,
      maxReservedSpots: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_reserved_spots']),
      displayOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}display_order'])!,
    );
  }

  @override
  $CachedTicketTiersTable createAlias(String alias) {
    return $CachedTicketTiersTable(attachedDatabase, alias);
  }
}

class CachedTicketTier extends DataClass
    implements Insertable<CachedTicketTier> {
  final int id;
  final int eventId;
  final String name;
  final int priceCents;
  final int? maxReservedSpots;
  final int displayOrder;
  const CachedTicketTier(
      {required this.id,
      required this.eventId,
      required this.name,
      required this.priceCents,
      this.maxReservedSpots,
      required this.displayOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['name'] = Variable<String>(name);
    map['price_cents'] = Variable<int>(priceCents);
    if (!nullToAbsent || maxReservedSpots != null) {
      map['max_reserved_spots'] = Variable<int>(maxReservedSpots);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  CachedTicketTiersCompanion toCompanion(bool nullToAbsent) {
    return CachedTicketTiersCompanion(
      id: Value(id),
      eventId: Value(eventId),
      name: Value(name),
      priceCents: Value(priceCents),
      maxReservedSpots: maxReservedSpots == null && nullToAbsent
          ? const Value.absent()
          : Value(maxReservedSpots),
      displayOrder: Value(displayOrder),
    );
  }

  factory CachedTicketTier.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTicketTier(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      name: serializer.fromJson<String>(json['name']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      maxReservedSpots: serializer.fromJson<int?>(json['maxReservedSpots']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'name': serializer.toJson<String>(name),
      'priceCents': serializer.toJson<int>(priceCents),
      'maxReservedSpots': serializer.toJson<int?>(maxReservedSpots),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  CachedTicketTier copyWith(
          {int? id,
          int? eventId,
          String? name,
          int? priceCents,
          Value<int?> maxReservedSpots = const Value.absent(),
          int? displayOrder}) =>
      CachedTicketTier(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        name: name ?? this.name,
        priceCents: priceCents ?? this.priceCents,
        maxReservedSpots: maxReservedSpots.present
            ? maxReservedSpots.value
            : this.maxReservedSpots,
        displayOrder: displayOrder ?? this.displayOrder,
      );
  CachedTicketTier copyWithCompanion(CachedTicketTiersCompanion data) {
    return CachedTicketTier(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      name: data.name.present ? data.name.value : this.name,
      priceCents:
          data.priceCents.present ? data.priceCents.value : this.priceCents,
      maxReservedSpots: data.maxReservedSpots.present
          ? data.maxReservedSpots.value
          : this.maxReservedSpots,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTicketTier(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('maxReservedSpots: $maxReservedSpots, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, eventId, name, priceCents, maxReservedSpots, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTicketTier &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.name == this.name &&
          other.priceCents == this.priceCents &&
          other.maxReservedSpots == this.maxReservedSpots &&
          other.displayOrder == this.displayOrder);
}

class CachedTicketTiersCompanion extends UpdateCompanion<CachedTicketTier> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<String> name;
  final Value<int> priceCents;
  final Value<int?> maxReservedSpots;
  final Value<int> displayOrder;
  const CachedTicketTiersCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.name = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.maxReservedSpots = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  CachedTicketTiersCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    this.name = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.maxReservedSpots = const Value.absent(),
    this.displayOrder = const Value.absent(),
  }) : eventId = Value(eventId);
  static Insertable<CachedTicketTier> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<String>? name,
    Expression<int>? priceCents,
    Expression<int>? maxReservedSpots,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (name != null) 'name': name,
      if (priceCents != null) 'price_cents': priceCents,
      if (maxReservedSpots != null) 'max_reserved_spots': maxReservedSpots,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  CachedTicketTiersCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<String>? name,
      Value<int>? priceCents,
      Value<int?>? maxReservedSpots,
      Value<int>? displayOrder}) {
    return CachedTicketTiersCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      maxReservedSpots: maxReservedSpots ?? this.maxReservedSpots,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (maxReservedSpots.present) {
      map['max_reserved_spots'] = Variable<int>(maxReservedSpots.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTicketTiersCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('maxReservedSpots: $maxReservedSpots, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }
}

class $OfflineTicketsTable extends OfflineTickets
    with TableInfo<$OfflineTicketsTable, OfflineTicket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ticketCodeMeta =
      const VerificationMeta('ticketCode');
  @override
  late final GeneratedColumn<String> ticketCode = GeneratedColumn<String>(
      'ticket_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _userNameMeta =
      const VerificationMeta('userName');
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
      'user_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tierNameMeta =
      const VerificationMeta('tierName');
  @override
  late final GeneratedColumn<String> tierName = GeneratedColumn<String>(
      'tier_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('purchased'));
  static const VerificationMeta _scannedLocallyMeta =
      const VerificationMeta('scannedLocally');
  @override
  late final GeneratedColumn<bool> scannedLocally = GeneratedColumn<bool>(
      'scanned_locally', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("scanned_locally" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        eventId,
        ticketCode,
        userId,
        userName,
        tierName,
        status,
        scannedLocally,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_tickets';
  @override
  VerificationContext validateIntegrity(Insertable<OfflineTicket> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('ticket_code')) {
      context.handle(
          _ticketCodeMeta,
          ticketCode.isAcceptableOrUnknown(
              data['ticket_code']!, _ticketCodeMeta));
    } else if (isInserting) {
      context.missing(_ticketCodeMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('user_name')) {
      context.handle(_userNameMeta,
          userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta));
    }
    if (data.containsKey('tier_name')) {
      context.handle(_tierNameMeta,
          tierName.isAcceptableOrUnknown(data['tier_name']!, _tierNameMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('scanned_locally')) {
      context.handle(
          _scannedLocallyMeta,
          scannedLocally.isAcceptableOrUnknown(
              data['scanned_locally']!, _scannedLocallyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineTicket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineTicket(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      ticketCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ticket_code'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id']),
      userName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_name']),
      tierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_name']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      scannedLocally: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}scanned_locally'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $OfflineTicketsTable createAlias(String alias) {
    return $OfflineTicketsTable(attachedDatabase, alias);
  }
}

class OfflineTicket extends DataClass implements Insertable<OfflineTicket> {
  final int id;
  final int eventId;
  final String ticketCode;
  final int? userId;
  final String? userName;
  final String? tierName;
  final String status;
  final bool scannedLocally;
  final DateTime syncedAt;
  const OfflineTicket(
      {required this.id,
      required this.eventId,
      required this.ticketCode,
      this.userId,
      this.userName,
      this.tierName,
      required this.status,
      required this.scannedLocally,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['ticket_code'] = Variable<String>(ticketCode);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    if (!nullToAbsent || userName != null) {
      map['user_name'] = Variable<String>(userName);
    }
    if (!nullToAbsent || tierName != null) {
      map['tier_name'] = Variable<String>(tierName);
    }
    map['status'] = Variable<String>(status);
    map['scanned_locally'] = Variable<bool>(scannedLocally);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  OfflineTicketsCompanion toCompanion(bool nullToAbsent) {
    return OfflineTicketsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      ticketCode: Value(ticketCode),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      userName: userName == null && nullToAbsent
          ? const Value.absent()
          : Value(userName),
      tierName: tierName == null && nullToAbsent
          ? const Value.absent()
          : Value(tierName),
      status: Value(status),
      scannedLocally: Value(scannedLocally),
      syncedAt: Value(syncedAt),
    );
  }

  factory OfflineTicket.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineTicket(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      ticketCode: serializer.fromJson<String>(json['ticketCode']),
      userId: serializer.fromJson<int?>(json['userId']),
      userName: serializer.fromJson<String?>(json['userName']),
      tierName: serializer.fromJson<String?>(json['tierName']),
      status: serializer.fromJson<String>(json['status']),
      scannedLocally: serializer.fromJson<bool>(json['scannedLocally']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'ticketCode': serializer.toJson<String>(ticketCode),
      'userId': serializer.toJson<int?>(userId),
      'userName': serializer.toJson<String?>(userName),
      'tierName': serializer.toJson<String?>(tierName),
      'status': serializer.toJson<String>(status),
      'scannedLocally': serializer.toJson<bool>(scannedLocally),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  OfflineTicket copyWith(
          {int? id,
          int? eventId,
          String? ticketCode,
          Value<int?> userId = const Value.absent(),
          Value<String?> userName = const Value.absent(),
          Value<String?> tierName = const Value.absent(),
          String? status,
          bool? scannedLocally,
          DateTime? syncedAt}) =>
      OfflineTicket(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        ticketCode: ticketCode ?? this.ticketCode,
        userId: userId.present ? userId.value : this.userId,
        userName: userName.present ? userName.value : this.userName,
        tierName: tierName.present ? tierName.value : this.tierName,
        status: status ?? this.status,
        scannedLocally: scannedLocally ?? this.scannedLocally,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  OfflineTicket copyWithCompanion(OfflineTicketsCompanion data) {
    return OfflineTicket(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      ticketCode:
          data.ticketCode.present ? data.ticketCode.value : this.ticketCode,
      userId: data.userId.present ? data.userId.value : this.userId,
      userName: data.userName.present ? data.userName.value : this.userName,
      tierName: data.tierName.present ? data.tierName.value : this.tierName,
      status: data.status.present ? data.status.value : this.status,
      scannedLocally: data.scannedLocally.present
          ? data.scannedLocally.value
          : this.scannedLocally,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineTicket(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('tierName: $tierName, ')
          ..write('status: $status, ')
          ..write('scannedLocally: $scannedLocally, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventId, ticketCode, userId, userName,
      tierName, status, scannedLocally, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineTicket &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.ticketCode == this.ticketCode &&
          other.userId == this.userId &&
          other.userName == this.userName &&
          other.tierName == this.tierName &&
          other.status == this.status &&
          other.scannedLocally == this.scannedLocally &&
          other.syncedAt == this.syncedAt);
}

class OfflineTicketsCompanion extends UpdateCompanion<OfflineTicket> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<String> ticketCode;
  final Value<int?> userId;
  final Value<String?> userName;
  final Value<String?> tierName;
  final Value<String> status;
  final Value<bool> scannedLocally;
  final Value<DateTime> syncedAt;
  const OfflineTicketsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.ticketCode = const Value.absent(),
    this.userId = const Value.absent(),
    this.userName = const Value.absent(),
    this.tierName = const Value.absent(),
    this.status = const Value.absent(),
    this.scannedLocally = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  OfflineTicketsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required String ticketCode,
    this.userId = const Value.absent(),
    this.userName = const Value.absent(),
    this.tierName = const Value.absent(),
    this.status = const Value.absent(),
    this.scannedLocally = const Value.absent(),
    required DateTime syncedAt,
  })  : eventId = Value(eventId),
        ticketCode = Value(ticketCode),
        syncedAt = Value(syncedAt);
  static Insertable<OfflineTicket> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<String>? ticketCode,
    Expression<int>? userId,
    Expression<String>? userName,
    Expression<String>? tierName,
    Expression<String>? status,
    Expression<bool>? scannedLocally,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (ticketCode != null) 'ticket_code': ticketCode,
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (tierName != null) 'tier_name': tierName,
      if (status != null) 'status': status,
      if (scannedLocally != null) 'scanned_locally': scannedLocally,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  OfflineTicketsCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<String>? ticketCode,
      Value<int?>? userId,
      Value<String?>? userName,
      Value<String?>? tierName,
      Value<String>? status,
      Value<bool>? scannedLocally,
      Value<DateTime>? syncedAt}) {
    return OfflineTicketsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      ticketCode: ticketCode ?? this.ticketCode,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      tierName: tierName ?? this.tierName,
      status: status ?? this.status,
      scannedLocally: scannedLocally ?? this.scannedLocally,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (ticketCode.present) {
      map['ticket_code'] = Variable<String>(ticketCode.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (tierName.present) {
      map['tier_name'] = Variable<String>(tierName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scannedLocally.present) {
      map['scanned_locally'] = Variable<bool>(scannedLocally.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineTicketsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('tierName: $tierName, ')
          ..write('status: $status, ')
          ..write('scannedLocally: $scannedLocally, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $OfflineScansTable extends OfflineScans
    with TableInfo<$OfflineScansTable, OfflineScan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ticketCodeMeta =
      const VerificationMeta('ticketCode');
  @override
  late final GeneratedColumn<String> ticketCode = GeneratedColumn<String>(
      'ticket_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _scannedAtMeta =
      const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
      'scanned_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _scannedByIdMeta =
      const VerificationMeta('scannedById');
  @override
  late final GeneratedColumn<int> scannedById = GeneratedColumn<int>(
      'scanned_by_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, ticketCode, eventId, scannedAt, scannedById, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_scans';
  @override
  VerificationContext validateIntegrity(Insertable<OfflineScan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ticket_code')) {
      context.handle(
          _ticketCodeMeta,
          ticketCode.isAcceptableOrUnknown(
              data['ticket_code']!, _ticketCodeMeta));
    } else if (isInserting) {
      context.missing(_ticketCodeMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta,
          scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    if (data.containsKey('scanned_by_id')) {
      context.handle(
          _scannedByIdMeta,
          scannedById.isAcceptableOrUnknown(
              data['scanned_by_id']!, _scannedByIdMeta));
    } else if (isInserting) {
      context.missing(_scannedByIdMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineScan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineScan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ticketCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ticket_code'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      scannedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scanned_at'])!,
      scannedById: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scanned_by_id'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $OfflineScansTable createAlias(String alias) {
    return $OfflineScansTable(attachedDatabase, alias);
  }
}

class OfflineScan extends DataClass implements Insertable<OfflineScan> {
  final int id;
  final String ticketCode;
  final int eventId;
  final DateTime scannedAt;
  final int scannedById;
  final bool synced;
  const OfflineScan(
      {required this.id,
      required this.ticketCode,
      required this.eventId,
      required this.scannedAt,
      required this.scannedById,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ticket_code'] = Variable<String>(ticketCode);
    map['event_id'] = Variable<int>(eventId);
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    map['scanned_by_id'] = Variable<int>(scannedById);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  OfflineScansCompanion toCompanion(bool nullToAbsent) {
    return OfflineScansCompanion(
      id: Value(id),
      ticketCode: Value(ticketCode),
      eventId: Value(eventId),
      scannedAt: Value(scannedAt),
      scannedById: Value(scannedById),
      synced: Value(synced),
    );
  }

  factory OfflineScan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineScan(
      id: serializer.fromJson<int>(json['id']),
      ticketCode: serializer.fromJson<String>(json['ticketCode']),
      eventId: serializer.fromJson<int>(json['eventId']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      scannedById: serializer.fromJson<int>(json['scannedById']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ticketCode': serializer.toJson<String>(ticketCode),
      'eventId': serializer.toJson<int>(eventId),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'scannedById': serializer.toJson<int>(scannedById),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  OfflineScan copyWith(
          {int? id,
          String? ticketCode,
          int? eventId,
          DateTime? scannedAt,
          int? scannedById,
          bool? synced}) =>
      OfflineScan(
        id: id ?? this.id,
        ticketCode: ticketCode ?? this.ticketCode,
        eventId: eventId ?? this.eventId,
        scannedAt: scannedAt ?? this.scannedAt,
        scannedById: scannedById ?? this.scannedById,
        synced: synced ?? this.synced,
      );
  OfflineScan copyWithCompanion(OfflineScansCompanion data) {
    return OfflineScan(
      id: data.id.present ? data.id.value : this.id,
      ticketCode:
          data.ticketCode.present ? data.ticketCode.value : this.ticketCode,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      scannedById:
          data.scannedById.present ? data.scannedById.value : this.scannedById,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineScan(')
          ..write('id: $id, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('eventId: $eventId, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('scannedById: $scannedById, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ticketCode, eventId, scannedAt, scannedById, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineScan &&
          other.id == this.id &&
          other.ticketCode == this.ticketCode &&
          other.eventId == this.eventId &&
          other.scannedAt == this.scannedAt &&
          other.scannedById == this.scannedById &&
          other.synced == this.synced);
}

class OfflineScansCompanion extends UpdateCompanion<OfflineScan> {
  final Value<int> id;
  final Value<String> ticketCode;
  final Value<int> eventId;
  final Value<DateTime> scannedAt;
  final Value<int> scannedById;
  final Value<bool> synced;
  const OfflineScansCompanion({
    this.id = const Value.absent(),
    this.ticketCode = const Value.absent(),
    this.eventId = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.scannedById = const Value.absent(),
    this.synced = const Value.absent(),
  });
  OfflineScansCompanion.insert({
    this.id = const Value.absent(),
    required String ticketCode,
    required int eventId,
    required DateTime scannedAt,
    required int scannedById,
    this.synced = const Value.absent(),
  })  : ticketCode = Value(ticketCode),
        eventId = Value(eventId),
        scannedAt = Value(scannedAt),
        scannedById = Value(scannedById);
  static Insertable<OfflineScan> custom({
    Expression<int>? id,
    Expression<String>? ticketCode,
    Expression<int>? eventId,
    Expression<DateTime>? scannedAt,
    Expression<int>? scannedById,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ticketCode != null) 'ticket_code': ticketCode,
      if (eventId != null) 'event_id': eventId,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (scannedById != null) 'scanned_by_id': scannedById,
      if (synced != null) 'synced': synced,
    });
  }

  OfflineScansCompanion copyWith(
      {Value<int>? id,
      Value<String>? ticketCode,
      Value<int>? eventId,
      Value<DateTime>? scannedAt,
      Value<int>? scannedById,
      Value<bool>? synced}) {
    return OfflineScansCompanion(
      id: id ?? this.id,
      ticketCode: ticketCode ?? this.ticketCode,
      eventId: eventId ?? this.eventId,
      scannedAt: scannedAt ?? this.scannedAt,
      scannedById: scannedById ?? this.scannedById,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ticketCode.present) {
      map['ticket_code'] = Variable<String>(ticketCode.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (scannedById.present) {
      map['scanned_by_id'] = Variable<int>(scannedById.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineScansCompanion(')
          ..write('id: $id, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('eventId: $eventId, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('scannedById: $scannedById, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $CachedBookmarksTable extends CachedBookmarks
    with TableInfo<$CachedBookmarksTable, CachedBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [eventId, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<CachedBookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  CachedBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedBookmark(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedBookmarksTable createAlias(String alias) {
    return $CachedBookmarksTable(attachedDatabase, alias);
  }
}

class CachedBookmark extends DataClass implements Insertable<CachedBookmark> {
  final int eventId;
  final DateTime syncedAt;
  const CachedBookmark({required this.eventId, required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedBookmarksCompanion toCompanion(bool nullToAbsent) {
    return CachedBookmarksCompanion(
      eventId: Value(eventId),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedBookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedBookmark(
      eventId: serializer.fromJson<int>(json['eventId']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedBookmark copyWith({int? eventId, DateTime? syncedAt}) => CachedBookmark(
        eventId: eventId ?? this.eventId,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedBookmark copyWithCompanion(CachedBookmarksCompanion data) {
    return CachedBookmark(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedBookmark(')
          ..write('eventId: $eventId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedBookmark &&
          other.eventId == this.eventId &&
          other.syncedAt == this.syncedAt);
}

class CachedBookmarksCompanion extends UpdateCompanion<CachedBookmark> {
  final Value<int> eventId;
  final Value<DateTime> syncedAt;
  const CachedBookmarksCompanion({
    this.eventId = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedBookmarksCompanion.insert({
    this.eventId = const Value.absent(),
    required DateTime syncedAt,
  }) : syncedAt = Value(syncedAt);
  static Insertable<CachedBookmark> custom({
    Expression<int>? eventId,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedBookmarksCompanion copyWith(
      {Value<int>? eventId, Value<DateTime>? syncedAt}) {
    return CachedBookmarksCompanion(
      eventId: eventId ?? this.eventId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedBookmarksCompanion(')
          ..write('eventId: $eventId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedTransportTable extends CachedTransport
    with TableInfo<$CachedTransportTable, CachedTransportData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTransportTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _parkingInfoMeta =
      const VerificationMeta('parkingInfo');
  @override
  late final GeneratedColumn<String> parkingInfo = GeneratedColumn<String>(
      'parking_info', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transitInfoMeta =
      const VerificationMeta('transitInfo');
  @override
  late final GeneratedColumn<String> transitInfo = GeneratedColumn<String>(
      'transit_info', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rideshareInfoMeta =
      const VerificationMeta('rideshareInfo');
  @override
  late final GeneratedColumn<String> rideshareInfo = GeneratedColumn<String>(
      'rideshare_info', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accessibilityInfoMeta =
      const VerificationMeta('accessibilityInfo');
  @override
  late final GeneratedColumn<String> accessibilityInfo =
      GeneratedColumn<String>('accessibility_info', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _directionsUrlMeta =
      const VerificationMeta('directionsUrl');
  @override
  late final GeneratedColumn<String> directionsUrl = GeneratedColumn<String>(
      'directions_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        eventId,
        parkingInfo,
        transitInfo,
        rideshareInfo,
        accessibilityInfo,
        directionsUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_transport';
  @override
  VerificationContext validateIntegrity(
      Insertable<CachedTransportData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    }
    if (data.containsKey('parking_info')) {
      context.handle(
          _parkingInfoMeta,
          parkingInfo.isAcceptableOrUnknown(
              data['parking_info']!, _parkingInfoMeta));
    }
    if (data.containsKey('transit_info')) {
      context.handle(
          _transitInfoMeta,
          transitInfo.isAcceptableOrUnknown(
              data['transit_info']!, _transitInfoMeta));
    }
    if (data.containsKey('rideshare_info')) {
      context.handle(
          _rideshareInfoMeta,
          rideshareInfo.isAcceptableOrUnknown(
              data['rideshare_info']!, _rideshareInfoMeta));
    }
    if (data.containsKey('accessibility_info')) {
      context.handle(
          _accessibilityInfoMeta,
          accessibilityInfo.isAcceptableOrUnknown(
              data['accessibility_info']!, _accessibilityInfoMeta));
    }
    if (data.containsKey('directions_url')) {
      context.handle(
          _directionsUrlMeta,
          directionsUrl.isAcceptableOrUnknown(
              data['directions_url']!, _directionsUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  CachedTransportData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTransportData(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      parkingInfo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parking_info']),
      transitInfo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transit_info']),
      rideshareInfo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rideshare_info']),
      accessibilityInfo: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}accessibility_info']),
      directionsUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}directions_url']),
    );
  }

  @override
  $CachedTransportTable createAlias(String alias) {
    return $CachedTransportTable(attachedDatabase, alias);
  }
}

class CachedTransportData extends DataClass
    implements Insertable<CachedTransportData> {
  final int eventId;
  final String? parkingInfo;
  final String? transitInfo;
  final String? rideshareInfo;
  final String? accessibilityInfo;
  final String? directionsUrl;
  const CachedTransportData(
      {required this.eventId,
      this.parkingInfo,
      this.transitInfo,
      this.rideshareInfo,
      this.accessibilityInfo,
      this.directionsUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    if (!nullToAbsent || parkingInfo != null) {
      map['parking_info'] = Variable<String>(parkingInfo);
    }
    if (!nullToAbsent || transitInfo != null) {
      map['transit_info'] = Variable<String>(transitInfo);
    }
    if (!nullToAbsent || rideshareInfo != null) {
      map['rideshare_info'] = Variable<String>(rideshareInfo);
    }
    if (!nullToAbsent || accessibilityInfo != null) {
      map['accessibility_info'] = Variable<String>(accessibilityInfo);
    }
    if (!nullToAbsent || directionsUrl != null) {
      map['directions_url'] = Variable<String>(directionsUrl);
    }
    return map;
  }

  CachedTransportCompanion toCompanion(bool nullToAbsent) {
    return CachedTransportCompanion(
      eventId: Value(eventId),
      parkingInfo: parkingInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(parkingInfo),
      transitInfo: transitInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(transitInfo),
      rideshareInfo: rideshareInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(rideshareInfo),
      accessibilityInfo: accessibilityInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(accessibilityInfo),
      directionsUrl: directionsUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(directionsUrl),
    );
  }

  factory CachedTransportData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTransportData(
      eventId: serializer.fromJson<int>(json['eventId']),
      parkingInfo: serializer.fromJson<String?>(json['parkingInfo']),
      transitInfo: serializer.fromJson<String?>(json['transitInfo']),
      rideshareInfo: serializer.fromJson<String?>(json['rideshareInfo']),
      accessibilityInfo:
          serializer.fromJson<String?>(json['accessibilityInfo']),
      directionsUrl: serializer.fromJson<String?>(json['directionsUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'parkingInfo': serializer.toJson<String?>(parkingInfo),
      'transitInfo': serializer.toJson<String?>(transitInfo),
      'rideshareInfo': serializer.toJson<String?>(rideshareInfo),
      'accessibilityInfo': serializer.toJson<String?>(accessibilityInfo),
      'directionsUrl': serializer.toJson<String?>(directionsUrl),
    };
  }

  CachedTransportData copyWith(
          {int? eventId,
          Value<String?> parkingInfo = const Value.absent(),
          Value<String?> transitInfo = const Value.absent(),
          Value<String?> rideshareInfo = const Value.absent(),
          Value<String?> accessibilityInfo = const Value.absent(),
          Value<String?> directionsUrl = const Value.absent()}) =>
      CachedTransportData(
        eventId: eventId ?? this.eventId,
        parkingInfo: parkingInfo.present ? parkingInfo.value : this.parkingInfo,
        transitInfo: transitInfo.present ? transitInfo.value : this.transitInfo,
        rideshareInfo:
            rideshareInfo.present ? rideshareInfo.value : this.rideshareInfo,
        accessibilityInfo: accessibilityInfo.present
            ? accessibilityInfo.value
            : this.accessibilityInfo,
        directionsUrl:
            directionsUrl.present ? directionsUrl.value : this.directionsUrl,
      );
  CachedTransportData copyWithCompanion(CachedTransportCompanion data) {
    return CachedTransportData(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      parkingInfo:
          data.parkingInfo.present ? data.parkingInfo.value : this.parkingInfo,
      transitInfo:
          data.transitInfo.present ? data.transitInfo.value : this.transitInfo,
      rideshareInfo: data.rideshareInfo.present
          ? data.rideshareInfo.value
          : this.rideshareInfo,
      accessibilityInfo: data.accessibilityInfo.present
          ? data.accessibilityInfo.value
          : this.accessibilityInfo,
      directionsUrl: data.directionsUrl.present
          ? data.directionsUrl.value
          : this.directionsUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransportData(')
          ..write('eventId: $eventId, ')
          ..write('parkingInfo: $parkingInfo, ')
          ..write('transitInfo: $transitInfo, ')
          ..write('rideshareInfo: $rideshareInfo, ')
          ..write('accessibilityInfo: $accessibilityInfo, ')
          ..write('directionsUrl: $directionsUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, parkingInfo, transitInfo,
      rideshareInfo, accessibilityInfo, directionsUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTransportData &&
          other.eventId == this.eventId &&
          other.parkingInfo == this.parkingInfo &&
          other.transitInfo == this.transitInfo &&
          other.rideshareInfo == this.rideshareInfo &&
          other.accessibilityInfo == this.accessibilityInfo &&
          other.directionsUrl == this.directionsUrl);
}

class CachedTransportCompanion extends UpdateCompanion<CachedTransportData> {
  final Value<int> eventId;
  final Value<String?> parkingInfo;
  final Value<String?> transitInfo;
  final Value<String?> rideshareInfo;
  final Value<String?> accessibilityInfo;
  final Value<String?> directionsUrl;
  const CachedTransportCompanion({
    this.eventId = const Value.absent(),
    this.parkingInfo = const Value.absent(),
    this.transitInfo = const Value.absent(),
    this.rideshareInfo = const Value.absent(),
    this.accessibilityInfo = const Value.absent(),
    this.directionsUrl = const Value.absent(),
  });
  CachedTransportCompanion.insert({
    this.eventId = const Value.absent(),
    this.parkingInfo = const Value.absent(),
    this.transitInfo = const Value.absent(),
    this.rideshareInfo = const Value.absent(),
    this.accessibilityInfo = const Value.absent(),
    this.directionsUrl = const Value.absent(),
  });
  static Insertable<CachedTransportData> custom({
    Expression<int>? eventId,
    Expression<String>? parkingInfo,
    Expression<String>? transitInfo,
    Expression<String>? rideshareInfo,
    Expression<String>? accessibilityInfo,
    Expression<String>? directionsUrl,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (parkingInfo != null) 'parking_info': parkingInfo,
      if (transitInfo != null) 'transit_info': transitInfo,
      if (rideshareInfo != null) 'rideshare_info': rideshareInfo,
      if (accessibilityInfo != null) 'accessibility_info': accessibilityInfo,
      if (directionsUrl != null) 'directions_url': directionsUrl,
    });
  }

  CachedTransportCompanion copyWith(
      {Value<int>? eventId,
      Value<String?>? parkingInfo,
      Value<String?>? transitInfo,
      Value<String?>? rideshareInfo,
      Value<String?>? accessibilityInfo,
      Value<String?>? directionsUrl}) {
    return CachedTransportCompanion(
      eventId: eventId ?? this.eventId,
      parkingInfo: parkingInfo ?? this.parkingInfo,
      transitInfo: transitInfo ?? this.transitInfo,
      rideshareInfo: rideshareInfo ?? this.rideshareInfo,
      accessibilityInfo: accessibilityInfo ?? this.accessibilityInfo,
      directionsUrl: directionsUrl ?? this.directionsUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (parkingInfo.present) {
      map['parking_info'] = Variable<String>(parkingInfo.value);
    }
    if (transitInfo.present) {
      map['transit_info'] = Variable<String>(transitInfo.value);
    }
    if (rideshareInfo.present) {
      map['rideshare_info'] = Variable<String>(rideshareInfo.value);
    }
    if (accessibilityInfo.present) {
      map['accessibility_info'] = Variable<String>(accessibilityInfo.value);
    }
    if (directionsUrl.present) {
      map['directions_url'] = Variable<String>(directionsUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransportCompanion(')
          ..write('eventId: $eventId, ')
          ..write('parkingInfo: $parkingInfo, ')
          ..write('transitInfo: $transitInfo, ')
          ..write('rideshareInfo: $rideshareInfo, ')
          ..write('accessibilityInfo: $accessibilityInfo, ')
          ..write('directionsUrl: $directionsUrl')
          ..write(')'))
        .toString();
  }
}

class $CachedMyTicketsTable extends CachedMyTickets
    with TableInfo<$CachedMyTicketsTable, CachedMyTicket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMyTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ticketCodeMeta =
      const VerificationMeta('ticketCode');
  @override
  late final GeneratedColumn<String> ticketCode = GeneratedColumn<String>(
      'ticket_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receiptNumberMeta =
      const VerificationMeta('receiptNumber');
  @override
  late final GeneratedColumn<String> receiptNumber = GeneratedColumn<String>(
      'receipt_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tierNameMeta =
      const VerificationMeta('tierName');
  @override
  late final GeneratedColumn<String> tierName = GeneratedColumn<String>(
      'tier_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _eventTitleMeta =
      const VerificationMeta('eventTitle');
  @override
  late final GeneratedColumn<String> eventTitle = GeneratedColumn<String>(
      'event_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountPaidCentsMeta =
      const VerificationMeta('amountPaidCents');
  @override
  late final GeneratedColumn<int> amountPaidCents = GeneratedColumn<int>(
      'amount_paid_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _discountAppliedCentsMeta =
      const VerificationMeta('discountAppliedCents');
  @override
  late final GeneratedColumn<int> discountAppliedCents = GeneratedColumn<int>(
      'discount_applied_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('purchased'));
  static const VerificationMeta _scannedAtMeta =
      const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
      'scanned_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _encryptedQrPayloadMeta =
      const VerificationMeta('encryptedQrPayload');
  @override
  late final GeneratedColumn<String> encryptedQrPayload =
      GeneratedColumn<String>('encrypted_qr_payload', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        eventId,
        userId,
        ticketCode,
        receiptNumber,
        tierName,
        eventTitle,
        amountPaidCents,
        discountAppliedCents,
        status,
        scannedAt,
        encryptedQrPayload,
        createdAt,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_my_tickets';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMyTicket> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('ticket_code')) {
      context.handle(
          _ticketCodeMeta,
          ticketCode.isAcceptableOrUnknown(
              data['ticket_code']!, _ticketCodeMeta));
    } else if (isInserting) {
      context.missing(_ticketCodeMeta);
    }
    if (data.containsKey('receipt_number')) {
      context.handle(
          _receiptNumberMeta,
          receiptNumber.isAcceptableOrUnknown(
              data['receipt_number']!, _receiptNumberMeta));
    }
    if (data.containsKey('tier_name')) {
      context.handle(_tierNameMeta,
          tierName.isAcceptableOrUnknown(data['tier_name']!, _tierNameMeta));
    }
    if (data.containsKey('event_title')) {
      context.handle(
          _eventTitleMeta,
          eventTitle.isAcceptableOrUnknown(
              data['event_title']!, _eventTitleMeta));
    }
    if (data.containsKey('amount_paid_cents')) {
      context.handle(
          _amountPaidCentsMeta,
          amountPaidCents.isAcceptableOrUnknown(
              data['amount_paid_cents']!, _amountPaidCentsMeta));
    }
    if (data.containsKey('discount_applied_cents')) {
      context.handle(
          _discountAppliedCentsMeta,
          discountAppliedCents.isAcceptableOrUnknown(
              data['discount_applied_cents']!, _discountAppliedCentsMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta,
          scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    }
    if (data.containsKey('encrypted_qr_payload')) {
      context.handle(
          _encryptedQrPayloadMeta,
          encryptedQrPayload.isAcceptableOrUnknown(
              data['encrypted_qr_payload']!, _encryptedQrPayloadMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMyTicket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMyTicket(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
      ticketCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ticket_code'])!,
      receiptNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receipt_number']),
      tierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_name']),
      eventTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_title']),
      amountPaidCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_paid_cents'])!,
      discountAppliedCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}discount_applied_cents'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      scannedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scanned_at']),
      encryptedQrPayload: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}encrypted_qr_payload']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedMyTicketsTable createAlias(String alias) {
    return $CachedMyTicketsTable(attachedDatabase, alias);
  }
}

class CachedMyTicket extends DataClass implements Insertable<CachedMyTicket> {
  final int id;
  final int eventId;
  final int userId;
  final String ticketCode;
  final String? receiptNumber;
  final String? tierName;
  final String? eventTitle;
  final int amountPaidCents;
  final int discountAppliedCents;
  final String status;
  final DateTime? scannedAt;
  final String? encryptedQrPayload;
  final DateTime createdAt;
  final DateTime syncedAt;
  const CachedMyTicket(
      {required this.id,
      required this.eventId,
      required this.userId,
      required this.ticketCode,
      this.receiptNumber,
      this.tierName,
      this.eventTitle,
      required this.amountPaidCents,
      required this.discountAppliedCents,
      required this.status,
      this.scannedAt,
      this.encryptedQrPayload,
      required this.createdAt,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['user_id'] = Variable<int>(userId);
    map['ticket_code'] = Variable<String>(ticketCode);
    if (!nullToAbsent || receiptNumber != null) {
      map['receipt_number'] = Variable<String>(receiptNumber);
    }
    if (!nullToAbsent || tierName != null) {
      map['tier_name'] = Variable<String>(tierName);
    }
    if (!nullToAbsent || eventTitle != null) {
      map['event_title'] = Variable<String>(eventTitle);
    }
    map['amount_paid_cents'] = Variable<int>(amountPaidCents);
    map['discount_applied_cents'] = Variable<int>(discountAppliedCents);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<DateTime>(scannedAt);
    }
    if (!nullToAbsent || encryptedQrPayload != null) {
      map['encrypted_qr_payload'] = Variable<String>(encryptedQrPayload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedMyTicketsCompanion toCompanion(bool nullToAbsent) {
    return CachedMyTicketsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      userId: Value(userId),
      ticketCode: Value(ticketCode),
      receiptNumber: receiptNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptNumber),
      tierName: tierName == null && nullToAbsent
          ? const Value.absent()
          : Value(tierName),
      eventTitle: eventTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTitle),
      amountPaidCents: Value(amountPaidCents),
      discountAppliedCents: Value(discountAppliedCents),
      status: Value(status),
      scannedAt: scannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scannedAt),
      encryptedQrPayload: encryptedQrPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedQrPayload),
      createdAt: Value(createdAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedMyTicket.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMyTicket(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      userId: serializer.fromJson<int>(json['userId']),
      ticketCode: serializer.fromJson<String>(json['ticketCode']),
      receiptNumber: serializer.fromJson<String?>(json['receiptNumber']),
      tierName: serializer.fromJson<String?>(json['tierName']),
      eventTitle: serializer.fromJson<String?>(json['eventTitle']),
      amountPaidCents: serializer.fromJson<int>(json['amountPaidCents']),
      discountAppliedCents:
          serializer.fromJson<int>(json['discountAppliedCents']),
      status: serializer.fromJson<String>(json['status']),
      scannedAt: serializer.fromJson<DateTime?>(json['scannedAt']),
      encryptedQrPayload:
          serializer.fromJson<String?>(json['encryptedQrPayload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'userId': serializer.toJson<int>(userId),
      'ticketCode': serializer.toJson<String>(ticketCode),
      'receiptNumber': serializer.toJson<String?>(receiptNumber),
      'tierName': serializer.toJson<String?>(tierName),
      'eventTitle': serializer.toJson<String?>(eventTitle),
      'amountPaidCents': serializer.toJson<int>(amountPaidCents),
      'discountAppliedCents': serializer.toJson<int>(discountAppliedCents),
      'status': serializer.toJson<String>(status),
      'scannedAt': serializer.toJson<DateTime?>(scannedAt),
      'encryptedQrPayload': serializer.toJson<String?>(encryptedQrPayload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedMyTicket copyWith(
          {int? id,
          int? eventId,
          int? userId,
          String? ticketCode,
          Value<String?> receiptNumber = const Value.absent(),
          Value<String?> tierName = const Value.absent(),
          Value<String?> eventTitle = const Value.absent(),
          int? amountPaidCents,
          int? discountAppliedCents,
          String? status,
          Value<DateTime?> scannedAt = const Value.absent(),
          Value<String?> encryptedQrPayload = const Value.absent(),
          DateTime? createdAt,
          DateTime? syncedAt}) =>
      CachedMyTicket(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        userId: userId ?? this.userId,
        ticketCode: ticketCode ?? this.ticketCode,
        receiptNumber:
            receiptNumber.present ? receiptNumber.value : this.receiptNumber,
        tierName: tierName.present ? tierName.value : this.tierName,
        eventTitle: eventTitle.present ? eventTitle.value : this.eventTitle,
        amountPaidCents: amountPaidCents ?? this.amountPaidCents,
        discountAppliedCents: discountAppliedCents ?? this.discountAppliedCents,
        status: status ?? this.status,
        scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
        encryptedQrPayload: encryptedQrPayload.present
            ? encryptedQrPayload.value
            : this.encryptedQrPayload,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedMyTicket copyWithCompanion(CachedMyTicketsCompanion data) {
    return CachedMyTicket(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      ticketCode:
          data.ticketCode.present ? data.ticketCode.value : this.ticketCode,
      receiptNumber: data.receiptNumber.present
          ? data.receiptNumber.value
          : this.receiptNumber,
      tierName: data.tierName.present ? data.tierName.value : this.tierName,
      eventTitle:
          data.eventTitle.present ? data.eventTitle.value : this.eventTitle,
      amountPaidCents: data.amountPaidCents.present
          ? data.amountPaidCents.value
          : this.amountPaidCents,
      discountAppliedCents: data.discountAppliedCents.present
          ? data.discountAppliedCents.value
          : this.discountAppliedCents,
      status: data.status.present ? data.status.value : this.status,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      encryptedQrPayload: data.encryptedQrPayload.present
          ? data.encryptedQrPayload.value
          : this.encryptedQrPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMyTicket(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('tierName: $tierName, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('amountPaidCents: $amountPaidCents, ')
          ..write('discountAppliedCents: $discountAppliedCents, ')
          ..write('status: $status, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('encryptedQrPayload: $encryptedQrPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      eventId,
      userId,
      ticketCode,
      receiptNumber,
      tierName,
      eventTitle,
      amountPaidCents,
      discountAppliedCents,
      status,
      scannedAt,
      encryptedQrPayload,
      createdAt,
      syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMyTicket &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.userId == this.userId &&
          other.ticketCode == this.ticketCode &&
          other.receiptNumber == this.receiptNumber &&
          other.tierName == this.tierName &&
          other.eventTitle == this.eventTitle &&
          other.amountPaidCents == this.amountPaidCents &&
          other.discountAppliedCents == this.discountAppliedCents &&
          other.status == this.status &&
          other.scannedAt == this.scannedAt &&
          other.encryptedQrPayload == this.encryptedQrPayload &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class CachedMyTicketsCompanion extends UpdateCompanion<CachedMyTicket> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<int> userId;
  final Value<String> ticketCode;
  final Value<String?> receiptNumber;
  final Value<String?> tierName;
  final Value<String?> eventTitle;
  final Value<int> amountPaidCents;
  final Value<int> discountAppliedCents;
  final Value<String> status;
  final Value<DateTime?> scannedAt;
  final Value<String?> encryptedQrPayload;
  final Value<DateTime> createdAt;
  final Value<DateTime> syncedAt;
  const CachedMyTicketsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.ticketCode = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.tierName = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.amountPaidCents = const Value.absent(),
    this.discountAppliedCents = const Value.absent(),
    this.status = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.encryptedQrPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedMyTicketsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required int userId,
    required String ticketCode,
    this.receiptNumber = const Value.absent(),
    this.tierName = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.amountPaidCents = const Value.absent(),
    this.discountAppliedCents = const Value.absent(),
    this.status = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.encryptedQrPayload = const Value.absent(),
    required DateTime createdAt,
    required DateTime syncedAt,
  })  : eventId = Value(eventId),
        userId = Value(userId),
        ticketCode = Value(ticketCode),
        createdAt = Value(createdAt),
        syncedAt = Value(syncedAt);
  static Insertable<CachedMyTicket> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<int>? userId,
    Expression<String>? ticketCode,
    Expression<String>? receiptNumber,
    Expression<String>? tierName,
    Expression<String>? eventTitle,
    Expression<int>? amountPaidCents,
    Expression<int>? discountAppliedCents,
    Expression<String>? status,
    Expression<DateTime>? scannedAt,
    Expression<String>? encryptedQrPayload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (userId != null) 'user_id': userId,
      if (ticketCode != null) 'ticket_code': ticketCode,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (tierName != null) 'tier_name': tierName,
      if (eventTitle != null) 'event_title': eventTitle,
      if (amountPaidCents != null) 'amount_paid_cents': amountPaidCents,
      if (discountAppliedCents != null)
        'discount_applied_cents': discountAppliedCents,
      if (status != null) 'status': status,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (encryptedQrPayload != null)
        'encrypted_qr_payload': encryptedQrPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedMyTicketsCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<int>? userId,
      Value<String>? ticketCode,
      Value<String?>? receiptNumber,
      Value<String?>? tierName,
      Value<String?>? eventTitle,
      Value<int>? amountPaidCents,
      Value<int>? discountAppliedCents,
      Value<String>? status,
      Value<DateTime?>? scannedAt,
      Value<String?>? encryptedQrPayload,
      Value<DateTime>? createdAt,
      Value<DateTime>? syncedAt}) {
    return CachedMyTicketsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      ticketCode: ticketCode ?? this.ticketCode,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      tierName: tierName ?? this.tierName,
      eventTitle: eventTitle ?? this.eventTitle,
      amountPaidCents: amountPaidCents ?? this.amountPaidCents,
      discountAppliedCents: discountAppliedCents ?? this.discountAppliedCents,
      status: status ?? this.status,
      scannedAt: scannedAt ?? this.scannedAt,
      encryptedQrPayload: encryptedQrPayload ?? this.encryptedQrPayload,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (ticketCode.present) {
      map['ticket_code'] = Variable<String>(ticketCode.value);
    }
    if (receiptNumber.present) {
      map['receipt_number'] = Variable<String>(receiptNumber.value);
    }
    if (tierName.present) {
      map['tier_name'] = Variable<String>(tierName.value);
    }
    if (eventTitle.present) {
      map['event_title'] = Variable<String>(eventTitle.value);
    }
    if (amountPaidCents.present) {
      map['amount_paid_cents'] = Variable<int>(amountPaidCents.value);
    }
    if (discountAppliedCents.present) {
      map['discount_applied_cents'] = Variable<int>(discountAppliedCents.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (encryptedQrPayload.present) {
      map['encrypted_qr_payload'] = Variable<String>(encryptedQrPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMyTicketsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('ticketCode: $ticketCode, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('tierName: $tierName, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('amountPaidCents: $amountPaidCents, ')
          ..write('discountAppliedCents: $discountAppliedCents, ')
          ..write('status: $status, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('encryptedQrPayload: $encryptedQrPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedScheduleItemsTable extends CachedScheduleItems
    with TableInfo<$CachedScheduleItemsTable, CachedScheduleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedScheduleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
      'start_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
      'end_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _overlapsMeta =
      const VerificationMeta('overlaps');
  @override
  late final GeneratedColumn<bool> overlaps = GeneratedColumn<bool>(
      'overlaps', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("overlaps" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        eventId,
        date,
        startTime,
        endTime,
        title,
        description,
        imageUrl,
        sortOrder,
        overlaps,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_schedule_items';
  @override
  VerificationContext validateIntegrity(Insertable<CachedScheduleItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('overlaps')) {
      context.handle(_overlapsMeta,
          overlaps.isAcceptableOrUnknown(data['overlaps']!, _overlapsMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedScheduleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedScheduleItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_time'])!,
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_time'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      overlaps: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}overlaps'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedScheduleItemsTable createAlias(String alias) {
    return $CachedScheduleItemsTable(attachedDatabase, alias);
  }
}

class CachedScheduleItem extends DataClass
    implements Insertable<CachedScheduleItem> {
  final int id;
  final int eventId;
  final String date;
  final String startTime;
  final String endTime;
  final String title;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool overlaps;
  final DateTime syncedAt;
  const CachedScheduleItem(
      {required this.id,
      required this.eventId,
      required this.date,
      required this.startTime,
      required this.endTime,
      required this.title,
      this.description,
      this.imageUrl,
      required this.sortOrder,
      required this.overlaps,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['date'] = Variable<String>(date);
    map['start_time'] = Variable<String>(startTime);
    map['end_time'] = Variable<String>(endTime);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['overlaps'] = Variable<bool>(overlaps);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedScheduleItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedScheduleItemsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      date: Value(date),
      startTime: Value(startTime),
      endTime: Value(endTime),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      sortOrder: Value(sortOrder),
      overlaps: Value(overlaps),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedScheduleItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedScheduleItem(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      date: serializer.fromJson<String>(json['date']),
      startTime: serializer.fromJson<String>(json['startTime']),
      endTime: serializer.fromJson<String>(json['endTime']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      overlaps: serializer.fromJson<bool>(json['overlaps']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'date': serializer.toJson<String>(date),
      'startTime': serializer.toJson<String>(startTime),
      'endTime': serializer.toJson<String>(endTime),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'overlaps': serializer.toJson<bool>(overlaps),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedScheduleItem copyWith(
          {int? id,
          int? eventId,
          String? date,
          String? startTime,
          String? endTime,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          int? sortOrder,
          bool? overlaps,
          DateTime? syncedAt}) =>
      CachedScheduleItem(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        sortOrder: sortOrder ?? this.sortOrder,
        overlaps: overlaps ?? this.overlaps,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedScheduleItem copyWithCompanion(CachedScheduleItemsCompanion data) {
    return CachedScheduleItem(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      date: data.date.present ? data.date.value : this.date,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      overlaps: data.overlaps.present ? data.overlaps.value : this.overlaps,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedScheduleItem(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('overlaps: $overlaps, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventId, date, startTime, endTime, title,
      description, imageUrl, sortOrder, overlaps, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedScheduleItem &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.date == this.date &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.title == this.title &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.sortOrder == this.sortOrder &&
          other.overlaps == this.overlaps &&
          other.syncedAt == this.syncedAt);
}

class CachedScheduleItemsCompanion extends UpdateCompanion<CachedScheduleItem> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<String> date;
  final Value<String> startTime;
  final Value<String> endTime;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> imageUrl;
  final Value<int> sortOrder;
  final Value<bool> overlaps;
  final Value<DateTime> syncedAt;
  const CachedScheduleItemsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.date = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.overlaps = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedScheduleItemsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required String date,
    required String startTime,
    required String endTime,
    required String title,
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.overlaps = const Value.absent(),
    required DateTime syncedAt,
  })  : eventId = Value(eventId),
        date = Value(date),
        startTime = Value(startTime),
        endTime = Value(endTime),
        title = Value(title),
        syncedAt = Value(syncedAt);
  static Insertable<CachedScheduleItem> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<String>? date,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<int>? sortOrder,
    Expression<bool>? overlaps,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (date != null) 'date': date,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (overlaps != null) 'overlaps': overlaps,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedScheduleItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<String>? date,
      Value<String>? startTime,
      Value<String>? endTime,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? imageUrl,
      Value<int>? sortOrder,
      Value<bool>? overlaps,
      Value<DateTime>? syncedAt}) {
    return CachedScheduleItemsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      overlaps: overlaps ?? this.overlaps,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (overlaps.present) {
      map['overlaps'] = Variable<bool>(overlaps.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedScheduleItemsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('overlaps: $overlaps, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedSponsorTicketsTable extends CachedSponsorTickets
    with TableInfo<$CachedSponsorTicketsTable, CachedSponsorTicket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSponsorTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sponsorUserIdMeta =
      const VerificationMeta('sponsorUserId');
  @override
  late final GeneratedColumn<int> sponsorUserId = GeneratedColumn<int>(
      'sponsor_user_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _receiptNumberMeta =
      const VerificationMeta('receiptNumber');
  @override
  late final GeneratedColumn<String> receiptNumber = GeneratedColumn<String>(
      'receipt_number', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _encryptedQrPayloadMeta =
      const VerificationMeta('encryptedQrPayload');
  @override
  late final GeneratedColumn<String> encryptedQrPayload =
      GeneratedColumn<String>('encrypted_qr_payload', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scannedAtMeta =
      const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<String> scannedAt = GeneratedColumn<String>(
      'scanned_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _eventTitleMeta =
      const VerificationMeta('eventTitle');
  @override
  late final GeneratedColumn<String> eventTitle = GeneratedColumn<String>(
      'event_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _eventStatusMeta =
      const VerificationMeta('eventStatus');
  @override
  late final GeneratedColumn<String> eventStatus = GeneratedColumn<String>(
      'event_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _eventStartTimeMeta =
      const VerificationMeta('eventStartTime');
  @override
  late final GeneratedColumn<String> eventStartTime = GeneratedColumn<String>(
      'event_start_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueNameMeta =
      const VerificationMeta('venueName');
  @override
  late final GeneratedColumn<String> venueName = GeneratedColumn<String>(
      'venue_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueAddressMeta =
      const VerificationMeta('venueAddress');
  @override
  late final GeneratedColumn<String> venueAddress = GeneratedColumn<String>(
      'venue_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _venueCityMeta =
      const VerificationMeta('venueCity');
  @override
  late final GeneratedColumn<String> venueCity = GeneratedColumn<String>(
      'venue_city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryCountMeta =
      const VerificationMeta('categoryCount');
  @override
  late final GeneratedColumn<int> categoryCount = GeneratedColumn<int>(
      'category_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _scanCountMeta =
      const VerificationMeta('scanCount');
  @override
  late final GeneratedColumn<int> scanCount = GeneratedColumn<int>(
      'scan_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _categoriesJsonMeta =
      const VerificationMeta('categoriesJson');
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
      'categories_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _categoryNamesJsonMeta =
      const VerificationMeta('categoryNamesJson');
  @override
  late final GeneratedColumn<String> categoryNamesJson =
      GeneratedColumn<String>('category_names_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        eventId,
        sponsorUserId,
        receiptNumber,
        encryptedQrPayload,
        scannedAt,
        createdAt,
        eventTitle,
        eventStatus,
        eventStartTime,
        venueName,
        venueAddress,
        venueCity,
        categoryCount,
        scanCount,
        categoriesJson,
        categoryNamesJson,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sponsor_tickets';
  @override
  VerificationContext validateIntegrity(
      Insertable<CachedSponsorTicket> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('sponsor_user_id')) {
      context.handle(
          _sponsorUserIdMeta,
          sponsorUserId.isAcceptableOrUnknown(
              data['sponsor_user_id']!, _sponsorUserIdMeta));
    } else if (isInserting) {
      context.missing(_sponsorUserIdMeta);
    }
    if (data.containsKey('receipt_number')) {
      context.handle(
          _receiptNumberMeta,
          receiptNumber.isAcceptableOrUnknown(
              data['receipt_number']!, _receiptNumberMeta));
    }
    if (data.containsKey('encrypted_qr_payload')) {
      context.handle(
          _encryptedQrPayloadMeta,
          encryptedQrPayload.isAcceptableOrUnknown(
              data['encrypted_qr_payload']!, _encryptedQrPayloadMeta));
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta,
          scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('event_title')) {
      context.handle(
          _eventTitleMeta,
          eventTitle.isAcceptableOrUnknown(
              data['event_title']!, _eventTitleMeta));
    }
    if (data.containsKey('event_status')) {
      context.handle(
          _eventStatusMeta,
          eventStatus.isAcceptableOrUnknown(
              data['event_status']!, _eventStatusMeta));
    }
    if (data.containsKey('event_start_time')) {
      context.handle(
          _eventStartTimeMeta,
          eventStartTime.isAcceptableOrUnknown(
              data['event_start_time']!, _eventStartTimeMeta));
    }
    if (data.containsKey('venue_name')) {
      context.handle(_venueNameMeta,
          venueName.isAcceptableOrUnknown(data['venue_name']!, _venueNameMeta));
    }
    if (data.containsKey('venue_address')) {
      context.handle(
          _venueAddressMeta,
          venueAddress.isAcceptableOrUnknown(
              data['venue_address']!, _venueAddressMeta));
    }
    if (data.containsKey('venue_city')) {
      context.handle(_venueCityMeta,
          venueCity.isAcceptableOrUnknown(data['venue_city']!, _venueCityMeta));
    }
    if (data.containsKey('category_count')) {
      context.handle(
          _categoryCountMeta,
          categoryCount.isAcceptableOrUnknown(
              data['category_count']!, _categoryCountMeta));
    }
    if (data.containsKey('scan_count')) {
      context.handle(_scanCountMeta,
          scanCount.isAcceptableOrUnknown(data['scan_count']!, _scanCountMeta));
    }
    if (data.containsKey('categories_json')) {
      context.handle(
          _categoriesJsonMeta,
          categoriesJson.isAcceptableOrUnknown(
              data['categories_json']!, _categoriesJsonMeta));
    }
    if (data.containsKey('category_names_json')) {
      context.handle(
          _categoryNamesJsonMeta,
          categoryNamesJson.isAcceptableOrUnknown(
              data['category_names_json']!, _categoryNamesJsonMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSponsorTicket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSponsorTicket(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      sponsorUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sponsor_user_id'])!,
      receiptNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receipt_number'])!,
      encryptedQrPayload: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}encrypted_qr_payload']),
      scannedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scanned_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at']),
      eventTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_title']),
      eventStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_status']),
      eventStartTime: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}event_start_time']),
      venueName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_name']),
      venueAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_address']),
      venueCity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}venue_city']),
      categoryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_count'])!,
      scanCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scan_count'])!,
      categoriesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}categories_json'])!,
      categoryNamesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}category_names_json'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedSponsorTicketsTable createAlias(String alias) {
    return $CachedSponsorTicketsTable(attachedDatabase, alias);
  }
}

class CachedSponsorTicket extends DataClass
    implements Insertable<CachedSponsorTicket> {
  final int id;
  final int eventId;
  final int sponsorUserId;
  final String receiptNumber;
  final String? encryptedQrPayload;
  final String? scannedAt;
  final String? createdAt;
  final String? eventTitle;
  final String? eventStatus;
  final String? eventStartTime;
  final String? venueName;
  final String? venueAddress;
  final String? venueCity;
  final int categoryCount;
  final int scanCount;
  final String categoriesJson;
  final String categoryNamesJson;
  final DateTime syncedAt;
  const CachedSponsorTicket(
      {required this.id,
      required this.eventId,
      required this.sponsorUserId,
      required this.receiptNumber,
      this.encryptedQrPayload,
      this.scannedAt,
      this.createdAt,
      this.eventTitle,
      this.eventStatus,
      this.eventStartTime,
      this.venueName,
      this.venueAddress,
      this.venueCity,
      required this.categoryCount,
      required this.scanCount,
      required this.categoriesJson,
      required this.categoryNamesJson,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['sponsor_user_id'] = Variable<int>(sponsorUserId);
    map['receipt_number'] = Variable<String>(receiptNumber);
    if (!nullToAbsent || encryptedQrPayload != null) {
      map['encrypted_qr_payload'] = Variable<String>(encryptedQrPayload);
    }
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<String>(scannedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || eventTitle != null) {
      map['event_title'] = Variable<String>(eventTitle);
    }
    if (!nullToAbsent || eventStatus != null) {
      map['event_status'] = Variable<String>(eventStatus);
    }
    if (!nullToAbsent || eventStartTime != null) {
      map['event_start_time'] = Variable<String>(eventStartTime);
    }
    if (!nullToAbsent || venueName != null) {
      map['venue_name'] = Variable<String>(venueName);
    }
    if (!nullToAbsent || venueAddress != null) {
      map['venue_address'] = Variable<String>(venueAddress);
    }
    if (!nullToAbsent || venueCity != null) {
      map['venue_city'] = Variable<String>(venueCity);
    }
    map['category_count'] = Variable<int>(categoryCount);
    map['scan_count'] = Variable<int>(scanCount);
    map['categories_json'] = Variable<String>(categoriesJson);
    map['category_names_json'] = Variable<String>(categoryNamesJson);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedSponsorTicketsCompanion toCompanion(bool nullToAbsent) {
    return CachedSponsorTicketsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      sponsorUserId: Value(sponsorUserId),
      receiptNumber: Value(receiptNumber),
      encryptedQrPayload: encryptedQrPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedQrPayload),
      scannedAt: scannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scannedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      eventTitle: eventTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTitle),
      eventStatus: eventStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(eventStatus),
      eventStartTime: eventStartTime == null && nullToAbsent
          ? const Value.absent()
          : Value(eventStartTime),
      venueName: venueName == null && nullToAbsent
          ? const Value.absent()
          : Value(venueName),
      venueAddress: venueAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(venueAddress),
      venueCity: venueCity == null && nullToAbsent
          ? const Value.absent()
          : Value(venueCity),
      categoryCount: Value(categoryCount),
      scanCount: Value(scanCount),
      categoriesJson: Value(categoriesJson),
      categoryNamesJson: Value(categoryNamesJson),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedSponsorTicket.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSponsorTicket(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      sponsorUserId: serializer.fromJson<int>(json['sponsorUserId']),
      receiptNumber: serializer.fromJson<String>(json['receiptNumber']),
      encryptedQrPayload:
          serializer.fromJson<String?>(json['encryptedQrPayload']),
      scannedAt: serializer.fromJson<String?>(json['scannedAt']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      eventTitle: serializer.fromJson<String?>(json['eventTitle']),
      eventStatus: serializer.fromJson<String?>(json['eventStatus']),
      eventStartTime: serializer.fromJson<String?>(json['eventStartTime']),
      venueName: serializer.fromJson<String?>(json['venueName']),
      venueAddress: serializer.fromJson<String?>(json['venueAddress']),
      venueCity: serializer.fromJson<String?>(json['venueCity']),
      categoryCount: serializer.fromJson<int>(json['categoryCount']),
      scanCount: serializer.fromJson<int>(json['scanCount']),
      categoriesJson: serializer.fromJson<String>(json['categoriesJson']),
      categoryNamesJson: serializer.fromJson<String>(json['categoryNamesJson']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'sponsorUserId': serializer.toJson<int>(sponsorUserId),
      'receiptNumber': serializer.toJson<String>(receiptNumber),
      'encryptedQrPayload': serializer.toJson<String?>(encryptedQrPayload),
      'scannedAt': serializer.toJson<String?>(scannedAt),
      'createdAt': serializer.toJson<String?>(createdAt),
      'eventTitle': serializer.toJson<String?>(eventTitle),
      'eventStatus': serializer.toJson<String?>(eventStatus),
      'eventStartTime': serializer.toJson<String?>(eventStartTime),
      'venueName': serializer.toJson<String?>(venueName),
      'venueAddress': serializer.toJson<String?>(venueAddress),
      'venueCity': serializer.toJson<String?>(venueCity),
      'categoryCount': serializer.toJson<int>(categoryCount),
      'scanCount': serializer.toJson<int>(scanCount),
      'categoriesJson': serializer.toJson<String>(categoriesJson),
      'categoryNamesJson': serializer.toJson<String>(categoryNamesJson),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedSponsorTicket copyWith(
          {int? id,
          int? eventId,
          int? sponsorUserId,
          String? receiptNumber,
          Value<String?> encryptedQrPayload = const Value.absent(),
          Value<String?> scannedAt = const Value.absent(),
          Value<String?> createdAt = const Value.absent(),
          Value<String?> eventTitle = const Value.absent(),
          Value<String?> eventStatus = const Value.absent(),
          Value<String?> eventStartTime = const Value.absent(),
          Value<String?> venueName = const Value.absent(),
          Value<String?> venueAddress = const Value.absent(),
          Value<String?> venueCity = const Value.absent(),
          int? categoryCount,
          int? scanCount,
          String? categoriesJson,
          String? categoryNamesJson,
          DateTime? syncedAt}) =>
      CachedSponsorTicket(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        sponsorUserId: sponsorUserId ?? this.sponsorUserId,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        encryptedQrPayload: encryptedQrPayload.present
            ? encryptedQrPayload.value
            : this.encryptedQrPayload,
        scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        eventTitle: eventTitle.present ? eventTitle.value : this.eventTitle,
        eventStatus: eventStatus.present ? eventStatus.value : this.eventStatus,
        eventStartTime:
            eventStartTime.present ? eventStartTime.value : this.eventStartTime,
        venueName: venueName.present ? venueName.value : this.venueName,
        venueAddress:
            venueAddress.present ? venueAddress.value : this.venueAddress,
        venueCity: venueCity.present ? venueCity.value : this.venueCity,
        categoryCount: categoryCount ?? this.categoryCount,
        scanCount: scanCount ?? this.scanCount,
        categoriesJson: categoriesJson ?? this.categoriesJson,
        categoryNamesJson: categoryNamesJson ?? this.categoryNamesJson,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedSponsorTicket copyWithCompanion(CachedSponsorTicketsCompanion data) {
    return CachedSponsorTicket(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      sponsorUserId: data.sponsorUserId.present
          ? data.sponsorUserId.value
          : this.sponsorUserId,
      receiptNumber: data.receiptNumber.present
          ? data.receiptNumber.value
          : this.receiptNumber,
      encryptedQrPayload: data.encryptedQrPayload.present
          ? data.encryptedQrPayload.value
          : this.encryptedQrPayload,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      eventTitle:
          data.eventTitle.present ? data.eventTitle.value : this.eventTitle,
      eventStatus:
          data.eventStatus.present ? data.eventStatus.value : this.eventStatus,
      eventStartTime: data.eventStartTime.present
          ? data.eventStartTime.value
          : this.eventStartTime,
      venueName: data.venueName.present ? data.venueName.value : this.venueName,
      venueAddress: data.venueAddress.present
          ? data.venueAddress.value
          : this.venueAddress,
      venueCity: data.venueCity.present ? data.venueCity.value : this.venueCity,
      categoryCount: data.categoryCount.present
          ? data.categoryCount.value
          : this.categoryCount,
      scanCount: data.scanCount.present ? data.scanCount.value : this.scanCount,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      categoryNamesJson: data.categoryNamesJson.present
          ? data.categoryNamesJson.value
          : this.categoryNamesJson,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSponsorTicket(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('sponsorUserId: $sponsorUserId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('encryptedQrPayload: $encryptedQrPayload, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('eventStatus: $eventStatus, ')
          ..write('eventStartTime: $eventStartTime, ')
          ..write('venueName: $venueName, ')
          ..write('venueAddress: $venueAddress, ')
          ..write('venueCity: $venueCity, ')
          ..write('categoryCount: $categoryCount, ')
          ..write('scanCount: $scanCount, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('categoryNamesJson: $categoryNamesJson, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      eventId,
      sponsorUserId,
      receiptNumber,
      encryptedQrPayload,
      scannedAt,
      createdAt,
      eventTitle,
      eventStatus,
      eventStartTime,
      venueName,
      venueAddress,
      venueCity,
      categoryCount,
      scanCount,
      categoriesJson,
      categoryNamesJson,
      syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSponsorTicket &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.sponsorUserId == this.sponsorUserId &&
          other.receiptNumber == this.receiptNumber &&
          other.encryptedQrPayload == this.encryptedQrPayload &&
          other.scannedAt == this.scannedAt &&
          other.createdAt == this.createdAt &&
          other.eventTitle == this.eventTitle &&
          other.eventStatus == this.eventStatus &&
          other.eventStartTime == this.eventStartTime &&
          other.venueName == this.venueName &&
          other.venueAddress == this.venueAddress &&
          other.venueCity == this.venueCity &&
          other.categoryCount == this.categoryCount &&
          other.scanCount == this.scanCount &&
          other.categoriesJson == this.categoriesJson &&
          other.categoryNamesJson == this.categoryNamesJson &&
          other.syncedAt == this.syncedAt);
}

class CachedSponsorTicketsCompanion
    extends UpdateCompanion<CachedSponsorTicket> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<int> sponsorUserId;
  final Value<String> receiptNumber;
  final Value<String?> encryptedQrPayload;
  final Value<String?> scannedAt;
  final Value<String?> createdAt;
  final Value<String?> eventTitle;
  final Value<String?> eventStatus;
  final Value<String?> eventStartTime;
  final Value<String?> venueName;
  final Value<String?> venueAddress;
  final Value<String?> venueCity;
  final Value<int> categoryCount;
  final Value<int> scanCount;
  final Value<String> categoriesJson;
  final Value<String> categoryNamesJson;
  final Value<DateTime> syncedAt;
  const CachedSponsorTicketsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.sponsorUserId = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.encryptedQrPayload = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.eventStatus = const Value.absent(),
    this.eventStartTime = const Value.absent(),
    this.venueName = const Value.absent(),
    this.venueAddress = const Value.absent(),
    this.venueCity = const Value.absent(),
    this.categoryCount = const Value.absent(),
    this.scanCount = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.categoryNamesJson = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedSponsorTicketsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required int sponsorUserId,
    this.receiptNumber = const Value.absent(),
    this.encryptedQrPayload = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.eventStatus = const Value.absent(),
    this.eventStartTime = const Value.absent(),
    this.venueName = const Value.absent(),
    this.venueAddress = const Value.absent(),
    this.venueCity = const Value.absent(),
    this.categoryCount = const Value.absent(),
    this.scanCount = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.categoryNamesJson = const Value.absent(),
    required DateTime syncedAt,
  })  : eventId = Value(eventId),
        sponsorUserId = Value(sponsorUserId),
        syncedAt = Value(syncedAt);
  static Insertable<CachedSponsorTicket> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<int>? sponsorUserId,
    Expression<String>? receiptNumber,
    Expression<String>? encryptedQrPayload,
    Expression<String>? scannedAt,
    Expression<String>? createdAt,
    Expression<String>? eventTitle,
    Expression<String>? eventStatus,
    Expression<String>? eventStartTime,
    Expression<String>? venueName,
    Expression<String>? venueAddress,
    Expression<String>? venueCity,
    Expression<int>? categoryCount,
    Expression<int>? scanCount,
    Expression<String>? categoriesJson,
    Expression<String>? categoryNamesJson,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (sponsorUserId != null) 'sponsor_user_id': sponsorUserId,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (encryptedQrPayload != null)
        'encrypted_qr_payload': encryptedQrPayload,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (eventTitle != null) 'event_title': eventTitle,
      if (eventStatus != null) 'event_status': eventStatus,
      if (eventStartTime != null) 'event_start_time': eventStartTime,
      if (venueName != null) 'venue_name': venueName,
      if (venueAddress != null) 'venue_address': venueAddress,
      if (venueCity != null) 'venue_city': venueCity,
      if (categoryCount != null) 'category_count': categoryCount,
      if (scanCount != null) 'scan_count': scanCount,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (categoryNamesJson != null) 'category_names_json': categoryNamesJson,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedSponsorTicketsCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<int>? sponsorUserId,
      Value<String>? receiptNumber,
      Value<String?>? encryptedQrPayload,
      Value<String?>? scannedAt,
      Value<String?>? createdAt,
      Value<String?>? eventTitle,
      Value<String?>? eventStatus,
      Value<String?>? eventStartTime,
      Value<String?>? venueName,
      Value<String?>? venueAddress,
      Value<String?>? venueCity,
      Value<int>? categoryCount,
      Value<int>? scanCount,
      Value<String>? categoriesJson,
      Value<String>? categoryNamesJson,
      Value<DateTime>? syncedAt}) {
    return CachedSponsorTicketsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      sponsorUserId: sponsorUserId ?? this.sponsorUserId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      encryptedQrPayload: encryptedQrPayload ?? this.encryptedQrPayload,
      scannedAt: scannedAt ?? this.scannedAt,
      createdAt: createdAt ?? this.createdAt,
      eventTitle: eventTitle ?? this.eventTitle,
      eventStatus: eventStatus ?? this.eventStatus,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      venueCity: venueCity ?? this.venueCity,
      categoryCount: categoryCount ?? this.categoryCount,
      scanCount: scanCount ?? this.scanCount,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      categoryNamesJson: categoryNamesJson ?? this.categoryNamesJson,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (sponsorUserId.present) {
      map['sponsor_user_id'] = Variable<int>(sponsorUserId.value);
    }
    if (receiptNumber.present) {
      map['receipt_number'] = Variable<String>(receiptNumber.value);
    }
    if (encryptedQrPayload.present) {
      map['encrypted_qr_payload'] = Variable<String>(encryptedQrPayload.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<String>(scannedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (eventTitle.present) {
      map['event_title'] = Variable<String>(eventTitle.value);
    }
    if (eventStatus.present) {
      map['event_status'] = Variable<String>(eventStatus.value);
    }
    if (eventStartTime.present) {
      map['event_start_time'] = Variable<String>(eventStartTime.value);
    }
    if (venueName.present) {
      map['venue_name'] = Variable<String>(venueName.value);
    }
    if (venueAddress.present) {
      map['venue_address'] = Variable<String>(venueAddress.value);
    }
    if (venueCity.present) {
      map['venue_city'] = Variable<String>(venueCity.value);
    }
    if (categoryCount.present) {
      map['category_count'] = Variable<int>(categoryCount.value);
    }
    if (scanCount.present) {
      map['scan_count'] = Variable<int>(scanCount.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (categoryNamesJson.present) {
      map['category_names_json'] = Variable<String>(categoryNamesJson.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSponsorTicketsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('sponsorUserId: $sponsorUserId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('encryptedQrPayload: $encryptedQrPayload, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('eventStatus: $eventStatus, ')
          ..write('eventStartTime: $eventStartTime, ')
          ..write('venueName: $venueName, ')
          ..write('venueAddress: $venueAddress, ')
          ..write('venueCity: $venueCity, ')
          ..write('categoryCount: $categoryCount, ')
          ..write('scanCount: $scanCount, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('categoryNamesJson: $categoryNamesJson, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedSponsorDelegatesTable extends CachedSponsorDelegates
    with TableInfo<$CachedSponsorDelegatesTable, CachedSponsorDelegate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSponsorDelegatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sponsorTicketIdMeta =
      const VerificationMeta('sponsorTicketId');
  @override
  late final GeneratedColumn<int> sponsorTicketId = GeneratedColumn<int>(
      'sponsor_ticket_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _checkedInMeta =
      const VerificationMeta('checkedIn');
  @override
  late final GeneratedColumn<bool> checkedIn = GeneratedColumn<bool>(
      'checked_in', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("checked_in" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _checkedInAtMeta =
      const VerificationMeta('checkedInAt');
  @override
  late final GeneratedColumn<String> checkedInAt = GeneratedColumn<String>(
      'checked_in_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sponsorTicketId,
        name,
        email,
        phone,
        checkedIn,
        checkedInAt,
        createdAt,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sponsor_delegates';
  @override
  VerificationContext validateIntegrity(
      Insertable<CachedSponsorDelegate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sponsor_ticket_id')) {
      context.handle(
          _sponsorTicketIdMeta,
          sponsorTicketId.isAcceptableOrUnknown(
              data['sponsor_ticket_id']!, _sponsorTicketIdMeta));
    } else if (isInserting) {
      context.missing(_sponsorTicketIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('checked_in')) {
      context.handle(_checkedInMeta,
          checkedIn.isAcceptableOrUnknown(data['checked_in']!, _checkedInMeta));
    }
    if (data.containsKey('checked_in_at')) {
      context.handle(
          _checkedInAtMeta,
          checkedInAt.isAcceptableOrUnknown(
              data['checked_in_at']!, _checkedInAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSponsorDelegate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSponsorDelegate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sponsorTicketId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sponsor_ticket_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      checkedIn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}checked_in'])!,
      checkedInAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}checked_in_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $CachedSponsorDelegatesTable createAlias(String alias) {
    return $CachedSponsorDelegatesTable(attachedDatabase, alias);
  }
}

class CachedSponsorDelegate extends DataClass
    implements Insertable<CachedSponsorDelegate> {
  final int id;
  final int sponsorTicketId;
  final String name;
  final String? email;
  final String? phone;
  final bool checkedIn;
  final String? checkedInAt;
  final String? createdAt;
  final DateTime syncedAt;
  const CachedSponsorDelegate(
      {required this.id,
      required this.sponsorTicketId,
      required this.name,
      this.email,
      this.phone,
      required this.checkedIn,
      this.checkedInAt,
      this.createdAt,
      required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sponsor_ticket_id'] = Variable<int>(sponsorTicketId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['checked_in'] = Variable<bool>(checkedIn);
    if (!nullToAbsent || checkedInAt != null) {
      map['checked_in_at'] = Variable<String>(checkedInAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedSponsorDelegatesCompanion toCompanion(bool nullToAbsent) {
    return CachedSponsorDelegatesCompanion(
      id: Value(id),
      sponsorTicketId: Value(sponsorTicketId),
      name: Value(name),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      checkedIn: Value(checkedIn),
      checkedInAt: checkedInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkedInAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedSponsorDelegate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSponsorDelegate(
      id: serializer.fromJson<int>(json['id']),
      sponsorTicketId: serializer.fromJson<int>(json['sponsorTicketId']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      checkedIn: serializer.fromJson<bool>(json['checkedIn']),
      checkedInAt: serializer.fromJson<String?>(json['checkedInAt']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sponsorTicketId': serializer.toJson<int>(sponsorTicketId),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'checkedIn': serializer.toJson<bool>(checkedIn),
      'checkedInAt': serializer.toJson<String?>(checkedInAt),
      'createdAt': serializer.toJson<String?>(createdAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedSponsorDelegate copyWith(
          {int? id,
          int? sponsorTicketId,
          String? name,
          Value<String?> email = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          bool? checkedIn,
          Value<String?> checkedInAt = const Value.absent(),
          Value<String?> createdAt = const Value.absent(),
          DateTime? syncedAt}) =>
      CachedSponsorDelegate(
        id: id ?? this.id,
        sponsorTicketId: sponsorTicketId ?? this.sponsorTicketId,
        name: name ?? this.name,
        email: email.present ? email.value : this.email,
        phone: phone.present ? phone.value : this.phone,
        checkedIn: checkedIn ?? this.checkedIn,
        checkedInAt: checkedInAt.present ? checkedInAt.value : this.checkedInAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  CachedSponsorDelegate copyWithCompanion(
      CachedSponsorDelegatesCompanion data) {
    return CachedSponsorDelegate(
      id: data.id.present ? data.id.value : this.id,
      sponsorTicketId: data.sponsorTicketId.present
          ? data.sponsorTicketId.value
          : this.sponsorTicketId,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      checkedIn: data.checkedIn.present ? data.checkedIn.value : this.checkedIn,
      checkedInAt:
          data.checkedInAt.present ? data.checkedInAt.value : this.checkedInAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSponsorDelegate(')
          ..write('id: $id, ')
          ..write('sponsorTicketId: $sponsorTicketId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('checkedIn: $checkedIn, ')
          ..write('checkedInAt: $checkedInAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sponsorTicketId, name, email, phone,
      checkedIn, checkedInAt, createdAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSponsorDelegate &&
          other.id == this.id &&
          other.sponsorTicketId == this.sponsorTicketId &&
          other.name == this.name &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.checkedIn == this.checkedIn &&
          other.checkedInAt == this.checkedInAt &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class CachedSponsorDelegatesCompanion
    extends UpdateCompanion<CachedSponsorDelegate> {
  final Value<int> id;
  final Value<int> sponsorTicketId;
  final Value<String> name;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<bool> checkedIn;
  final Value<String?> checkedInAt;
  final Value<String?> createdAt;
  final Value<DateTime> syncedAt;
  const CachedSponsorDelegatesCompanion({
    this.id = const Value.absent(),
    this.sponsorTicketId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.checkedIn = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  CachedSponsorDelegatesCompanion.insert({
    this.id = const Value.absent(),
    required int sponsorTicketId,
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.checkedIn = const Value.absent(),
    this.checkedInAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime syncedAt,
  })  : sponsorTicketId = Value(sponsorTicketId),
        syncedAt = Value(syncedAt);
  static Insertable<CachedSponsorDelegate> custom({
    Expression<int>? id,
    Expression<int>? sponsorTicketId,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<bool>? checkedIn,
    Expression<String>? checkedInAt,
    Expression<String>? createdAt,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sponsorTicketId != null) 'sponsor_ticket_id': sponsorTicketId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (checkedIn != null) 'checked_in': checkedIn,
      if (checkedInAt != null) 'checked_in_at': checkedInAt,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  CachedSponsorDelegatesCompanion copyWith(
      {Value<int>? id,
      Value<int>? sponsorTicketId,
      Value<String>? name,
      Value<String?>? email,
      Value<String?>? phone,
      Value<bool>? checkedIn,
      Value<String?>? checkedInAt,
      Value<String?>? createdAt,
      Value<DateTime>? syncedAt}) {
    return CachedSponsorDelegatesCompanion(
      id: id ?? this.id,
      sponsorTicketId: sponsorTicketId ?? this.sponsorTicketId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      checkedIn: checkedIn ?? this.checkedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sponsorTicketId.present) {
      map['sponsor_ticket_id'] = Variable<int>(sponsorTicketId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (checkedIn.present) {
      map['checked_in'] = Variable<bool>(checkedIn.value);
    }
    if (checkedInAt.present) {
      map['checked_in_at'] = Variable<String>(checkedInAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSponsorDelegatesCompanion(')
          ..write('id: $id, ')
          ..write('sponsorTicketId: $sponsorTicketId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('checkedIn: $checkedIn, ')
          ..write('checkedInAt: $checkedInAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncTableNameMeta =
      const VerificationMeta('syncTableName');
  @override
  late final GeneratedColumn<String> syncTableName = GeneratedColumn<String>(
      'sync_table_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncAtMeta =
      const VerificationMeta('lastSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
      'last_sync_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncCursorMeta =
      const VerificationMeta('lastSyncCursor');
  @override
  late final GeneratedColumn<String> lastSyncCursor = GeneratedColumn<String>(
      'last_sync_cursor', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [syncTableName, lastSyncAt, lastSyncCursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<SyncMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_table_name')) {
      context.handle(
          _syncTableNameMeta,
          syncTableName.isAcceptableOrUnknown(
              data['sync_table_name']!, _syncTableNameMeta));
    } else if (isInserting) {
      context.missing(_syncTableNameMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
          _lastSyncAtMeta,
          lastSyncAt.isAcceptableOrUnknown(
              data['last_sync_at']!, _lastSyncAtMeta));
    } else if (isInserting) {
      context.missing(_lastSyncAtMeta);
    }
    if (data.containsKey('last_sync_cursor')) {
      context.handle(
          _lastSyncCursorMeta,
          lastSyncCursor.isAcceptableOrUnknown(
              data['last_sync_cursor']!, _lastSyncCursorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncTableName};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      syncTableName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sync_table_name'])!,
      lastSyncAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_at'])!,
      lastSyncCursor: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_sync_cursor']),
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String syncTableName;
  final DateTime lastSyncAt;
  final String? lastSyncCursor;
  const SyncMetadataData(
      {required this.syncTableName,
      required this.lastSyncAt,
      this.lastSyncCursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_table_name'] = Variable<String>(syncTableName);
    map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    if (!nullToAbsent || lastSyncCursor != null) {
      map['last_sync_cursor'] = Variable<String>(lastSyncCursor);
    }
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      syncTableName: Value(syncTableName),
      lastSyncAt: Value(lastSyncAt),
      lastSyncCursor: lastSyncCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncCursor),
    );
  }

  factory SyncMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      syncTableName: serializer.fromJson<String>(json['syncTableName']),
      lastSyncAt: serializer.fromJson<DateTime>(json['lastSyncAt']),
      lastSyncCursor: serializer.fromJson<String?>(json['lastSyncCursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncTableName': serializer.toJson<String>(syncTableName),
      'lastSyncAt': serializer.toJson<DateTime>(lastSyncAt),
      'lastSyncCursor': serializer.toJson<String?>(lastSyncCursor),
    };
  }

  SyncMetadataData copyWith(
          {String? syncTableName,
          DateTime? lastSyncAt,
          Value<String?> lastSyncCursor = const Value.absent()}) =>
      SyncMetadataData(
        syncTableName: syncTableName ?? this.syncTableName,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastSyncCursor:
            lastSyncCursor.present ? lastSyncCursor.value : this.lastSyncCursor,
      );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      syncTableName: data.syncTableName.present
          ? data.syncTableName.value
          : this.syncTableName,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      lastSyncCursor: data.lastSyncCursor.present
          ? data.lastSyncCursor.value
          : this.lastSyncCursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('syncTableName: $syncTableName, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncCursor: $lastSyncCursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncTableName, lastSyncAt, lastSyncCursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.syncTableName == this.syncTableName &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastSyncCursor == this.lastSyncCursor);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> syncTableName;
  final Value<DateTime> lastSyncAt;
  final Value<String?> lastSyncCursor;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.syncTableName = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastSyncCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String syncTableName,
    required DateTime lastSyncAt,
    this.lastSyncCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : syncTableName = Value(syncTableName),
        lastSyncAt = Value(lastSyncAt);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? syncTableName,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastSyncCursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncTableName != null) 'sync_table_name': syncTableName,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastSyncCursor != null) 'last_sync_cursor': lastSyncCursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith(
      {Value<String>? syncTableName,
      Value<DateTime>? lastSyncAt,
      Value<String?>? lastSyncCursor,
      Value<int>? rowid}) {
    return SyncMetadataCompanion(
      syncTableName: syncTableName ?? this.syncTableName,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncCursor: lastSyncCursor ?? this.lastSyncCursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncTableName.present) {
      map['sync_table_name'] = Variable<String>(syncTableName.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastSyncCursor.present) {
      map['last_sync_cursor'] = Variable<String>(lastSyncCursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('syncTableName: $syncTableName, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncCursor: $lastSyncCursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedEventsTable cachedEvents = $CachedEventsTable(this);
  late final $CachedVenuesTable cachedVenues = $CachedVenuesTable(this);
  late final $CachedTicketTiersTable cachedTicketTiers =
      $CachedTicketTiersTable(this);
  late final $OfflineTicketsTable offlineTickets = $OfflineTicketsTable(this);
  late final $OfflineScansTable offlineScans = $OfflineScansTable(this);
  late final $CachedBookmarksTable cachedBookmarks =
      $CachedBookmarksTable(this);
  late final $CachedTransportTable cachedTransport =
      $CachedTransportTable(this);
  late final $CachedMyTicketsTable cachedMyTickets =
      $CachedMyTicketsTable(this);
  late final $CachedScheduleItemsTable cachedScheduleItems =
      $CachedScheduleItemsTable(this);
  late final $CachedSponsorTicketsTable cachedSponsorTickets =
      $CachedSponsorTicketsTable(this);
  late final $CachedSponsorDelegatesTable cachedSponsorDelegates =
      $CachedSponsorDelegatesTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cachedEvents,
        cachedVenues,
        cachedTicketTiers,
        offlineTickets,
        offlineScans,
        cachedBookmarks,
        cachedTransport,
        cachedMyTickets,
        cachedScheduleItems,
        cachedSponsorTickets,
        cachedSponsorDelegates,
        syncMetadata
      ];
}

typedef $$CachedEventsTableCreateCompanionBuilder = CachedEventsCompanion
    Function({
  Value<int> id,
  Value<String> title,
  Value<String?> description,
  Value<String?> genre,
  Value<String> status,
  Value<DateTime?> startTime,
  Value<DateTime?> endTime,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> venueName,
  Value<String?> city,
  Value<String?> firstImageUrl,
  Value<int?> fundingGoalCents,
  Value<int?> totalPledgedCents,
  Value<int?> ticketsSoldCount,
  required DateTime syncedAt,
});
typedef $$CachedEventsTableUpdateCompanionBuilder = CachedEventsCompanion
    Function({
  Value<int> id,
  Value<String> title,
  Value<String?> description,
  Value<String?> genre,
  Value<String> status,
  Value<DateTime?> startTime,
  Value<DateTime?> endTime,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> venueName,
  Value<String?> city,
  Value<String?> firstImageUrl,
  Value<int?> fundingGoalCents,
  Value<int?> totalPledgedCents,
  Value<int?> ticketsSoldCount,
  Value<DateTime> syncedAt,
});

class $$CachedEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedEventsTable> {
  $$CachedEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firstImageUrl => $composableBuilder(
      column: $table.firstImageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fundingGoalCents => $composableBuilder(
      column: $table.fundingGoalCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPledgedCents => $composableBuilder(
      column: $table.totalPledgedCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ticketsSoldCount => $composableBuilder(
      column: $table.ticketsSoldCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedEventsTable> {
  $$CachedEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firstImageUrl => $composableBuilder(
      column: $table.firstImageUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fundingGoalCents => $composableBuilder(
      column: $table.fundingGoalCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPledgedCents => $composableBuilder(
      column: $table.totalPledgedCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ticketsSoldCount => $composableBuilder(
      column: $table.ticketsSoldCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedEventsTable> {
  $$CachedEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get venueName =>
      $composableBuilder(column: $table.venueName, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get firstImageUrl => $composableBuilder(
      column: $table.firstImageUrl, builder: (column) => column);

  GeneratedColumn<int> get fundingGoalCents => $composableBuilder(
      column: $table.fundingGoalCents, builder: (column) => column);

  GeneratedColumn<int> get totalPledgedCents => $composableBuilder(
      column: $table.totalPledgedCents, builder: (column) => column);

  GeneratedColumn<int> get ticketsSoldCount => $composableBuilder(
      column: $table.ticketsSoldCount, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedEventsTable,
    CachedEvent,
    $$CachedEventsTableFilterComposer,
    $$CachedEventsTableOrderingComposer,
    $$CachedEventsTableAnnotationComposer,
    $$CachedEventsTableCreateCompanionBuilder,
    $$CachedEventsTableUpdateCompanionBuilder,
    (
      CachedEvent,
      BaseReferences<_$AppDatabase, $CachedEventsTable, CachedEvent>
    ),
    CachedEvent,
    PrefetchHooks Function()> {
  $$CachedEventsTableTableManager(_$AppDatabase db, $CachedEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> firstImageUrl = const Value.absent(),
            Value<int?> fundingGoalCents = const Value.absent(),
            Value<int?> totalPledgedCents = const Value.absent(),
            Value<int?> ticketsSoldCount = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedEventsCompanion(
            id: id,
            title: title,
            description: description,
            genre: genre,
            status: status,
            startTime: startTime,
            endTime: endTime,
            lat: lat,
            lng: lng,
            venueName: venueName,
            city: city,
            firstImageUrl: firstImageUrl,
            fundingGoalCents: fundingGoalCents,
            totalPledgedCents: totalPledgedCents,
            ticketsSoldCount: ticketsSoldCount,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> firstImageUrl = const Value.absent(),
            Value<int?> fundingGoalCents = const Value.absent(),
            Value<int?> totalPledgedCents = const Value.absent(),
            Value<int?> ticketsSoldCount = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              CachedEventsCompanion.insert(
            id: id,
            title: title,
            description: description,
            genre: genre,
            status: status,
            startTime: startTime,
            endTime: endTime,
            lat: lat,
            lng: lng,
            venueName: venueName,
            city: city,
            firstImageUrl: firstImageUrl,
            fundingGoalCents: fundingGoalCents,
            totalPledgedCents: totalPledgedCents,
            ticketsSoldCount: ticketsSoldCount,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedEventsTable,
    CachedEvent,
    $$CachedEventsTableFilterComposer,
    $$CachedEventsTableOrderingComposer,
    $$CachedEventsTableAnnotationComposer,
    $$CachedEventsTableCreateCompanionBuilder,
    $$CachedEventsTableUpdateCompanionBuilder,
    (
      CachedEvent,
      BaseReferences<_$AppDatabase, $CachedEventsTable, CachedEvent>
    ),
    CachedEvent,
    PrefetchHooks Function()>;
typedef $$CachedVenuesTableCreateCompanionBuilder = CachedVenuesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String?> address,
  Value<String?> city,
  Value<double?> lat,
  Value<double?> lng,
});
typedef $$CachedVenuesTableUpdateCompanionBuilder = CachedVenuesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String?> address,
  Value<String?> city,
  Value<double?> lat,
  Value<double?> lng,
});

class $$CachedVenuesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVenuesTable> {
  $$CachedVenuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));
}

class $$CachedVenuesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVenuesTable> {
  $$CachedVenuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));
}

class $$CachedVenuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVenuesTable> {
  $$CachedVenuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);
}

class $$CachedVenuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedVenuesTable,
    CachedVenue,
    $$CachedVenuesTableFilterComposer,
    $$CachedVenuesTableOrderingComposer,
    $$CachedVenuesTableAnnotationComposer,
    $$CachedVenuesTableCreateCompanionBuilder,
    $$CachedVenuesTableUpdateCompanionBuilder,
    (
      CachedVenue,
      BaseReferences<_$AppDatabase, $CachedVenuesTable, CachedVenue>
    ),
    CachedVenue,
    PrefetchHooks Function()> {
  $$CachedVenuesTableTableManager(_$AppDatabase db, $CachedVenuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVenuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVenuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVenuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
          }) =>
              CachedVenuesCompanion(
            id: id,
            name: name,
            address: address,
            city: city,
            lat: lat,
            lng: lng,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
          }) =>
              CachedVenuesCompanion.insert(
            id: id,
            name: name,
            address: address,
            city: city,
            lat: lat,
            lng: lng,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedVenuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedVenuesTable,
    CachedVenue,
    $$CachedVenuesTableFilterComposer,
    $$CachedVenuesTableOrderingComposer,
    $$CachedVenuesTableAnnotationComposer,
    $$CachedVenuesTableCreateCompanionBuilder,
    $$CachedVenuesTableUpdateCompanionBuilder,
    (
      CachedVenue,
      BaseReferences<_$AppDatabase, $CachedVenuesTable, CachedVenue>
    ),
    CachedVenue,
    PrefetchHooks Function()>;
typedef $$CachedTicketTiersTableCreateCompanionBuilder
    = CachedTicketTiersCompanion Function({
  Value<int> id,
  required int eventId,
  Value<String> name,
  Value<int> priceCents,
  Value<int?> maxReservedSpots,
  Value<int> displayOrder,
});
typedef $$CachedTicketTiersTableUpdateCompanionBuilder
    = CachedTicketTiersCompanion Function({
  Value<int> id,
  Value<int> eventId,
  Value<String> name,
  Value<int> priceCents,
  Value<int?> maxReservedSpots,
  Value<int> displayOrder,
});

class $$CachedTicketTiersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTicketTiersTable> {
  $$CachedTicketTiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxReservedSpots => $composableBuilder(
      column: $table.maxReservedSpots,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder, builder: (column) => ColumnFilters(column));
}

class $$CachedTicketTiersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTicketTiersTable> {
  $$CachedTicketTiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxReservedSpots => $composableBuilder(
      column: $table.maxReservedSpots,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder,
      builder: (column) => ColumnOrderings(column));
}

class $$CachedTicketTiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTicketTiersTable> {
  $$CachedTicketTiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => column);

  GeneratedColumn<int> get maxReservedSpots => $composableBuilder(
      column: $table.maxReservedSpots, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder, builder: (column) => column);
}

class $$CachedTicketTiersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedTicketTiersTable,
    CachedTicketTier,
    $$CachedTicketTiersTableFilterComposer,
    $$CachedTicketTiersTableOrderingComposer,
    $$CachedTicketTiersTableAnnotationComposer,
    $$CachedTicketTiersTableCreateCompanionBuilder,
    $$CachedTicketTiersTableUpdateCompanionBuilder,
    (
      CachedTicketTier,
      BaseReferences<_$AppDatabase, $CachedTicketTiersTable, CachedTicketTier>
    ),
    CachedTicketTier,
    PrefetchHooks Function()> {
  $$CachedTicketTiersTableTableManager(
      _$AppDatabase db, $CachedTicketTiersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTicketTiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTicketTiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTicketTiersTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> priceCents = const Value.absent(),
            Value<int?> maxReservedSpots = const Value.absent(),
            Value<int> displayOrder = const Value.absent(),
          }) =>
              CachedTicketTiersCompanion(
            id: id,
            eventId: eventId,
            name: name,
            priceCents: priceCents,
            maxReservedSpots: maxReservedSpots,
            displayOrder: displayOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            Value<String> name = const Value.absent(),
            Value<int> priceCents = const Value.absent(),
            Value<int?> maxReservedSpots = const Value.absent(),
            Value<int> displayOrder = const Value.absent(),
          }) =>
              CachedTicketTiersCompanion.insert(
            id: id,
            eventId: eventId,
            name: name,
            priceCents: priceCents,
            maxReservedSpots: maxReservedSpots,
            displayOrder: displayOrder,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedTicketTiersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedTicketTiersTable,
    CachedTicketTier,
    $$CachedTicketTiersTableFilterComposer,
    $$CachedTicketTiersTableOrderingComposer,
    $$CachedTicketTiersTableAnnotationComposer,
    $$CachedTicketTiersTableCreateCompanionBuilder,
    $$CachedTicketTiersTableUpdateCompanionBuilder,
    (
      CachedTicketTier,
      BaseReferences<_$AppDatabase, $CachedTicketTiersTable, CachedTicketTier>
    ),
    CachedTicketTier,
    PrefetchHooks Function()>;
typedef $$OfflineTicketsTableCreateCompanionBuilder = OfflineTicketsCompanion
    Function({
  Value<int> id,
  required int eventId,
  required String ticketCode,
  Value<int?> userId,
  Value<String?> userName,
  Value<String?> tierName,
  Value<String> status,
  Value<bool> scannedLocally,
  required DateTime syncedAt,
});
typedef $$OfflineTicketsTableUpdateCompanionBuilder = OfflineTicketsCompanion
    Function({
  Value<int> id,
  Value<int> eventId,
  Value<String> ticketCode,
  Value<int?> userId,
  Value<String?> userName,
  Value<String?> tierName,
  Value<String> status,
  Value<bool> scannedLocally,
  Value<DateTime> syncedAt,
});

class $$OfflineTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineTicketsTable> {
  $$OfflineTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tierName => $composableBuilder(
      column: $table.tierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get scannedLocally => $composableBuilder(
      column: $table.scannedLocally,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$OfflineTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineTicketsTable> {
  $$OfflineTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tierName => $composableBuilder(
      column: $table.tierName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get scannedLocally => $composableBuilder(
      column: $table.scannedLocally,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$OfflineTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineTicketsTable> {
  $$OfflineTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get tierName =>
      $composableBuilder(column: $table.tierName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get scannedLocally => $composableBuilder(
      column: $table.scannedLocally, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$OfflineTicketsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfflineTicketsTable,
    OfflineTicket,
    $$OfflineTicketsTableFilterComposer,
    $$OfflineTicketsTableOrderingComposer,
    $$OfflineTicketsTableAnnotationComposer,
    $$OfflineTicketsTableCreateCompanionBuilder,
    $$OfflineTicketsTableUpdateCompanionBuilder,
    (
      OfflineTicket,
      BaseReferences<_$AppDatabase, $OfflineTicketsTable, OfflineTicket>
    ),
    OfflineTicket,
    PrefetchHooks Function()> {
  $$OfflineTicketsTableTableManager(
      _$AppDatabase db, $OfflineTicketsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<String> ticketCode = const Value.absent(),
            Value<int?> userId = const Value.absent(),
            Value<String?> userName = const Value.absent(),
            Value<String?> tierName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> scannedLocally = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              OfflineTicketsCompanion(
            id: id,
            eventId: eventId,
            ticketCode: ticketCode,
            userId: userId,
            userName: userName,
            tierName: tierName,
            status: status,
            scannedLocally: scannedLocally,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            required String ticketCode,
            Value<int?> userId = const Value.absent(),
            Value<String?> userName = const Value.absent(),
            Value<String?> tierName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> scannedLocally = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              OfflineTicketsCompanion.insert(
            id: id,
            eventId: eventId,
            ticketCode: ticketCode,
            userId: userId,
            userName: userName,
            tierName: tierName,
            status: status,
            scannedLocally: scannedLocally,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfflineTicketsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfflineTicketsTable,
    OfflineTicket,
    $$OfflineTicketsTableFilterComposer,
    $$OfflineTicketsTableOrderingComposer,
    $$OfflineTicketsTableAnnotationComposer,
    $$OfflineTicketsTableCreateCompanionBuilder,
    $$OfflineTicketsTableUpdateCompanionBuilder,
    (
      OfflineTicket,
      BaseReferences<_$AppDatabase, $OfflineTicketsTable, OfflineTicket>
    ),
    OfflineTicket,
    PrefetchHooks Function()>;
typedef $$OfflineScansTableCreateCompanionBuilder = OfflineScansCompanion
    Function({
  Value<int> id,
  required String ticketCode,
  required int eventId,
  required DateTime scannedAt,
  required int scannedById,
  Value<bool> synced,
});
typedef $$OfflineScansTableUpdateCompanionBuilder = OfflineScansCompanion
    Function({
  Value<int> id,
  Value<String> ticketCode,
  Value<int> eventId,
  Value<DateTime> scannedAt,
  Value<int> scannedById,
  Value<bool> synced,
});

class $$OfflineScansTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineScansTable> {
  $$OfflineScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scannedById => $composableBuilder(
      column: $table.scannedById, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$OfflineScansTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineScansTable> {
  $$OfflineScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scannedById => $composableBuilder(
      column: $table.scannedById, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$OfflineScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineScansTable> {
  $$OfflineScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<int> get scannedById => $composableBuilder(
      column: $table.scannedById, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$OfflineScansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfflineScansTable,
    OfflineScan,
    $$OfflineScansTableFilterComposer,
    $$OfflineScansTableOrderingComposer,
    $$OfflineScansTableAnnotationComposer,
    $$OfflineScansTableCreateCompanionBuilder,
    $$OfflineScansTableUpdateCompanionBuilder,
    (
      OfflineScan,
      BaseReferences<_$AppDatabase, $OfflineScansTable, OfflineScan>
    ),
    OfflineScan,
    PrefetchHooks Function()> {
  $$OfflineScansTableTableManager(_$AppDatabase db, $OfflineScansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> ticketCode = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<DateTime> scannedAt = const Value.absent(),
            Value<int> scannedById = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              OfflineScansCompanion(
            id: id,
            ticketCode: ticketCode,
            eventId: eventId,
            scannedAt: scannedAt,
            scannedById: scannedById,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String ticketCode,
            required int eventId,
            required DateTime scannedAt,
            required int scannedById,
            Value<bool> synced = const Value.absent(),
          }) =>
              OfflineScansCompanion.insert(
            id: id,
            ticketCode: ticketCode,
            eventId: eventId,
            scannedAt: scannedAt,
            scannedById: scannedById,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfflineScansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfflineScansTable,
    OfflineScan,
    $$OfflineScansTableFilterComposer,
    $$OfflineScansTableOrderingComposer,
    $$OfflineScansTableAnnotationComposer,
    $$OfflineScansTableCreateCompanionBuilder,
    $$OfflineScansTableUpdateCompanionBuilder,
    (
      OfflineScan,
      BaseReferences<_$AppDatabase, $OfflineScansTable, OfflineScan>
    ),
    OfflineScan,
    PrefetchHooks Function()>;
typedef $$CachedBookmarksTableCreateCompanionBuilder = CachedBookmarksCompanion
    Function({
  Value<int> eventId,
  required DateTime syncedAt,
});
typedef $$CachedBookmarksTableUpdateCompanionBuilder = CachedBookmarksCompanion
    Function({
  Value<int> eventId,
  Value<DateTime> syncedAt,
});

class $$CachedBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $CachedBookmarksTable> {
  $$CachedBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedBookmarksTable> {
  $$CachedBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedBookmarksTable> {
  $$CachedBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedBookmarksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedBookmarksTable,
    CachedBookmark,
    $$CachedBookmarksTableFilterComposer,
    $$CachedBookmarksTableOrderingComposer,
    $$CachedBookmarksTableAnnotationComposer,
    $$CachedBookmarksTableCreateCompanionBuilder,
    $$CachedBookmarksTableUpdateCompanionBuilder,
    (
      CachedBookmark,
      BaseReferences<_$AppDatabase, $CachedBookmarksTable, CachedBookmark>
    ),
    CachedBookmark,
    PrefetchHooks Function()> {
  $$CachedBookmarksTableTableManager(
      _$AppDatabase db, $CachedBookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> eventId = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedBookmarksCompanion(
            eventId: eventId,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> eventId = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              CachedBookmarksCompanion.insert(
            eventId: eventId,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedBookmarksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedBookmarksTable,
    CachedBookmark,
    $$CachedBookmarksTableFilterComposer,
    $$CachedBookmarksTableOrderingComposer,
    $$CachedBookmarksTableAnnotationComposer,
    $$CachedBookmarksTableCreateCompanionBuilder,
    $$CachedBookmarksTableUpdateCompanionBuilder,
    (
      CachedBookmark,
      BaseReferences<_$AppDatabase, $CachedBookmarksTable, CachedBookmark>
    ),
    CachedBookmark,
    PrefetchHooks Function()>;
typedef $$CachedTransportTableCreateCompanionBuilder = CachedTransportCompanion
    Function({
  Value<int> eventId,
  Value<String?> parkingInfo,
  Value<String?> transitInfo,
  Value<String?> rideshareInfo,
  Value<String?> accessibilityInfo,
  Value<String?> directionsUrl,
});
typedef $$CachedTransportTableUpdateCompanionBuilder = CachedTransportCompanion
    Function({
  Value<int> eventId,
  Value<String?> parkingInfo,
  Value<String?> transitInfo,
  Value<String?> rideshareInfo,
  Value<String?> accessibilityInfo,
  Value<String?> directionsUrl,
});

class $$CachedTransportTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTransportTable> {
  $$CachedTransportTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parkingInfo => $composableBuilder(
      column: $table.parkingInfo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transitInfo => $composableBuilder(
      column: $table.transitInfo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rideshareInfo => $composableBuilder(
      column: $table.rideshareInfo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accessibilityInfo => $composableBuilder(
      column: $table.accessibilityInfo,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directionsUrl => $composableBuilder(
      column: $table.directionsUrl, builder: (column) => ColumnFilters(column));
}

class $$CachedTransportTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTransportTable> {
  $$CachedTransportTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parkingInfo => $composableBuilder(
      column: $table.parkingInfo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transitInfo => $composableBuilder(
      column: $table.transitInfo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rideshareInfo => $composableBuilder(
      column: $table.rideshareInfo,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accessibilityInfo => $composableBuilder(
      column: $table.accessibilityInfo,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directionsUrl => $composableBuilder(
      column: $table.directionsUrl,
      builder: (column) => ColumnOrderings(column));
}

class $$CachedTransportTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTransportTable> {
  $$CachedTransportTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get parkingInfo => $composableBuilder(
      column: $table.parkingInfo, builder: (column) => column);

  GeneratedColumn<String> get transitInfo => $composableBuilder(
      column: $table.transitInfo, builder: (column) => column);

  GeneratedColumn<String> get rideshareInfo => $composableBuilder(
      column: $table.rideshareInfo, builder: (column) => column);

  GeneratedColumn<String> get accessibilityInfo => $composableBuilder(
      column: $table.accessibilityInfo, builder: (column) => column);

  GeneratedColumn<String> get directionsUrl => $composableBuilder(
      column: $table.directionsUrl, builder: (column) => column);
}

class $$CachedTransportTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedTransportTable,
    CachedTransportData,
    $$CachedTransportTableFilterComposer,
    $$CachedTransportTableOrderingComposer,
    $$CachedTransportTableAnnotationComposer,
    $$CachedTransportTableCreateCompanionBuilder,
    $$CachedTransportTableUpdateCompanionBuilder,
    (
      CachedTransportData,
      BaseReferences<_$AppDatabase, $CachedTransportTable, CachedTransportData>
    ),
    CachedTransportData,
    PrefetchHooks Function()> {
  $$CachedTransportTableTableManager(
      _$AppDatabase db, $CachedTransportTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTransportTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTransportTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTransportTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> eventId = const Value.absent(),
            Value<String?> parkingInfo = const Value.absent(),
            Value<String?> transitInfo = const Value.absent(),
            Value<String?> rideshareInfo = const Value.absent(),
            Value<String?> accessibilityInfo = const Value.absent(),
            Value<String?> directionsUrl = const Value.absent(),
          }) =>
              CachedTransportCompanion(
            eventId: eventId,
            parkingInfo: parkingInfo,
            transitInfo: transitInfo,
            rideshareInfo: rideshareInfo,
            accessibilityInfo: accessibilityInfo,
            directionsUrl: directionsUrl,
          ),
          createCompanionCallback: ({
            Value<int> eventId = const Value.absent(),
            Value<String?> parkingInfo = const Value.absent(),
            Value<String?> transitInfo = const Value.absent(),
            Value<String?> rideshareInfo = const Value.absent(),
            Value<String?> accessibilityInfo = const Value.absent(),
            Value<String?> directionsUrl = const Value.absent(),
          }) =>
              CachedTransportCompanion.insert(
            eventId: eventId,
            parkingInfo: parkingInfo,
            transitInfo: transitInfo,
            rideshareInfo: rideshareInfo,
            accessibilityInfo: accessibilityInfo,
            directionsUrl: directionsUrl,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedTransportTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedTransportTable,
    CachedTransportData,
    $$CachedTransportTableFilterComposer,
    $$CachedTransportTableOrderingComposer,
    $$CachedTransportTableAnnotationComposer,
    $$CachedTransportTableCreateCompanionBuilder,
    $$CachedTransportTableUpdateCompanionBuilder,
    (
      CachedTransportData,
      BaseReferences<_$AppDatabase, $CachedTransportTable, CachedTransportData>
    ),
    CachedTransportData,
    PrefetchHooks Function()>;
typedef $$CachedMyTicketsTableCreateCompanionBuilder = CachedMyTicketsCompanion
    Function({
  Value<int> id,
  required int eventId,
  required int userId,
  required String ticketCode,
  Value<String?> receiptNumber,
  Value<String?> tierName,
  Value<String?> eventTitle,
  Value<int> amountPaidCents,
  Value<int> discountAppliedCents,
  Value<String> status,
  Value<DateTime?> scannedAt,
  Value<String?> encryptedQrPayload,
  required DateTime createdAt,
  required DateTime syncedAt,
});
typedef $$CachedMyTicketsTableUpdateCompanionBuilder = CachedMyTicketsCompanion
    Function({
  Value<int> id,
  Value<int> eventId,
  Value<int> userId,
  Value<String> ticketCode,
  Value<String?> receiptNumber,
  Value<String?> tierName,
  Value<String?> eventTitle,
  Value<int> amountPaidCents,
  Value<int> discountAppliedCents,
  Value<String> status,
  Value<DateTime?> scannedAt,
  Value<String?> encryptedQrPayload,
  Value<DateTime> createdAt,
  Value<DateTime> syncedAt,
});

class $$CachedMyTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMyTicketsTable> {
  $$CachedMyTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tierName => $composableBuilder(
      column: $table.tierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountPaidCents => $composableBuilder(
      column: $table.amountPaidCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get discountAppliedCents => $composableBuilder(
      column: $table.discountAppliedCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedMyTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMyTicketsTable> {
  $$CachedMyTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tierName => $composableBuilder(
      column: $table.tierName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountPaidCents => $composableBuilder(
      column: $table.amountPaidCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get discountAppliedCents => $composableBuilder(
      column: $table.discountAppliedCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedMyTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMyTicketsTable> {
  $$CachedMyTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get ticketCode => $composableBuilder(
      column: $table.ticketCode, builder: (column) => column);

  GeneratedColumn<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => column);

  GeneratedColumn<String> get tierName =>
      $composableBuilder(column: $table.tierName, builder: (column) => column);

  GeneratedColumn<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => column);

  GeneratedColumn<int> get amountPaidCents => $composableBuilder(
      column: $table.amountPaidCents, builder: (column) => column);

  GeneratedColumn<int> get discountAppliedCents => $composableBuilder(
      column: $table.discountAppliedCents, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedMyTicketsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMyTicketsTable,
    CachedMyTicket,
    $$CachedMyTicketsTableFilterComposer,
    $$CachedMyTicketsTableOrderingComposer,
    $$CachedMyTicketsTableAnnotationComposer,
    $$CachedMyTicketsTableCreateCompanionBuilder,
    $$CachedMyTicketsTableUpdateCompanionBuilder,
    (
      CachedMyTicket,
      BaseReferences<_$AppDatabase, $CachedMyTicketsTable, CachedMyTicket>
    ),
    CachedMyTicket,
    PrefetchHooks Function()> {
  $$CachedMyTicketsTableTableManager(
      _$AppDatabase db, $CachedMyTicketsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMyTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMyTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMyTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<int> userId = const Value.absent(),
            Value<String> ticketCode = const Value.absent(),
            Value<String?> receiptNumber = const Value.absent(),
            Value<String?> tierName = const Value.absent(),
            Value<String?> eventTitle = const Value.absent(),
            Value<int> amountPaidCents = const Value.absent(),
            Value<int> discountAppliedCents = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> scannedAt = const Value.absent(),
            Value<String?> encryptedQrPayload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedMyTicketsCompanion(
            id: id,
            eventId: eventId,
            userId: userId,
            ticketCode: ticketCode,
            receiptNumber: receiptNumber,
            tierName: tierName,
            eventTitle: eventTitle,
            amountPaidCents: amountPaidCents,
            discountAppliedCents: discountAppliedCents,
            status: status,
            scannedAt: scannedAt,
            encryptedQrPayload: encryptedQrPayload,
            createdAt: createdAt,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            required int userId,
            required String ticketCode,
            Value<String?> receiptNumber = const Value.absent(),
            Value<String?> tierName = const Value.absent(),
            Value<String?> eventTitle = const Value.absent(),
            Value<int> amountPaidCents = const Value.absent(),
            Value<int> discountAppliedCents = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> scannedAt = const Value.absent(),
            Value<String?> encryptedQrPayload = const Value.absent(),
            required DateTime createdAt,
            required DateTime syncedAt,
          }) =>
              CachedMyTicketsCompanion.insert(
            id: id,
            eventId: eventId,
            userId: userId,
            ticketCode: ticketCode,
            receiptNumber: receiptNumber,
            tierName: tierName,
            eventTitle: eventTitle,
            amountPaidCents: amountPaidCents,
            discountAppliedCents: discountAppliedCents,
            status: status,
            scannedAt: scannedAt,
            encryptedQrPayload: encryptedQrPayload,
            createdAt: createdAt,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMyTicketsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedMyTicketsTable,
    CachedMyTicket,
    $$CachedMyTicketsTableFilterComposer,
    $$CachedMyTicketsTableOrderingComposer,
    $$CachedMyTicketsTableAnnotationComposer,
    $$CachedMyTicketsTableCreateCompanionBuilder,
    $$CachedMyTicketsTableUpdateCompanionBuilder,
    (
      CachedMyTicket,
      BaseReferences<_$AppDatabase, $CachedMyTicketsTable, CachedMyTicket>
    ),
    CachedMyTicket,
    PrefetchHooks Function()>;
typedef $$CachedScheduleItemsTableCreateCompanionBuilder
    = CachedScheduleItemsCompanion Function({
  Value<int> id,
  required int eventId,
  required String date,
  required String startTime,
  required String endTime,
  required String title,
  Value<String?> description,
  Value<String?> imageUrl,
  Value<int> sortOrder,
  Value<bool> overlaps,
  required DateTime syncedAt,
});
typedef $$CachedScheduleItemsTableUpdateCompanionBuilder
    = CachedScheduleItemsCompanion Function({
  Value<int> id,
  Value<int> eventId,
  Value<String> date,
  Value<String> startTime,
  Value<String> endTime,
  Value<String> title,
  Value<String?> description,
  Value<String?> imageUrl,
  Value<int> sortOrder,
  Value<bool> overlaps,
  Value<DateTime> syncedAt,
});

class $$CachedScheduleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedScheduleItemsTable> {
  $$CachedScheduleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get overlaps => $composableBuilder(
      column: $table.overlaps, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedScheduleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedScheduleItemsTable> {
  $$CachedScheduleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get overlaps => $composableBuilder(
      column: $table.overlaps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedScheduleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedScheduleItemsTable> {
  $$CachedScheduleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get overlaps =>
      $composableBuilder(column: $table.overlaps, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedScheduleItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedScheduleItemsTable,
    CachedScheduleItem,
    $$CachedScheduleItemsTableFilterComposer,
    $$CachedScheduleItemsTableOrderingComposer,
    $$CachedScheduleItemsTableAnnotationComposer,
    $$CachedScheduleItemsTableCreateCompanionBuilder,
    $$CachedScheduleItemsTableUpdateCompanionBuilder,
    (
      CachedScheduleItem,
      BaseReferences<_$AppDatabase, $CachedScheduleItemsTable,
          CachedScheduleItem>
    ),
    CachedScheduleItem,
    PrefetchHooks Function()> {
  $$CachedScheduleItemsTableTableManager(
      _$AppDatabase db, $CachedScheduleItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedScheduleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedScheduleItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedScheduleItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<String> startTime = const Value.absent(),
            Value<String> endTime = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> overlaps = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedScheduleItemsCompanion(
            id: id,
            eventId: eventId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            title: title,
            description: description,
            imageUrl: imageUrl,
            sortOrder: sortOrder,
            overlaps: overlaps,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            required String date,
            required String startTime,
            required String endTime,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> overlaps = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              CachedScheduleItemsCompanion.insert(
            id: id,
            eventId: eventId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            title: title,
            description: description,
            imageUrl: imageUrl,
            sortOrder: sortOrder,
            overlaps: overlaps,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedScheduleItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedScheduleItemsTable,
    CachedScheduleItem,
    $$CachedScheduleItemsTableFilterComposer,
    $$CachedScheduleItemsTableOrderingComposer,
    $$CachedScheduleItemsTableAnnotationComposer,
    $$CachedScheduleItemsTableCreateCompanionBuilder,
    $$CachedScheduleItemsTableUpdateCompanionBuilder,
    (
      CachedScheduleItem,
      BaseReferences<_$AppDatabase, $CachedScheduleItemsTable,
          CachedScheduleItem>
    ),
    CachedScheduleItem,
    PrefetchHooks Function()>;
typedef $$CachedSponsorTicketsTableCreateCompanionBuilder
    = CachedSponsorTicketsCompanion Function({
  Value<int> id,
  required int eventId,
  required int sponsorUserId,
  Value<String> receiptNumber,
  Value<String?> encryptedQrPayload,
  Value<String?> scannedAt,
  Value<String?> createdAt,
  Value<String?> eventTitle,
  Value<String?> eventStatus,
  Value<String?> eventStartTime,
  Value<String?> venueName,
  Value<String?> venueAddress,
  Value<String?> venueCity,
  Value<int> categoryCount,
  Value<int> scanCount,
  Value<String> categoriesJson,
  Value<String> categoryNamesJson,
  required DateTime syncedAt,
});
typedef $$CachedSponsorTicketsTableUpdateCompanionBuilder
    = CachedSponsorTicketsCompanion Function({
  Value<int> id,
  Value<int> eventId,
  Value<int> sponsorUserId,
  Value<String> receiptNumber,
  Value<String?> encryptedQrPayload,
  Value<String?> scannedAt,
  Value<String?> createdAt,
  Value<String?> eventTitle,
  Value<String?> eventStatus,
  Value<String?> eventStartTime,
  Value<String?> venueName,
  Value<String?> venueAddress,
  Value<String?> venueCity,
  Value<int> categoryCount,
  Value<int> scanCount,
  Value<String> categoriesJson,
  Value<String> categoryNamesJson,
  Value<DateTime> syncedAt,
});

class $$CachedSponsorTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSponsorTicketsTable> {
  $$CachedSponsorTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sponsorUserId => $composableBuilder(
      column: $table.sponsorUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventStatus => $composableBuilder(
      column: $table.eventStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventStartTime => $composableBuilder(
      column: $table.eventStartTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueAddress => $composableBuilder(
      column: $table.venueAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get venueCity => $composableBuilder(
      column: $table.venueCity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryCount => $composableBuilder(
      column: $table.categoryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scanCount => $composableBuilder(
      column: $table.scanCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoriesJson => $composableBuilder(
      column: $table.categoriesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryNamesJson => $composableBuilder(
      column: $table.categoryNamesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedSponsorTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSponsorTicketsTable> {
  $$CachedSponsorTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sponsorUserId => $composableBuilder(
      column: $table.sponsorUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventStatus => $composableBuilder(
      column: $table.eventStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventStartTime => $composableBuilder(
      column: $table.eventStartTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueName => $composableBuilder(
      column: $table.venueName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueAddress => $composableBuilder(
      column: $table.venueAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get venueCity => $composableBuilder(
      column: $table.venueCity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryCount => $composableBuilder(
      column: $table.categoryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scanCount => $composableBuilder(
      column: $table.scanCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
      column: $table.categoriesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryNamesJson => $composableBuilder(
      column: $table.categoryNamesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedSponsorTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSponsorTicketsTable> {
  $$CachedSponsorTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get sponsorUserId => $composableBuilder(
      column: $table.sponsorUserId, builder: (column) => column);

  GeneratedColumn<String> get receiptNumber => $composableBuilder(
      column: $table.receiptNumber, builder: (column) => column);

  GeneratedColumn<String> get encryptedQrPayload => $composableBuilder(
      column: $table.encryptedQrPayload, builder: (column) => column);

  GeneratedColumn<String> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get eventTitle => $composableBuilder(
      column: $table.eventTitle, builder: (column) => column);

  GeneratedColumn<String> get eventStatus => $composableBuilder(
      column: $table.eventStatus, builder: (column) => column);

  GeneratedColumn<String> get eventStartTime => $composableBuilder(
      column: $table.eventStartTime, builder: (column) => column);

  GeneratedColumn<String> get venueName =>
      $composableBuilder(column: $table.venueName, builder: (column) => column);

  GeneratedColumn<String> get venueAddress => $composableBuilder(
      column: $table.venueAddress, builder: (column) => column);

  GeneratedColumn<String> get venueCity =>
      $composableBuilder(column: $table.venueCity, builder: (column) => column);

  GeneratedColumn<int> get categoryCount => $composableBuilder(
      column: $table.categoryCount, builder: (column) => column);

  GeneratedColumn<int> get scanCount =>
      $composableBuilder(column: $table.scanCount, builder: (column) => column);

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
      column: $table.categoriesJson, builder: (column) => column);

  GeneratedColumn<String> get categoryNamesJson => $composableBuilder(
      column: $table.categoryNamesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedSponsorTicketsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedSponsorTicketsTable,
    CachedSponsorTicket,
    $$CachedSponsorTicketsTableFilterComposer,
    $$CachedSponsorTicketsTableOrderingComposer,
    $$CachedSponsorTicketsTableAnnotationComposer,
    $$CachedSponsorTicketsTableCreateCompanionBuilder,
    $$CachedSponsorTicketsTableUpdateCompanionBuilder,
    (
      CachedSponsorTicket,
      BaseReferences<_$AppDatabase, $CachedSponsorTicketsTable,
          CachedSponsorTicket>
    ),
    CachedSponsorTicket,
    PrefetchHooks Function()> {
  $$CachedSponsorTicketsTableTableManager(
      _$AppDatabase db, $CachedSponsorTicketsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSponsorTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSponsorTicketsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSponsorTicketsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<int> sponsorUserId = const Value.absent(),
            Value<String> receiptNumber = const Value.absent(),
            Value<String?> encryptedQrPayload = const Value.absent(),
            Value<String?> scannedAt = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<String?> eventTitle = const Value.absent(),
            Value<String?> eventStatus = const Value.absent(),
            Value<String?> eventStartTime = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> venueAddress = const Value.absent(),
            Value<String?> venueCity = const Value.absent(),
            Value<int> categoryCount = const Value.absent(),
            Value<int> scanCount = const Value.absent(),
            Value<String> categoriesJson = const Value.absent(),
            Value<String> categoryNamesJson = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedSponsorTicketsCompanion(
            id: id,
            eventId: eventId,
            sponsorUserId: sponsorUserId,
            receiptNumber: receiptNumber,
            encryptedQrPayload: encryptedQrPayload,
            scannedAt: scannedAt,
            createdAt: createdAt,
            eventTitle: eventTitle,
            eventStatus: eventStatus,
            eventStartTime: eventStartTime,
            venueName: venueName,
            venueAddress: venueAddress,
            venueCity: venueCity,
            categoryCount: categoryCount,
            scanCount: scanCount,
            categoriesJson: categoriesJson,
            categoryNamesJson: categoryNamesJson,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            required int sponsorUserId,
            Value<String> receiptNumber = const Value.absent(),
            Value<String?> encryptedQrPayload = const Value.absent(),
            Value<String?> scannedAt = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<String?> eventTitle = const Value.absent(),
            Value<String?> eventStatus = const Value.absent(),
            Value<String?> eventStartTime = const Value.absent(),
            Value<String?> venueName = const Value.absent(),
            Value<String?> venueAddress = const Value.absent(),
            Value<String?> venueCity = const Value.absent(),
            Value<int> categoryCount = const Value.absent(),
            Value<int> scanCount = const Value.absent(),
            Value<String> categoriesJson = const Value.absent(),
            Value<String> categoryNamesJson = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              CachedSponsorTicketsCompanion.insert(
            id: id,
            eventId: eventId,
            sponsorUserId: sponsorUserId,
            receiptNumber: receiptNumber,
            encryptedQrPayload: encryptedQrPayload,
            scannedAt: scannedAt,
            createdAt: createdAt,
            eventTitle: eventTitle,
            eventStatus: eventStatus,
            eventStartTime: eventStartTime,
            venueName: venueName,
            venueAddress: venueAddress,
            venueCity: venueCity,
            categoryCount: categoryCount,
            scanCount: scanCount,
            categoriesJson: categoriesJson,
            categoryNamesJson: categoryNamesJson,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedSponsorTicketsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CachedSponsorTicketsTable,
        CachedSponsorTicket,
        $$CachedSponsorTicketsTableFilterComposer,
        $$CachedSponsorTicketsTableOrderingComposer,
        $$CachedSponsorTicketsTableAnnotationComposer,
        $$CachedSponsorTicketsTableCreateCompanionBuilder,
        $$CachedSponsorTicketsTableUpdateCompanionBuilder,
        (
          CachedSponsorTicket,
          BaseReferences<_$AppDatabase, $CachedSponsorTicketsTable,
              CachedSponsorTicket>
        ),
        CachedSponsorTicket,
        PrefetchHooks Function()>;
typedef $$CachedSponsorDelegatesTableCreateCompanionBuilder
    = CachedSponsorDelegatesCompanion Function({
  Value<int> id,
  required int sponsorTicketId,
  Value<String> name,
  Value<String?> email,
  Value<String?> phone,
  Value<bool> checkedIn,
  Value<String?> checkedInAt,
  Value<String?> createdAt,
  required DateTime syncedAt,
});
typedef $$CachedSponsorDelegatesTableUpdateCompanionBuilder
    = CachedSponsorDelegatesCompanion Function({
  Value<int> id,
  Value<int> sponsorTicketId,
  Value<String> name,
  Value<String?> email,
  Value<String?> phone,
  Value<bool> checkedIn,
  Value<String?> checkedInAt,
  Value<String?> createdAt,
  Value<DateTime> syncedAt,
});

class $$CachedSponsorDelegatesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSponsorDelegatesTable> {
  $$CachedSponsorDelegatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sponsorTicketId => $composableBuilder(
      column: $table.sponsorTicketId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkedIn => $composableBuilder(
      column: $table.checkedIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get checkedInAt => $composableBuilder(
      column: $table.checkedInAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedSponsorDelegatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSponsorDelegatesTable> {
  $$CachedSponsorDelegatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sponsorTicketId => $composableBuilder(
      column: $table.sponsorTicketId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkedIn => $composableBuilder(
      column: $table.checkedIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get checkedInAt => $composableBuilder(
      column: $table.checkedInAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedSponsorDelegatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSponsorDelegatesTable> {
  $$CachedSponsorDelegatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sponsorTicketId => $composableBuilder(
      column: $table.sponsorTicketId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<bool> get checkedIn =>
      $composableBuilder(column: $table.checkedIn, builder: (column) => column);

  GeneratedColumn<String> get checkedInAt => $composableBuilder(
      column: $table.checkedInAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedSponsorDelegatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedSponsorDelegatesTable,
    CachedSponsorDelegate,
    $$CachedSponsorDelegatesTableFilterComposer,
    $$CachedSponsorDelegatesTableOrderingComposer,
    $$CachedSponsorDelegatesTableAnnotationComposer,
    $$CachedSponsorDelegatesTableCreateCompanionBuilder,
    $$CachedSponsorDelegatesTableUpdateCompanionBuilder,
    (
      CachedSponsorDelegate,
      BaseReferences<_$AppDatabase, $CachedSponsorDelegatesTable,
          CachedSponsorDelegate>
    ),
    CachedSponsorDelegate,
    PrefetchHooks Function()> {
  $$CachedSponsorDelegatesTableTableManager(
      _$AppDatabase db, $CachedSponsorDelegatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSponsorDelegatesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSponsorDelegatesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSponsorDelegatesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sponsorTicketId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<bool> checkedIn = const Value.absent(),
            Value<String?> checkedInAt = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
          }) =>
              CachedSponsorDelegatesCompanion(
            id: id,
            sponsorTicketId: sponsorTicketId,
            name: name,
            email: email,
            phone: phone,
            checkedIn: checkedIn,
            checkedInAt: checkedInAt,
            createdAt: createdAt,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sponsorTicketId,
            Value<String> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<bool> checkedIn = const Value.absent(),
            Value<String?> checkedInAt = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            required DateTime syncedAt,
          }) =>
              CachedSponsorDelegatesCompanion.insert(
            id: id,
            sponsorTicketId: sponsorTicketId,
            name: name,
            email: email,
            phone: phone,
            checkedIn: checkedIn,
            checkedInAt: checkedInAt,
            createdAt: createdAt,
            syncedAt: syncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedSponsorDelegatesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CachedSponsorDelegatesTable,
        CachedSponsorDelegate,
        $$CachedSponsorDelegatesTableFilterComposer,
        $$CachedSponsorDelegatesTableOrderingComposer,
        $$CachedSponsorDelegatesTableAnnotationComposer,
        $$CachedSponsorDelegatesTableCreateCompanionBuilder,
        $$CachedSponsorDelegatesTableUpdateCompanionBuilder,
        (
          CachedSponsorDelegate,
          BaseReferences<_$AppDatabase, $CachedSponsorDelegatesTable,
              CachedSponsorDelegate>
        ),
        CachedSponsorDelegate,
        PrefetchHooks Function()>;
typedef $$SyncMetadataTableCreateCompanionBuilder = SyncMetadataCompanion
    Function({
  required String syncTableName,
  required DateTime lastSyncAt,
  Value<String?> lastSyncCursor,
  Value<int> rowid,
});
typedef $$SyncMetadataTableUpdateCompanionBuilder = SyncMetadataCompanion
    Function({
  Value<String> syncTableName,
  Value<DateTime> lastSyncAt,
  Value<String?> lastSyncCursor,
  Value<int> rowid,
});

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncTableName => $composableBuilder(
      column: $table.syncTableName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastSyncCursor => $composableBuilder(
      column: $table.lastSyncCursor,
      builder: (column) => ColumnFilters(column));
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncTableName => $composableBuilder(
      column: $table.syncTableName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastSyncCursor => $composableBuilder(
      column: $table.lastSyncCursor,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncTableName => $composableBuilder(
      column: $table.syncTableName, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => column);

  GeneratedColumn<String> get lastSyncCursor => $composableBuilder(
      column: $table.lastSyncCursor, builder: (column) => column);
}

class $$SyncMetadataTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()> {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncTableName = const Value.absent(),
            Value<DateTime> lastSyncAt = const Value.absent(),
            Value<String?> lastSyncCursor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion(
            syncTableName: syncTableName,
            lastSyncAt: lastSyncAt,
            lastSyncCursor: lastSyncCursor,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String syncTableName,
            required DateTime lastSyncAt,
            Value<String?> lastSyncCursor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion.insert(
            syncTableName: syncTableName,
            lastSyncAt: lastSyncAt,
            lastSyncCursor: lastSyncCursor,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncMetadataTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedEventsTableTableManager get cachedEvents =>
      $$CachedEventsTableTableManager(_db, _db.cachedEvents);
  $$CachedVenuesTableTableManager get cachedVenues =>
      $$CachedVenuesTableTableManager(_db, _db.cachedVenues);
  $$CachedTicketTiersTableTableManager get cachedTicketTiers =>
      $$CachedTicketTiersTableTableManager(_db, _db.cachedTicketTiers);
  $$OfflineTicketsTableTableManager get offlineTickets =>
      $$OfflineTicketsTableTableManager(_db, _db.offlineTickets);
  $$OfflineScansTableTableManager get offlineScans =>
      $$OfflineScansTableTableManager(_db, _db.offlineScans);
  $$CachedBookmarksTableTableManager get cachedBookmarks =>
      $$CachedBookmarksTableTableManager(_db, _db.cachedBookmarks);
  $$CachedTransportTableTableManager get cachedTransport =>
      $$CachedTransportTableTableManager(_db, _db.cachedTransport);
  $$CachedMyTicketsTableTableManager get cachedMyTickets =>
      $$CachedMyTicketsTableTableManager(_db, _db.cachedMyTickets);
  $$CachedScheduleItemsTableTableManager get cachedScheduleItems =>
      $$CachedScheduleItemsTableTableManager(_db, _db.cachedScheduleItems);
  $$CachedSponsorTicketsTableTableManager get cachedSponsorTickets =>
      $$CachedSponsorTicketsTableTableManager(_db, _db.cachedSponsorTickets);
  $$CachedSponsorDelegatesTableTableManager get cachedSponsorDelegates =>
      $$CachedSponsorDelegatesTableTableManager(
          _db, _db.cachedSponsorDelegates);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
