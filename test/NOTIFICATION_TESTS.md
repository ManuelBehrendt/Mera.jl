# Notification System Tests

This directory contains comprehensive tests for the MERA.jl notification system. The tests are designed to run locally only when notification configuration files are present, ensuring they don't interfere with CI/CD pipelines.

## Test Files

### `zulip_notification_tests.jl`
- **Purpose**: Comprehensive Zulip integration tests (basic text, command/function output capture, image optimization, error handling, combined scenarios, performance / Unicode). Auto-switches to a reduced "basic" mode via `MERA_BASIC_ZULIP_TESTS=true` for CI or fast runs.
- **Safety**: All messages restricted to `runtests` channel.

### `notifications_simple_test.jl`
- **Purpose**: Lightweight local smoke test (function availability, basic notify, timing, progress tracker, small attachment logic) — included only when not in CI.
- **Role**: Fast sanity check before running heavier comprehensive suite.

### `notification_robustness_tests.jl`
- **Purpose**: Network/dry-run independent edge coverage (missing files, large file skip, malformed config, forced timeout) using sandboxed HOME & environment overrides.
- **Goal**: Ensure error paths never throw and remain CI-safe.

### `run_notification_tests.jl`
- **Purpose**: Standalone runner to execute only the simple smoke tests outside full suite.
- **Usage**: `julia test/run_notification_tests.jl`

### Removed / Consolidated
- `notification_tests.jl` (legacy comprehensive) and `quick_zulip_test.jl` were removed to eliminate duplication. Their coverage merged into `zulip_notification_tests.jl` (full features) plus the simple + robustness files.

## Configuration Requirements

### Email Notifications
Create `~/email.txt` containing your email address:
```bash
echo "your.email@example.com" > ~/email.txt
```

### Zulip Notifications  
Create `~/zulip.txt` with three lines:
```bash
cat > ~/zulip.txt << EOF
your-bot@your-zulip-server.com
your_api_key_here
https://your-zulip-server.com
EOF
```

## Test Channel Safety

All tests send messages exclusively to the `runtests` channel in Zulip to avoid spamming general channels. This ensures:
- ✅ No disruption to team communications
- ✅ Easy identification of test messages
- ✅ Safe testing in production Zulip instances

## Running Tests

### Option 1: Dedicated Test Runner (Recommended)
```bash
julia test/run_notification_tests.jl
```

### Option 2: With Main Test Suite (Local Only)
```bash
julia --project=. test/runtests.jl
```
*Note: Simple tests & robustness always safe; comprehensive Zulip tests auto‑downgrade to basic mode in CI / heavy-skip contexts.*

## CI/CD Integration

The notification tests are designed to be **local-only**:
- ✅ Automatically skip in CI environments
- ✅ Don't require special CI configuration
- ✅ Won't break builds if notification config is missing
- ✅ Use `IS_CI` detection to avoid running in automated environments

## Test Coverage

The notification tests verify:

### Core Functions
- [x] `bell()` - Audio notifications
- [x] `notifyme()` - Basic text notifications
- [x] Email delivery (when configured)
- [x] Zulip messaging (when configured)

### Advanced Features  
- [x] `timed_notify()` - Automatic timing wrapper
- [x] `safe_execute()` - Exception handling wrapper
- [x] `create_progress_tracker()` - Progress monitoring
- [x] `update_progress!()` - Progress updates
- [x] `complete_progress!()` - Progress completion
- [x] Time tracking (`start_time`, `include_timing`)
- [x] Performance metrics (`timing_details=true`)
- [x] Exception reporting (`exception_context`)

### File Attachments (Basic)
- [x] Single file attachments
- [x] Multiple file attachments  
- [x] Error handling for missing files
- [x] Large file skip logic (robustness)
- [x] Timeout & malformed config resilience
- [x] `send_results()` convenience function

## Troubleshooting

### Tests Skip with "No configuration files found"
- Check that `~/email.txt` and/or `~/zulip.txt` exist
- Verify file permissions are readable
- Ensure file contents are correct format

### Zulip Tests Fail
- Verify Zulip server URL is reachable
- Check API key is valid and not expired
- Ensure bot has permissions to post in `runtests` channel
- Create `runtests` channel if it doesn't exist

### Email Tests Fail
- Verify email client `mail` is installed (macOS/Linux)
- Check system mail configuration
- For Windows, use Zulip notifications instead

### Image Processing Errors
- Install required image processing packages if using advanced tests
- Simple tests avoid image processing to reduce dependencies

## Best Practices

1. **Always Test in `runtests` Channel**: Never change the test channel to avoid spam
2. **Run Locally First**: Test notification setup before committing
3. **Respect Rate Limits**: Tests include `sleep()` calls to avoid overwhelming servers
4. **Monitor Channel**: Check `runtests` channel after running tests to verify delivery
5. **Clean Up**: Remove test configuration files from production systems when done

## Example Test Output

```
🔔 MERA Notification Test Runner
========================================
Configuration Status:
  📧 Email: ✅ Configured
  💬 Zulip: ✅ Configured
  🧪 Tests: Will run

🚀 Running notification tests...
📤 All test messages sent to: 'runtests' channel

✅ All notification functions are available
✅ bell() works
✅ notifyme() works
✅ Time tracking works
✅ Progress tracking works
🎉 All simple notification tests passed!

🎉 Notification tests completed!
🔍 Check your 'runtests' channel in Zulip for test messages
📧 Check your email for test notifications
```
