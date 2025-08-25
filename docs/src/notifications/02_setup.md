# Setup and Configuration Guide

Complete setup instructions for MERA notifications.

## 📧 Email Configuration

### Requirements
- System mail client (macOS/Linux built-in, Windows requires setup)
- Valid email address that can receive emails

### Step-by-Step Setup

#### Step 1: Create Email Configuration

**Option A: Using Terminal (Linux/macOS)**
```bash
# Navigate to home directory
cd ~

# Create email.txt with your email address
echo "your.email@example.com" > email.txt

# Verify the file was created correctly
cat email.txt
```

**Option B: Manual Creation**
1. Create a new text file named `email.txt` in your home directory
2. Add **only one line** containing your email address
3. **Important**: No extra spaces, quotes, or empty lines
4. Save the file

**Example `email.txt` content:**
```
researcher@university.edu
```

#### Step 2: Verify Mail System

**Check if mail command exists:**
```bash
which mail
# Should return a path like /usr/bin/mail (macOS/Linux)
```

**Test email functionality:**
```bash
echo "MERA setup test" | mail -s "Test from MERA" your.email@example.com
```

#### Step 3: Platform-Specific Notes

**macOS**: Built-in mail command works out of the box
**Linux**: Usually pre-installed; install if needed:
```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# CentOS/RHEL
sudo yum install mailx
```

**Windows**: Requires additional setup (consider using Zulip only)

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

**Option A: Using Terminal (Linux/macOS)**
```bash
# Navigate to home directory
cd ~

# Create zulip.txt with your bot credentials
cat > zulip.txt << EOF
mera-bot@zulip.yourdomain.com
your-api-key-here
https://zulip.yourdomain.com
EOF

# Set secure permissions
chmod 600 zulip.txt
```

**Option B: Manual Creation**
1. Create a new text file named `zulip.txt` in your home directory
2. Add exactly three lines:
   - **Line 1**: Your bot email (e.g., `mera-bot@yourlab.zulipchat.com`)
   - **Line 2**: Your bot API key (long string from bot settings)
   - **Line 3**: Your Zulip server URL (e.g., `https://yourlab.zulipchat.com`)
3. Save the file
4. **Important**: No extra spaces, empty lines, or comments

**Example `zulip.txt` content:**
```
mera-computation-bot@mylab.zulipchat.com
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
https://mylab.zulipchat.com
```

### Step 3: Create Channels

Create these recommended channels in Zulip:
- `mera-personal` - Your private notifications
- `research` - Research-related alerts
- `errors` - Error notifications
- `progress` - Long-running job updates

## ⚡ Important: Multiple Methods Behavior

**Key Point**: If you configure both email and Zulip, `notifyme()` sends to **BOTH** methods simultaneously.

### Notification Matrix

| Configuration | `notifyme("Hello!")` sends to: |
|---------------|-------------------------------|
| Only `~/email.txt` | ✅ Email only |
| Only `~/zulip.txt` | ✅ Zulip only |  
| **Both files exist** | ✅ **Both email AND Zulip** |
| No config files | ❌ Nothing (silent) |

### Examples

```julia
# With both email.txt and zulip.txt configured:
notifyme("Analysis complete!")
# Result: Email sent to your.email@example.com
#         AND Zulip message sent to #alerts channel

# If you want only email for this message:
# Temporarily rename zulip.txt or use system-specific method
```

**💡 Tip**: Most users find the "send to all configured methods" behavior useful for important notifications, but be aware that you'll get multiple notifications for each call.

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
