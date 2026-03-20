// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/user_menu.dart';
import 'login_screen.dart';
import 'friends_screen.dart';
import '../services/api_service.dart';
import '../models/planmate_event.dart';
import '../theme/theme_extensions.dart';
import '../services/calendar_sync_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String? firstName;

  const HomeScreen({super.key, required this.username, this.firstName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  Map<DateTime, List<PlanmateEvent>> _events = {};
  bool _isLoadingEvents = false;
  List<dynamic> _myFriends = [];
  List<int> _selectedFriendIds = [];

  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDescController = TextEditingController();
  
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  String _formatDateForBackend(DateTime date) {
    String y = date.year.toString().padLeft(4, '0');
    String m = date.month.toString().padLeft(2, '0');
    String d = date.day.toString().padLeft(2, '0');
    String h = date.hour.toString().padLeft(2, '0');
    String min = date.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $h:$min:00"; 
  }

  String _formatTimeForUI(DateTime date) {
    return TimeOfDay.fromDateTime(date).format(context);
  }

  String _formatDateForApi(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 00:00:00";
  }

  // --- FETCH EVENTS BY RANGE ---
  Future<void> _fetchEventsForMonth(DateTime month, {bool hideSpinner = false}) async {
    if (!hideSpinner) setState(() => _isLoadingEvents = true);

    try {
      DateTime start = DateTime(month.year, month.month - 1, 15);
      DateTime end = DateTime(month.year, month.month + 1, 15);

      String startStr = _formatDateForApi(start);
      String endStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} 23:59:59";

      List<PlanmateEvent> allEvents = [];

      // 1. Try to fetch Planmate events
      try {
        final response = await ApiService.getSecure('/events/range?start=$startStr&end=$endStr');
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          for (var item in data) {
            allEvents.add(PlanmateEvent.fromJson(item));
          }
        }
      } catch (e) {
        print("Planmate Fetch Error: $e");
      }

      // 2. Try to fetch Device (Google/Apple) events
      try {
        final syncService = CalendarSyncService();
        final deviceEvents = await syncService.fetchDeviceEvents(start, end);
        allEvents.addAll(deviceEvents);
      } catch (e) {
        print("Device Sync Error: $e");
      }

      // 3. Group EVERYTHING into the map once
      Map<DateTime, List<PlanmateEvent>> groupedEvents = {};
      for (var event in allEvents) {
        DateTime normalizedDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        if (groupedEvents[normalizedDate] == null) {
          groupedEvents[normalizedDate] = [];
        }
        groupedEvents[normalizedDate]!.add(event);
      }

      setState(() {
        _events = groupedEvents;
      });
      
    } catch (e) {
      print('General Fetch Error: $e');
    } finally {
      if (!hideSpinner) setState(() => _isLoadingEvents = false);
    }
  }

  Color _getEventColor(PlanmateEvent event, BuildContext context) {
    final eventColors = Theme.of(context).extension<EventColors>()!;
    
    if (event.creatorUsername == "Google") return eventColors.googleEvent!;
    if (event.creatorUsername == "Apple") return eventColors.appleEvent!;
    if (event.creatorUsername == "Samsung") return eventColors.samsungEvent!;
    
    return event.creatorUsername == widget.username 
        ? eventColors.myEvent! 
        : eventColors.inviteEvent!;
  }

  Widget _buildEventLeadingIcon(PlanmateEvent event, Color baseColor) {
    final eventColors = Theme.of(context).extension<EventColors>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (event.creatorUsername == "Google") {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: SvgPicture.asset(
            isDarkMode 
              ? 'assets/icons/android_dark_rd_na.svg' 
              : 'assets/icons/android_light_rd_na.svg',
            semanticsLabel: 'Google Logo',
          ),
        ),
      );
    }

    if (event.creatorUsername == "Apple") {
      return Icon(Icons.apple, color: eventColors?.appleEvent ?? baseColor, size: 28);
    }

    return Icon(Icons.event, color: baseColor);
  }

  Future<void> _fetchMyFriends() async {
    try {
      print("Fetching friends for invite list...");
      final response = await ApiService.getSecure('/friends/list');
      
      if (response.statusCode == 200) {
        final List<dynamic> allFriendships = jsonDecode(response.body);
        List<dynamic> acceptedFriends = [];

        for (var f in allFriendships) {
          if (f['status'] != null && (f['status'] as String).toUpperCase() == 'ACCEPTED') {
            
            final aEmail = f['userA']['email'];
            final aUsername = f['userA']['username'];
            
            if (aEmail == widget.username || aUsername == widget.username) {
              acceptedFriends.add(f['userB']);
            } else {
              acceptedFriends.add(f['userA']);
            }
          }
        }
        
        print("Found ${acceptedFriends.length} accepted friends!");
        setState(() => _myFriends = acceptedFriends);
      } else {
        print("Backend returned an error: ${response.statusCode}");
      }
    } catch (e) {
      print("Crash while fetching friends: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchEventsForMonth(_focusedDay);
    _fetchMyFriends();
  }

  List<PlanmateEvent> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  // --- 2. CREATE EVENT ---
  Future<void> _createEvent() async {
    if (_eventTitleController.text.isEmpty) return;

    final selectedDate = _selectedDay ?? DateTime.now();
    final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, _startTime.hour, _startTime.minute);
    final endDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, _endTime.hour, _endTime.minute);

    try {
      final response = await ApiService.postSecure('/events', {
          'title': _eventTitleController.text,
          'description': _eventDescController.text,
          'startTime': _formatDateForBackend(startDateTime),
          'endTime': _formatDateForBackend(endDateTime),
          'participantIds': _selectedFriendIds,
        });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context);
        _fetchEventsForMonth(_focusedDay);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created!'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // --- 3. UPDATE EVENT ---
  Future<void> _updateEvent(int eventId) async {
    if (_eventTitleController.text.isEmpty) return;

    final selectedDate = _selectedDay ?? DateTime.now();
    final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, _startTime.hour, _startTime.minute);
    final endDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, _endTime.hour, _endTime.minute);

    try {
      final response = await ApiService.putSecure('/events/$eventId', {
          'id': eventId,
          'title': _eventTitleController.text,
          'description': _eventDescController.text,
          'startTime': _formatDateForBackend(startDateTime),
          'endTime': _formatDateForBackend(endDateTime),
          'participantIds': _selectedFriendIds,
        });

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context);
        _fetchEventsForMonth(_focusedDay);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated!'), backgroundColor: Colors.blue));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // --- 4. DELETE EVENT (WITH CONFIRMATION) ---
  Future<void> _deleteEvent(int eventId) async {
    try {
      final response = await ApiService.deleteSecure('/events/$eventId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchEventsForMonth(_focusedDay);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted!'), backgroundColor: Colors.redAccent));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // The Warning Pop-up before deleting
  void _confirmDelete(int eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('Are you sure you want to permanently delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteEvent(eventId);  // Execute delete
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- 5. THE SMART BOTTOM SHEET (HANDLES BOTH CREATE & EDIT) ---
  void _showEventSheet({PlanmateEvent? eventToEdit}) {
    final isEditMode = eventToEdit != null;
    final isMine = eventToEdit == null || eventToEdit.creatorUsername == widget.username;
    String friendSearchQuery = '';

    if (isEditMode) {
      _eventTitleController.text = eventToEdit.title;
      _eventDescController.text = eventToEdit.description;
      _startTime = TimeOfDay.fromDateTime(eventToEdit.startTime);
      _endTime = TimeOfDay.fromDateTime(eventToEdit.endTime);
      _selectedFriendIds = eventToEdit.participants.map<int>((p) => p['id'] as int).toList();
    } else {
      _eventTitleController.clear();
      _eventDescController.clear();
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      _selectedFriendIds = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // IMPORTANT: TabController must wrap the StatefulBuilder so tabs don't reset on text input!
        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              
              Future<void> selectTime(bool isStart) async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: isStart ? _startTime : _endTime,
                );
                if (picked != null) {
                  setModalState(() {
                    if (isStart) _startTime = picked;
                    else _endTime = picked;
                  });
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24, right: 24, top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEditMode ? 'Edit Event' : 'Add New Event', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // --- THE TAB BAR ---
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                        Tab(icon: Icon(Icons.people_outline), text: 'Invites'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- THE TAB CONTENT ---
                    SizedBox(
                      height: 280, 
                      child: TabBarView(
                        children: [
                          // ====== TAB 1: DETAILS ======
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _eventTitleController,
                                  decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
                                  autofocus: !isEditMode,
                                  readOnly: !isMine,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => selectTime(true),
                                        icon: const Icon(Icons.access_time),
                                        label: Text('Start: ${_startTime.format(context)}'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => selectTime(false),
                                        icon: const Icon(Icons.access_time),
                                        label: Text('End: ${_endTime.format(context)}'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _eventDescController,
                                  decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                                  maxLines: 2,
                                  readOnly: !isMine,
                                ),
                                if (!isMine) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.person, color: Colors.grey, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Created by ${eventToEdit!.creatorUsername}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // ====== TAB 2: INVITES ======
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              if (_myFriends.isEmpty)
                                const Expanded(child: Center(child: Text('You have no friends to invite.', style: TextStyle(color: Colors.grey))))
                              else ...[
                                TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Search friends...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      friendSearchQuery = value.toLowerCase();
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final filteredFriends = _myFriends.where((friend) {
                                        
                                        if (isEditMode && friend['username'] == eventToEdit!.creatorUsername) {
                                          return false;
                                        }

                                        final name = (friend['firstName'] ?? friend['username']).toString().toLowerCase();
                                        final email = (friend['email']).toString().toLowerCase();
                                        return name.contains(friendSearchQuery) || email.contains(friendSearchQuery);
                                      }).toList();

                                      if (filteredFriends.isEmpty) {
                                        return const Center(child: Text('No friends found.', style: TextStyle(color: Colors.grey)));
                                      }

                                      return ListView.builder(
                                        itemCount: filteredFriends.length,
                                        itemBuilder: (context, index) {
                                          final friend = filteredFriends[index];
                                          final friendId = friend['id'] as int;
                                          final isSelected = _selectedFriendIds.contains(friendId);

                                          return CheckboxListTile(
                                            dense: true,
                                            title: Text(friend['firstName'] ?? friend['username']),
                                            subtitle: Text(friend['email'], style: const TextStyle(fontSize: 12)),
                                            value: isSelected,
                                            activeColor: Theme.of(context).colorScheme.primary,
                                            onChanged: (bool? checked) {
                                              setModalState(() {
                                                if (checked == true) {
                                                  _selectedFriendIds.add(friendId);
                                                } else {
                                                  _selectedFriendIds.remove(friendId);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      );
                                    }
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- ALWAYS VISIBLE ACTION BUTTONS ---
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => isEditMode ? _updateEvent(eventToEdit!.id) : _createEvent(),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: Text(isEditMode ? 'Update Event' : 'Save Event', style: const TextStyle(fontSize: 16)),
                    ),
                    
                    if (isEditMode && isMine) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(eventToEdit!.id);
                        },
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: const Text('Delete Event', style: TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = (widget.firstName != null && widget.firstName!.trim().isNotEmpty)
        ? widget.firstName!
        : widget.username;

    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
        appBar: AppBar(
            title: const Text('Planmate'),
            actions: [
            Center(
                child: Text(
                'Hello, $displayName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
            ),
            
            UserMenu(
              displayName: displayName,
              onLogout: _logout,
              onProfile: () => print("Navigate to Profile"),
              
              onFriends: () async {

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendsScreen(currentUserEmail: widget.username), 
                  ),
                );
                
                _fetchMyFriends();
                _fetchEventsForMonth(_focusedDay);
              },
              
              onSettings: () => print("Navigate to Settings"),
            ),
            const SizedBox(width: 8),
            ],
        ),
        body: Column(
          children: [
            // --- 1. THE INTERACTIVE CALENDAR GRID ---
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              
              // This is the magic that puts dots under days with events!
              eventLoader: (day) {
                // Normalize the day to midnight to match our map keys
                DateTime normalized = DateTime(day.year, day.month, day.day);
                return _events[normalized] ?? [];
              },
              
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),

              calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox.shrink();

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(4).map((event) {
                      final planmateEvent = event as PlanmateEvent;
                      final dotColor = _getEventColor(planmateEvent, context);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              
              // Handle Swiping to a new Month
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchEventsForMonth(focusedDay); 
              },
            ),

            const Divider(height: 1),

            // --- 2. THE EVENT LIST FOR THE SELECTED DAY ---
            Expanded(
              child: _isLoadingEvents
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _fetchEventsForMonth(_focusedDay, hideSpinner: true),
                      child: Builder(
                        builder: (context) {
                          // Get the events for the currently tapped day
                          DateTime normalizedSelected = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                          List<PlanmateEvent> dayEvents = _events[normalizedSelected] ?? [];

                          if (dayEvents.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                                Center(child: Text('No events for this day.', style: TextStyle(color: Colors.grey.shade600))),
                              ],
                            );
                          }

                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: dayEvents.length,
                            itemBuilder: (context, index) {
                              final event = dayEvents[index];
                              final timeString = "${event.startTime.hour}:${event.startTime.minute.toString().padLeft(2, '0')} - ${event.endTime.hour}:${event.endTime.minute.toString().padLeft(2, '0')}";
                              
                              final eventColors = Theme.of(context).extension<EventColors>()!;
                              final isMine = event.creatorUsername == widget.username;
                              final baseColor = _getEventColor(event, context);
                              final cardBackgroundColor = baseColor.withOpacity(0.15);

                              return Card(
                                color: cardBackgroundColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: baseColor.withOpacity(0.5), width: 1),
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: _buildEventLeadingIcon(event, baseColor),
                                  title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(timeString),
                                  onTap: () => _showEventSheet(eventToEdit: event),
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventSheet(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}