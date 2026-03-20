class PlanmateEvent {
  final int id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String creatorUsername;
  final List<dynamic> participants;

  PlanmateEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.creatorUsername,
    required this.participants,
  });

  factory PlanmateEvent.fromJson(Map<String, dynamic> json) {
    return PlanmateEvent(
      id: json['id'] as int,
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      creatorUsername: json['user'] != null ? json['user']['username'] : '',
      participants: json['participants'] ?? [],
    );
  }
}