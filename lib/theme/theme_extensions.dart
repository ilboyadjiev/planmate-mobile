// lib/theme/theme_extensions.dart
import 'package:flutter/material.dart';

class EventColors extends ThemeExtension<EventColors> {
  final Color? myEvent;
  final Color? inviteEvent;
  final Color? googleEvent;
  final Color? appleEvent;
  final Color? samsungEvent;

  const EventColors({
    this.myEvent,
    this.inviteEvent,
    this.googleEvent,
    this.appleEvent,
    this.samsungEvent,
  });

  @override
  EventColors copyWith({
    Color? myEvent,
    Color? inviteEvent,
    Color? googleEvent,
    Color? appleEvent,
    Color? samsungEvent,
  }) {
    return EventColors(
      myEvent: myEvent ?? this.myEvent,
      inviteEvent: inviteEvent ?? this.inviteEvent,
      googleEvent: googleEvent ?? this.googleEvent,
      appleEvent: appleEvent ?? this.appleEvent,
      samsungEvent: samsungEvent ?? this.samsungEvent,
    );
  }

  @override
  EventColors lerp(ThemeExtension<EventColors>? other, double t) {
    if (other is! EventColors) return this;
    return EventColors(
      myEvent: Color.lerp(myEvent, other.myEvent, t),
      inviteEvent: Color.lerp(inviteEvent, other.inviteEvent, t),
      googleEvent: Color.lerp(googleEvent, other.googleEvent, t),
      appleEvent: Color.lerp(appleEvent, other.appleEvent, t),
      samsungEvent: Color.lerp(samsungEvent, other.samsungEvent, t),
    );
  }
}