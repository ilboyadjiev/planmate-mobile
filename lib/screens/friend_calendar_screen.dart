import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/planmate_event.dart';

class FriendCalendarScreen extends StatefulWidget {
  final String friendName;
  final String friendUsername;

  const FriendCalendarScreen({
    super.key, 
    required this.friendName, 
    required this.friendUsername
  });

  @override
  State<FriendCalendarScreen> createState() => _FriendCalendarScreenState();
}

class _FriendCalendarScreenState extends State<FriendCalendarScreen> {
  Map<DateTime, List<PlanmateEvent>> _groupedEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriendEvents();
  }

  Future<void> _fetchFriendEvents() async {
    try {
      final response = await ApiService.getSecure('/events/username/${widget.friendUsername}');

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        List<PlanmateEvent> fetchedEvents = rawData.map((item) => PlanmateEvent.fromJson(item)).toList();

        fetchedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

        Map<DateTime, List<PlanmateEvent>> tempGrouped = {};
        
        for (var event in fetchedEvents) {
          DateTime startDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
          DateTime endDate = DateTime(event.endTime.year, event.endTime.month, event.endTime.day);

          DateTime currentDay = startDate;
          
          while (!currentDay.isAfter(endDate)) {
            if (tempGrouped[currentDay] == null) {
              tempGrouped[currentDay] = [];
            }
            tempGrouped[currentDay]!.add(event);
            
            currentDay = currentDay.add(const Duration(days: 1));
          }
        }

        setState(() {
          _groupedEvents = tempGrouped;
          _isLoading = false;
        });
      } else {
        _showError('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  String _formatDateHeader(DateTime date) {
    return "${date.month}/${date.day}/${date.year}"; 
  }

  String _formatEventTime(DateTime start, DateTime end) {
    final startStr = "${start.hour}:${start.minute.toString().padLeft(2, '0')}";
    final endStr = "${end.hour}:${end.minute.toString().padLeft(2, '0')}";
    
    bool isMultiDay = start.year != end.year || start.month != end.month || start.day != end.day;

    if (!isMultiDay) {
      return "$startStr - $endStr";
    } else {
      return "$startStr (${start.month}/${start.day}) to $endStr (${end.month}/${end.day})";
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _groupedEvents.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.friendName}'s Calendar"),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _groupedEvents.isEmpty
          ? Center(child: Text('${widget.friendName} has no events yet.', style: const TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final dateKey = days[index];
                final dayEvents = _groupedEvents[dateKey]!;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DATE HEADER
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          _formatDateHeader(dateKey),
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      
                      // We map over the events for this specific day and generate a Card for each
                      ...dayEvents.map((event) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            leading: const Icon(Icons.event, color: Colors.blue),
                            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                // Only showing the time now!
                                Text(_formatEventTime(event.startTime, event.endTime)),
                                if (event.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(event.description, style: const TextStyle(fontStyle: FontStyle.italic)),
                                ]
                              ],
                            ),
                            isThreeLine: event.description.isNotEmpty,
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}