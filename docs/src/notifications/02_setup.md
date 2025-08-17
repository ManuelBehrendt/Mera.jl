# Setup and Configuration Guide

Complete setup instructions for MERA notifications.

## 📧 Email Configuration

### Requirements
- System mail client (macOS/Linux built-in, Windows requires setup)
- Valid email address

### Setup
1. Create `~/email.txt` with your email:
   ```
   your.email@example.com
   ```

2. Test email functionality:
   ```bash
   echo "Test message" | mail -s "Test Subject" your.email@example.com
   ```

## 💬 Zulip Configuration

### Step 1: Create a Zulip Bot

**Important**: Use a **Generic bot** (not Incoming webhook) for full functionality.

1. Log in to your Zulip server
2. Go to **Settings > Your bots**
3. Click **Add a new bot**
4. Select **"Generic bot"** type
5. Enter name (e.g., `mera-bot`)
6. Copy the bot email and API key
7. Note your server URL

### Step 2: Create Configuration File

Create `~/zulip.txt`:
```
mera-bot@zulip.yourdomain.com
your-api-key-here
https://zulip.yourdomain.com
```

### Step 3: Create Channels

Create these recommended channels in Zulip:
- `mera-personal` - Your private notifications
- `research` - Research-related alerts
- `errors` - Error notifications
- `progress` - Long-running job updates

## 🔧 Verification

Test your setup:

```julia
using Mera

# Test basic notification
notifyme("Setup test - basic message")

# Test with custom channel
notifyme("Setup test - custom channel", 
         zulip_channel="mera-personal",
         zulip_topic="Configuration Test")

# Test output capture
notifyme("Setup test - with output", 
         capture_output=`julia --version`)
```

## 🛠️ Troubleshooting

### Common Issues

**Email not working:**
- Check if `mail` command exists: `which mail`
- Verify email.txt format (no extra whitespace)
- Test manual email: `echo "test" | mail -s "test" you@example.com`

**Zulip authentication failed:**
- Verify bot type is "Generic" not "Incoming webhook"
- Check API key has no extra characters
- Ensure bot has access to target channels
- Test bot permissions in Zulip web interface

**Channel not found:**
- Create channels manually in Zulip web interface
- Check channel names for typos
- Ensure bot is subscribed to target channels

**File upload failed:**
- Check file exists and is readable
- Verify file size (default limit: 25 MB)
- Images auto-optimize; check for image processing errors
- Server may have stricter limits than client

### Debug Mode

Enable verbose output:
```julia
# Check configuration status
println("Email configured: ", isfile(homedir() * "/email.txt"))
println("Zulip configured: ", isfile(homedir() * "/zulip.txt"))

# Test with error handling
try
    notifyme("Debug test")
    println("✅ Notification sent successfully")
catch e
    println("❌ Error: ", e)
end
```

## 🔒 Security Notes

- Keep `zulip.txt` private (consider `chmod 600 ~/zulip.txt`)
- Use bot accounts, not personal API keys
- Regularly rotate API keys
- Monitor bot activity in Zulip
- Be cautious with system information capture in shared channels
