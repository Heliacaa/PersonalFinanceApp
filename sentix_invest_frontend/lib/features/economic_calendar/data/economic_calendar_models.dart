class EconomicEvent {
  final String date;
  final String time;
  final String country;
  final String event;
  final String impact; // LOW, MEDIUM, HIGH
  final String? forecast;
  final String? previous;
  final String? actual;

  EconomicEvent({
    required this.date,
    required this.time,
    required this.country,
    required this.event,
    required this.impact,
    this.forecast,
    this.previous,
    this.actual,
  });

  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    return EconomicEvent(
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      country: json['country'] ?? '',
      event: json['event'] ?? '',
      impact: json['impact'] ?? 'MEDIUM',
      forecast: json['forecast'],
      previous: json['previous'],
      actual: json['actual'],
    );
  }
}

class EconomicCalendarResponse {
  final List<EconomicEvent> events;
  final String fromDate;
  final String toDate;

  EconomicCalendarResponse({
    required this.events,
    required this.fromDate,
    required this.toDate,
  });

  factory EconomicCalendarResponse.fromJson(Map<String, dynamic> json) {
    return EconomicCalendarResponse(
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => EconomicEvent.fromJson(e))
              .toList() ??
          [],
      fromDate: json['fromDate'] ?? '',
      toDate: json['toDate'] ?? '',
    );
  }
}
