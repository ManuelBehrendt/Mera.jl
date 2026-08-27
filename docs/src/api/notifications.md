# Notifications API Reference

Functions for notifications and progress tracking.

**⚠️ Platform Support**: Tested on macOS and Linux. Windows support not tested.

## Notification Functions

- [`bell`](@ref) - Audio notifications
- [`notifyme`](@ref) - General notification system
- [`send_results`](@ref) - Send computation results
- [`timed_notify`](@ref) - Time-based notifications

## Progress Tracking

- [`create_progress_tracker`](@ref) - Create progress trackers
- [`update_progress!`](@ref) - Update progress status
- [`complete_progress!`](@ref) - Mark progress complete

## Utility Functions

- [`safe_execute`](@ref) - Safe function execution
- [`optimize_image_for_zulip`](@ref) - shrink an image before upload

## Notification Types

- **Bell Notifications** - Local audio alerts
- **Email Notifications** - Remote email alerts
- **Zulip Notifications** - Team chat integration

---
*For complete function documentation, see the [Complete API Reference](../api.md).*

## Function Reference

```@docs
notifyme
bell
timed_notify
send_results
```

## Progress Tracking

A tracker reports long-running work as it goes, rather than only at the end.
Create one, update it inside the loop, and complete it when the work is done.

```@docs
create_progress_tracker
update_progress!
complete_progress!
```

## Utilities

```@docs
safe_execute
optimize_image_for_zulip
```
