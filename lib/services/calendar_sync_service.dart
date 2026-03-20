import 'package:device_calendar/device_calendar.dart';
import '../models/planmate_event.dart';

class CalendarSyncService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<List<PlanmateEvent>> fetchDeviceEvents(DateTime start, DateTime end) async {
    List<PlanmateEvent> deviceEvents = [];

    try {
      // Check and request permissions
      //var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      //if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      //  permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      //  if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
      //    print("Calendar permission denied.");
      //    return []; 
      //  }
      //}
      // FORCE request every time just for testing
      var permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
          print("FORCED CHECK: Permission is actually DENIED");
          return []; 
      }

      print('Looking for 3rd party calendar apps...');
      // Get all calendars on the device
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        print('No calendars found');
        return [];
      }
      print(calendarsResult.data);

      for (var calendar in calendarsResult.data!) {
        print("Found Calendar: ${calendar.name} - Account: ${calendar.accountName}");
        // Identify the source (Google, Apple, Samsung)
        String sourceName = "Device";
        final accName = calendar.accountName?.toLowerCase() ?? '';
        final accType = calendar.accountType?.toLowerCase() ?? '';

        if (accName.contains('gmail') || accType.contains('google')) {
          sourceName = "Google";
        } else if (accName.contains('icloud') || accType.contains('apple') || accType.contains('local')) {
          sourceName = "Apple";
        } else if (accType.contains('samsung')) {
          sourceName = "Samsung";
        }

        // Fetch the events for this specific calendar within the month
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        print("Events found in ${calendar.name}: ${eventsResult.data?.length ?? 0}");

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (var e in eventsResult.data!) {
            if (e.start != null && e.end != null) {
              // Map the native event directly into your Planmate model!
              deviceEvents.add(PlanmateEvent(
                // Use hashCode to convert the native String ID into an int
                id: e.eventId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
                title: e.title ?? 'Busy',
                description: e.description ?? '',
                startTime: e.start!.toLocal(),
                endTime: e.end!.toLocal(),
                creatorUsername: sourceName,
                participants: [],
              ));
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching device events: $e");
    }

    return deviceEvents;
  }
}