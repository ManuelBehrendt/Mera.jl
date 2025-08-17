# Comprehensive Zulip Notification Guide for Mera.jl

This comprehensive tutorial explains how to set up and use the powerful `notifyme` function in Mera.jl for complete workflow notifications. The system supports text messages, captured outputs, optimized image uploads, and multi-platform compatibility.

> ⚠️ **Privacy Notice**: This tutorial includes helper functions for system monitoring (memory, disk, network, processes). These functions can expose sensitive system information. **Use them judiciously** and only in trusted environments. Most examples in this tutorial use safe alternatives like `pwd`, `hostname`, and `julia --version` for demonstration purposes.

## 🚀 Complete Feature Overview

The `notifyme` function provides **5 main capabilities**:

1. **📧 Email Notifications** - Traditional email alerts using system mail
2. **💬 Zulip Messaging** - Rich chat notifications with channel/topic organization  
3. **📸 Image Uploads** - Automatic optimization and upload of plots/screenshots
4. **🖥️ Output Capture** - Real-time capture of terminal commands, function outputs, and shell operations
5. **🔄 Multi-platform Support** - Works on macOS, Linux, and Windows with automatic adaptation

### 📦 Attachment & File Size Policy (New)

Mera's notification layer now includes smart safeguards:

- Images are auto-optimized (target: ≤ 1 MB; max dimension 1024 px). Oversized images are resized; if optimization fails the original file is attempted.
- Non‑image files are validated against a configurable `max_file_size` (default 25 MB). Oversized files are skipped (the notification still succeeds and lists the skipped items).
- Zulip itself may reject files above the server limit (commonly 25–50 MB). You can raise `max_file_size` (e.g. to 50_000_000) but server limits still apply.

Best practices:
1. Keep plots lightweight (PNG or SVG with minimal transparency) for faster uploads.
2. For large tabular data, upload only an extracted summary (e.g. first 100 lines) and retain the full artifact in object storage.
3. Use a tighter `max_file_size` (e.g. 5–10 MB) when running on constrained or mobile connections.
4. When sending many images from a folder, rely on `attachment_folder` + `max_attachments` to limit noise.

Examples:
```julia
notifyme(msg="Full results (allow larger files)", attachments=["results.tar.gz"], max_file_size=50_000_000)
notifyme(msg="Quick summary only", attachments=["summary.log"], max_file_size=5_000_000)
```

## 1. Prerequisites and Dependencies
- A Zulip account on your organization/server  
- Access to create a bot or obtain an API key
- Mera.jl installed and working
- **Auto-loaded packages**: HTTP, JSON (loaded automatically when needed)
- **Optional for images**: Images.jl, FileIO.jl (for automatic optimization)
- **Email support**: System mail client (macOS/Linux) or equivalent

## 2. Create a Zulip Bot and Get API Key

**Important**: For full functionality including image uploads, you need to create a **Generic bot** (not an Incoming webhook bot).

1. Log in to your Zulip server (e.g., https://zulip.yourdomain.com)
2. Go to **Settings > Your bots**
3. Click **Add a new bot**
4. **Bot Type**: Select **"Generic bot"** (NOT "Incoming webhook")
   - Generic bots have full API access including file uploads
   - Webhook bots have limited permissions and cannot upload images
5. Enter a name (e.g., `mera-bot`), and note the bot email (e.g., `mera-bot@zulip.yourdomain.com`)
6. After creation, copy the API key for the bot
7. Note your Zulip server URL (e.g., `https://zulip.yourdomain.com`)

**Note**: If you already have a webhook bot, you'll need to create a new Generic bot for image upload functionality.

## 3. Create Configuration Files

### Email Configuration (Optional)
Create a file named `email.txt` in your home directory (`~/email.txt`) with your email address:
```
your.email@example.com
```

### Zulip Configuration (Optional)
Create a file named `zulip.txt` in your home directory (`~/zulip.txt`) with the following content:

```
mera-bot@zulip.yourdomain.com
YOUR-ZULIP-API-KEY
https://zulip.yourdomain.com
```

**Important:** Make sure the channels you want to send messages to already exist in your Zulip organization. You need to create channels manually through the Zulip web interface under "Manage channels". If a channel doesn't exist, the message will fail to send.

**Recommendation:** Create a personal private channel dedicated to Mera.jl notifications (e.g., "mera-personal") where only you and your bot have access. This keeps your computation results organized and private.

## 4. Complete Usage Guide

The `notifyme` function is extremely versatile and supports multiple ways to send notifications. Here's a comprehensive breakdown of all possibilities:

### 🔧 Function Signature

```julia
notifyme(msg::String)  # Simple version
notifyme(;              # Full keyword version
    msg="done!", 
    zulip_channel="general", 
    zulip_topic="MERA Notification", 
    image_path=nothing, 
    capture_output=nothing
)
```

### 📝 Basic Text Notifications

```julia
# 1. Simplest form - uses defaults
notifyme("Calculation finished!")

# 2. Custom channel and topic (recommended for organization)
notifyme(msg="Heavy computation completed!", 
         zulip_channel="mera-personal", 
         zulip_topic="Daily Calculations")

# 3. Multi-line messages with formatting
notifyme(msg="""
🎉 **Simulation Complete!**

✅ **Status**: Success  
⏱️ **Duration**: 45 minutes  
📊 **Results**: 1,000,000 data points processed  
🔢 **Final Value**: 42.0  

Ready for analysis! 🚀
""", zulip_channel="mera-results", zulip_topic="Simulations")
```

### 🖥️ Output Capture - Advanced Examples

#### **A. Terminal Command Capture**
```julia
# Simple commands (use backticks for basic commands)
notifyme(msg="Directory contents:", capture_output=`ls -la`)
notifyme(msg="Current processes:", capture_output=`ps aux`)
notifyme(msg="Disk usage:", capture_output=`df -h`)

# macOS specific commands
notifyme(msg="System info:", capture_output=`uname -a`)
notifyme(msg="CPU info:", capture_output=`sysctl -n machdep.cpu.brand_string`)
```

#### **B. Complex Shell Commands (use strings for pipes, operators)**
```julia
# Simple computational output examples
notifyme(msg="Current directory:", capture_output=`pwd`)
notifyme(msg="Julia version check:", capture_output=`julia --version`)
notifyme(msg="Git status:", capture_output=`git status --porcelain`)

# Platform-specific shell commands with pipes and operators
if Sys.islinux()
    notifyme(msg="Top processes:", capture_output="ps aux --sort=-%cpu | head -10")
    notifyme(msg="Memory and disk:", capture_output="free -h && df -h")
    notifyme(msg="Network connections:", capture_output="ss -tuln | head -10")
elseif Sys.iswindows()
    notifyme(msg="Top processes:", capture_output="tasklist /fo table | head -10")
    notifyme(msg="Memory info:", capture_output="wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /value")
    notifyme(msg="Disk info:", capture_output="wmic logicaldisk get size,freespace,caption /format:table")
else  # macOS
    notifyme(msg="Top processes:", capture_output="top -l 1 | head -20")
    notifyme(msg="Memory and disk:", capture_output="vm_stat && echo '---' && df -h")
    notifyme(msg="Network interfaces:", capture_output="ifconfig | grep inet")
end

# Advanced filtering and processing
notifyme(msg="Large files:", capture_output="find . -size +100M -type f | head -10")

# Platform-specific log analysis
if Sys.islinux()
    notifyme(msg="System errors:", capture_output="journalctl -p err --since today | tail -20")
elseif Sys.iswindows()
    notifyme(msg="System errors:", capture_output="wevtutil qe System /c:20 /rd:true /f:text")
else  # macOS  
    notifyme(msg="System errors:", capture_output="log show --last 1h --style syslog | grep -i error | tail -20")
end
```

#### **C. Function Output Capture**
```julia
# Capture function results and stdout
notifyme(msg="Random calculation:", capture_output=() -> sum(rand(1000)))

# Complex computational functions
notifyme(msg="Matrix operations:", capture_output=() -> begin
    A = randn(100, 100)
    B = randn(100, 100)
    println("Matrix sizes: $(size(A)) × $(size(B))")
    result = A * B
    println("Result norm: $(norm(result))")
    return trace(result)
end)

# Statistical analysis with output
notifyme(msg="Data analysis:", capture_output=() -> begin
    data = randn(10000)
    println("Sample size: $(length(data))")
    println("Mean: $(mean(data))")
    println("Std: $(std(data))")
    println("Min/Max: $(minimum(data))/$(maximum(data))")
    return "Analysis complete"
end)

# Progress monitoring
notifyme(msg="Long calculation:", capture_output=() -> begin
    result = 0
    for i in 1:100
        result += i^2
        if i % 25 == 0
            println("Progress: $i/100 complete")
        end
    end
    return result
end)
```

#### **D. Mixed Capture Examples**
```julia
# Combine system info with custom computation
system_info = read(`uname -a`, String)
custom_result = sum(rand(1000))
notifyme(msg="System: $system_info\nResult: $custom_result", 
         zulip_channel="mera-personal")

# Conditional capture based on results
result = some_heavy_computation()
if result > threshold
    notifyme(msg="⚠️ High result detected!", 
             capture_output="free -m",  # Check memory usage
             zulip_channel="alerts")
end
```

### 📸 Image Upload - Complete Examples

#### **A. PyPlot Integration**
```julia
using PyPlot

# Simple plot
figure(figsize=(10, 6))
x = 0:0.1:2π
plot(x, sin.(x), label="sin(x)", linewidth=2)
plot(x, cos.(x), label="cos(x)", linewidth=2)
title("Trigonometric Functions")
xlabel("x")
ylabel("y")
legend()
grid(true)
savefig("trig_plot.png", dpi=300, bbox_inches="tight")

notifyme(msg="📊 **Trigonometric Analysis Complete**\n\nGenerated comparison plot with high resolution.", 
         image_path="trig_plot.png",
         zulip_channel="mera-plots", 
         zulip_topic="Mathematical Functions")

# Complex multi-subplot figure
figure(figsize=(12, 8))
for i in 1:4
    subplot(2, 2, i)
    data = randn(1000) .+ i
    hist(data, bins=50, alpha=0.7, label="Dataset $i")
    title("Distribution $i")
    legend()
end
tight_layout()
savefig("multi_analysis.png", dpi=300)

notifyme(msg="📈 **Multi-Dataset Analysis**\n\n4 datasets processed and visualized.", 
         image_path="multi_analysis.png",
         zulip_channel="mera-results")
```

#### **B. CairoMakie Integration**
```julia
using CairoMakie

# 3D surface plot
fig = Figure(resolution=(1200, 800))
ax = Axis3(fig[1, 1], title="3D Surface Analysis")

x = -3:0.1:3
y = -3:0.1:3
z = [sin(√(i^2 + j^2)) for i in x, j in y]

surface!(ax, x, y, z, colormap=:viridis)
save("3d_surface.png", fig)

notifyme(msg="🌊 **3D Surface Analysis Complete**\n\nGenerated high-quality surface visualization.", 
         image_path="3d_surface.png",
         zulip_channel="mera-plots", 
         zulip_topic="3D Visualizations")

# Heatmap with annotations
fig = Figure(resolution=(1000, 800))
ax = Axis(fig[1, 1], title="Correlation Matrix Heatmap")

data = randn(20, 20)
correlation_matrix = cor(data)
hm = heatmap!(ax, correlation_matrix, colormap=:RdBu, colorrange=(-1, 1))
Colorbar(fig[1, 2], hm, label="Correlation")
save("correlation_heatmap.png", fig)

notifyme(msg="🔥 **Correlation Analysis Complete**\n\n20×20 correlation matrix computed and visualized.", 
         image_path="correlation_heatmap.png",
         zulip_channel="mera-analysis")
```

#### **C. Screenshots and External Images**
```julia
# Take screenshot (macOS example)
notifyme(msg="Taking screenshot of current workspace:", 
         capture_output="screencapture -x ~/Desktop/workspace_screenshot.png")

# Send existing images
notifyme(msg="📷 **Workspace Screenshot**\n\nCurrent state of analysis environment.", 
         image_path="~/Desktop/workspace_screenshot.png",
         zulip_channel="mera-personal")

# Convert and send different formats
notifyme(msg="📋 **Diagram Upload**\n\nProcess flow diagram for current analysis.", 
         image_path="process_diagram.pdf",  # PDFs are supported
         zulip_channel="mera-documentation")
```

### 🔄 Comprehensive Workflow Examples

#### **Complete Analysis Pipeline**
```julia
function heavy_computation_with_notifications()
    # Start notification
    notifyme(msg="🚀 **Starting Heavy Computation**\n\nInitializing datasets and parameters...", 
             zulip_channel="mera-personal", 
             zulip_topic="Heavy Computation")
    
    # Computation with progress
    n = 1_000_000
    data = zeros(n)
    
    for i in 1:n
        data[i] = sin(i * π / n) + 0.1 * randn()
        if i % 100_000 == 0
            progress = round(100 * i / n, digits=1)
            notifyme(msg="⏳ **Progress Update**\n\n$progress% complete ($i/$n samples)", 
                     zulip_channel="mera-personal", 
                     zulip_topic="Heavy Computation")
        end
    end
    
    # Generate results plot
    using PyPlot
    figure(figsize=(12, 6))
    plot(1:1000, data[1:1000], alpha=0.7)
    title("Sample of Generated Data (first 1000 points)")
    xlabel("Sample Index")
    ylabel("Value")
    grid(true)
    savefig("computation_result.png", dpi=300, bbox_inches="tight")
    
    # Final result with statistics
    mean_val = mean(data)
    std_val = std(data)
    
    notifyme(msg="""
🎉 **Heavy Computation COMPLETE!**

📊 **Results Summary:**
• **Sample size**: $(length(data)) points
• **Mean value**: $(round(mean_val, digits=4))
• **Standard deviation**: $(round(std_val, digits=4))
• **Min/Max**: $(round(minimum(data), digits=4)) / $(round(maximum(data), digits=4))

✅ Plot generated and attached!
""", 
             image_path="computation_result.png",
             zulip_channel="mera-personal", 
             zulip_topic="Heavy Computation")
    
    return data
end

# Run the complete pipeline
result = heavy_computation_with_notifications()
```

#### **Error Handling and Monitoring**
```julia
function monitored_calculation()
    try
        # Attempt risky calculation
        notifyme(msg="⚠️ **Starting Risky Calculation**\n\nThis might fail...", 
                 zulip_channel="mera-alerts", 
                 zulip_topic="Error Monitoring")
        
        # Simulate potential failure
        if rand() < 0.3  # 30% chance of "failure"
            error("Simulated computation error!")
        end
        
        result = sum(rand(1000))
        
        # Success notification
        notifyme(msg="✅ **Calculation Successful**\n\nResult: $result", 
                 capture_output=() -> println("Success at $(now())"),
                 zulip_channel="mera-alerts", 
                 zulip_topic="Error Monitoring")
        
    catch e
        # Error notification with system info
        notifyme(msg="""
❌ **CALCULATION FAILED**

🐛 **Error Details:**
$(string(e))

📊 **System Status:**
""", 
                 capture_output="top -l 1 | head -10",  # System status
                 zulip_channel="mera-alerts", 
                 zulip_topic="Error Monitoring")
    end
end

monitored_calculation()
```

#### **Multi-Stage Scientific Workflow**
```julia
# Stage 1: Data Collection
notifyme(msg="🔬 **Stage 1: Data Collection**\n\nGathering experimental data...", 
         capture_output=() -> begin
             println("Initializing data collection...")
             println("Connecting to instruments...")
             println("Data collection started at $(now())")
         end,
         zulip_channel="experiment-log", 
         zulip_topic="Daily Experiment")

# Simulate data collection
raw_data = randn(10000, 5)  # 5 experimental parameters

# Stage 2: Data Processing
notifyme(msg="⚙️ **Stage 2: Data Processing**\n\nCleaning and preprocessing data...", 
         capture_output=() -> begin
             println("Raw data shape: $(size(raw_data))")
             println("Checking for outliers...")
             outliers = sum(abs.(raw_data) .> 3)
             println("Found $outliers potential outliers")
             return outliers
         end,
         zulip_channel="experiment-log", 
         zulip_topic="Daily Experiment")

# Stage 3: Analysis and Visualization
using PyPlot
figure(figsize=(15, 10))

for i in 1:5
    subplot(2, 3, i)
    hist(raw_data[:, i], bins=50, alpha=0.7, color="C$i")
    title("Parameter $i Distribution")
    xlabel("Value")
    ylabel("Frequency")
    grid(true)
end

subplot(2, 3, 6)
correlation_matrix = cor(raw_data)
imshow(correlation_matrix, cmap="RdBu", vmin=-1, vmax=1)
title("Parameter Correlations")
colorbar()

tight_layout()
savefig("experiment_analysis.png", dpi=300, bbox_inches="tight")

notifyme(msg="""
📈 **Stage 3: Analysis Complete**

🔬 **Experimental Results:**
• **Sample size**: $(size(raw_data, 1)) measurements
• **Parameters**: $(size(raw_data, 2)) variables measured
• **Quality check**: $(sum(abs.(raw_data) .< 3)) valid measurements
• **Strongest correlation**: $(round(maximum(abs.(correlation_matrix - I)), digits=3))

📊 **Comprehensive analysis plots attached!**
""", 
         image_path="experiment_analysis.png",
         zulip_channel="experiment-log", 
         zulip_topic="Daily Experiment")
```

## 5. Advanced Image Optimization System

The `notifyme` function includes **sophisticated automatic image optimization** to ensure optimal performance and display quality in Zulip:

### 🎯 **Optimization Specifications**
- **Maximum dimension**: 1024 pixels (width or height)  
- **Maximum file size**: 1MB (1,000,000 bytes)
- **Aspect ratio**: Always preserved during resizing
- **Quality preservation**: Smart compression maintains visual quality
- **Format support**: PNG, JPEG/JPG, TIFF, BMP, GIF, WebP, SVG, PDF

### 🚀 **Why Automatic Optimization Matters**

#### **Performance Benefits**
1. **🚄 Upload speed**: 4K images (5MB) → optimized (200KB) = **25× faster uploads**
2. **💾 Storage efficiency**: Reduces Zulip server storage requirements
3. **📱 Mobile friendly**: Optimized for mobile/limited bandwidth viewing
4. **⚡ Chat responsiveness**: Large images can slow down Zulip interface

#### **Quality vs Size Balance**
```julia
# Example optimization results:
# Original: 3840×2160 (4K), 5.2MB PNG → Optimized: 1024×576, 180KB PNG
# Original: 2048×1536, 2.8MB JPEG → Optimized: 1024×768, 95KB JPEG  
# Original: 800×600, 120KB PNG → No optimization (already optimal)
```

### 🔧 **Optimization Process Details**

#### **Step-by-Step Optimization**
1. **📏 Dimension check**: If any dimension > 1024px → resize proportionally
2. **⚖️ File size check**: If file > 1MB → apply additional compression
3. **🎨 Format preservation**: Original format (PNG/JPEG/etc.) maintained
4. **✨ Quality tuning**: Balanced compression for optimal quality/size ratio
5. **🧹 Cleanup**: Temporary files automatically removed after upload

#### **Smart Resizing Algorithm**
```julia
# Proportional scaling example:
original_size = (3840, 2160)  # 4K image
max_dimension = 1024

# Calculate scale factor to fit within bounds
scale = min(1024/3840, 1024/2160) = min(0.267, 0.474) = 0.267

# New dimensions (maintaining aspect ratio)
new_size = (3840 * 0.267, 2160 * 0.267) = (1024, 576)
```

### 💡 **Optimization Examples**

#### **Scientific Plot Optimization**
```julia
using PyPlot

# Create high-resolution scientific plot
figure(figsize=(20, 12))  # Very large figure
x = 0:0.001:10π  # High-density data
plot(x, sin.(x) .* exp.(-x/10), linewidth=3)
title("Damped Oscillation - High Resolution", fontsize=24)
xlabel("Time", fontsize=20)
ylabel("Amplitude", fontsize=20)
grid(true)
savefig("high_res_plot.png", dpi=600)  # 600 DPI = ~12MB file

# Auto-optimization will:
# 1. Detect: 12000×7200 pixels, ~12MB file size
# 2. Resize: → 1024×614 pixels  
# 3. Compress: → ~250KB optimized file
# 4. Upload: 48× smaller, 48× faster upload!

notifyme(msg="🔬 **High-Resolution Scientific Plot**\n\nDamped oscillation analysis complete.\n\n📊 **Auto-optimized for fast viewing**", 
         image_path="high_res_plot.png",
         zulip_channel="science-plots")
```

#### **Image Format Compatibility**
```julia
# PNG plots (best for scientific graphs)
savefig("analysis.png")  # Sharp lines, perfect for plots
notifyme(msg="📈 Analysis plot", image_path="analysis.png")

# JPEG photos (good for photographs/real images)  
savefig("photo_result.jpg")  # Good compression for photos
notifyme(msg="📷 Photo analysis", image_path="photo_result.jpg")

# PDF diagrams (vector graphics)
savefig("diagram.pdf")  # Scalable vector format
notifyme(msg="📋 Process diagram", image_path="diagram.pdf")

# All formats are automatically optimized while preserving format!
```

#### **Before/After Optimization Monitoring**
```julia
function upload_with_optimization_info(image_path, msg)
    # Get original file info
    original_size = filesize(image_path)
    original_dims = try
        using Images
        img = load(image_path)
        size(img)
    catch
        "Unknown"
    end
    
    detailed_msg = """
$msg

📊 **Original Image Info:**
• **File size**: $(round(original_size/1024, digits=1)) KB
• **Dimensions**: $original_dims
• **Auto-optimization**: $(original_size > 1_000_000 ? "Applied" : "Not needed")
"""
    
    notifyme(msg=detailed_msg, image_path=image_path, zulip_channel="mera-analysis")
end

# Usage
figure(figsize=(16, 12))
# ... create plot ...
savefig("large_analysis.png", dpi=300)
upload_with_optimization_info("large_analysis.png", "📊 **Complex Analysis Complete**")
```

### ⚙️ **Optimization Configuration**

#### **Understanding the Defaults**
```julia
# Current optimization settings (built-in):
max_dimension = 1024    # pixels (width or height)
max_file_size = 1_000_000  # bytes (1MB)

# These settings are optimized for:
# - Chat viewing (1024px is ideal for most screens)  
# - Network efficiency (1MB uploads quickly on most connections)
# - Zulip performance (server handles <1MB files efficiently)
# - Visual quality (1024px maintains excellent plot readability)
```

#### **When Optimization Is Skipped**
- ✅ **Small images**: ≤1024px AND ≤1MB → uploaded unchanged
- ✅ **Already optimal**: No unnecessary processing
- ⚠️ **Missing packages**: Images.jl/FileIO.jl not available → original uploaded with warning
- ❌ **Optimization fails**: Uses original image, shows warning

### 🔍 **Troubleshooting Optimization**

#### **Common Issues and Solutions**
```julia
# Issue: Images.jl not installed
# Solution: Install optimization packages
using Pkg
Pkg.add(["Images", "FileIO", "ImageTransformations"])

# Issue: Unsupported format
# Supported: PNG, JPEG, TIFF, BMP, GIF, WebP, SVG, PDF
# Convert unsupported formats first

# Issue: Very large images taking time
# This is normal - 50MB images need processing time
# Monitor with verbose output:
println("Starting optimization of large image...")
notifyme(msg="Large image upload", image_path="huge_file.png")
println("Optimization and upload complete!")
```

### Basic Text Message
```julia
# Simple notification (uses default channel "general" and topic "MERA Notification")
# Note: The "general" channel must exist in your Zulip organization
# Recommendation: Use your personal channel instead
notifyme("Calculation finished!")

# With personal channel and topic (recommended)
notifyme(msg="Calculation finished!", zulip_channel="mera-personal", zulip_topic="Run Status")
```

### Sending Screen Output
```julia
# Capture command output and send as notification
output = read(`ls -l`, String)
notifyme(msg="Directory listing:\n" * output, zulip_channel="mera-personal", zulip_topic="System Info")
```

### Sending PyPlot Images
```julia
using PyPlot
plot(rand(10))
savefig("result.png")
notifyme(msg="Here is the result plot!", 
         zulip_channel="mera-personal",
         zulip_topic="Results", 
         image_path="result.png")
```

### Sending Makie Images
```julia
using CairoMakie
f = Figure()
ax = Axis(f[1, 1])
lines!(ax, 1:10, rand(10))
save("makie_result.png", f)
notifyme(msg="Makie plot attached.", 
         zulip_channel="mera-personal",
         zulip_topic="Makie Results", 
         image_path="makie_result.png")
```

### Complete Workflow Example
```julia
# Start calculation
println("Starting heavy calculation...")

# Your computation here
result = sum(rand(1000000))

# Create a plot
using PyPlot
plot(rand(100))
title("Random Data Plot")
savefig("calculation_result.png")

# Send notification with result and plot to personal channel
notifyme(msg="Calculation completed! Result: $result", 
         zulip_channel="mera-personal", 
         zulip_topic="Heavy Computation", 
         image_path="calculation_result.png")
```

## 6. Quick Start Examples

**Important Note:** When copying code examples, make sure to use straight ASCII quotes (`"`) not smart/curly quotes (`"` or `"`). Smart quotes will cause a ParseError in Julia.

### Basic Text Message
```julia
# Simple notification (uses default channel "general" and topic "MERA Notification")
# Note: The "general" channel must exist in your Zulip organization
# Recommendation: Use your personal channel instead
notifyme("Calculation finished!")

# With personal channel and topic (recommended)
notifyme(msg="Calculation finished!", zulip_channel="mera-personal", zulip_topic="Run Status")
```

### Sending Screen Output
```julia
# Capture command output and send as notification
output = read(`ls -l`, String)
notifyme(msg="Directory listing:\n" * output, zulip_channel="mera-personal", zulip_topic="System Info")
```

### Sending PyPlot Images
```julia
using PyPlot
plot(rand(10))
savefig("result.png")
notifyme(msg="Here is the result plot!", 
         zulip_channel="mera-personal",
         zulip_topic="Results", 
         image_path="result.png")
```

### Sending Makie Images
```julia
using CairoMakie
f = Figure()
ax = Axis(f[1, 1])
lines!(ax, 1:10, rand(10))
save("makie_result.png", f)
notifyme(msg="Makie plot attached.", 
         zulip_channel="mera-personal",
         zulip_topic="Makie Results", 
         image_path="makie_result.png")
```

### Complete Workflow Example
```julia
# Start calculation
println("Starting heavy calculation...")

# Your computation here
result = sum(rand(1000000))

# Create a plot
using PyPlot
plot(rand(100))
title("Random Data Plot")
savefig("calculation_result.png")

# Send notification with result and plot to personal channel
notifyme(msg="Calculation completed! Result: $result", 
         zulip_channel="mera-personal", 
         zulip_topic="Heavy Computation", 
         image_path="calculation_result.png")
```

Since automatic channel creation through the API requires special permissions, you'll need to create channels manually in Zulip:

### Creating a Personal Mera Channel (Recommended)

**For personal use, we recommend creating a private channel dedicated to Mera.jl:**

1. **Log in to your Zulip organization**
2. **Click on the gear icon** (⚙️) in the top right, then select "Manage channels"
3. **Click "Create channel"**
4. **Enter channel details:**
   - **Name**: `mera-personal` (or your preferred name)
   - **Description**: "Personal channel for Mera.jl computational notifications and results"
   - **Privacy**: Select **"Private"** to make it visible only to you
5. **Click "Create channel"**
6. **Add your bot**: In the channel settings, add your Mera bot as a subscriber

### Creating Additional Channels

You can also create specific channels for different types of notifications:

1. **Follow the same steps as above**
2. **Suggested channel names:**
   - `mera-calculations` - For computation results
   - `mera-plots` - For generated plots and visualizations
   - `mera-errors` - For error notifications
   - `mera-testing` - For testing and development
3. **Use these channel names** in your `notifyme` calls

### Setting Default Channel

After creating your personal channel, you can update the default in your scripts:
```julia
# Use your personal channel as default
notifyme("Calculation finished!", zulip_channel="mera-personal")
```

## 7. How to Create Channels in Zulip
All Zulip messages sent by `notifyme` will automatically include:
- `[From Mera.jl]` tag
- The path to the executed script (or "REPL or unknown" if run interactively)

Example message format:
```
[From Mera.jl] Script: /path/to/your/script.jl
Your custom message here
```

## 8. Automatic Message Tagging
- If `email.txt` doesn't exist, email notifications are skipped silently
- If `zulip.txt` doesn't exist, Zulip notifications are skipped silently
- If Zulip API calls fail, a warning is printed but execution continues
- Required packages (HTTP, JSON, Base64) are loaded automatically when needed
- If using a webhook bot, image uploads will fail with a clear error message

## 10. Comprehensive Troubleshooting Guide

### 🔧 **Authentication and Setup Issues**

#### **"This API is not available to incoming webhook bots" Error**
```julia
# ❌ Problem: Using webhook bot instead of generic bot
# ✅ Solution: Create a new Generic bot (not webhook bot)

# Steps to fix:
# 1. Go to Zulip Settings > Your bots
# 2. Create new bot with type "Generic bot" (NOT "Incoming webhook")  
# 3. Update ~/zulip.txt with new bot credentials
# 4. Test with: notifyme("Test message")
```

#### **Authentication/API Key Errors**
```julia
# Check your configuration file
zulip_config = split(read(homedir() * "/zulip.txt", String), '\n')
println("Bot email: '$(strip(zulip_config[1]))'")
println("API key length: $(length(strip(zulip_config[2])))")  
println("Server URL: '$(strip(zulip_config[3]))'")

# Common issues:
# - Extra spaces/newlines in zulip.txt
# - Wrong API key (regenerate in Zulip settings)
# - Incorrect server URL (must include https://)
```

#### **Channel and Topic Issues**
```julia
# ❌ Problem: Channel doesn't exist
# ✅ Solution: Create channel manually in Zulip

# Test channel existence:
notifyme(msg="Testing channel access", zulip_channel="test-channel", zulip_topic="Access Test")

# If this fails, create channel in Zulip web interface:
# Settings > Manage channels > Create channel

# Bot permission check:
# 1. Ensure bot is subscribed to target channel
# 2. Check channel privacy settings
# 3. Verify bot has send permissions
```

### 📸 **Image Upload Issues**

#### **Image Upload Failures**
```julia
# Check image file and format
function debug_image_upload(image_path)
    println("Checking image: $image_path")
    
    # File exists?
    if !isfile(image_path)
        println("❌ File does not exist!")
        return
    end
    
    # File size
    size_mb = filesize(image_path) / 1_000_000
    println("📁 File size: $(round(size_mb, digits=2)) MB")
    
    # Try to load with Images.jl
    try
        using Images
        img = load(image_path)
        println("✅ Image loaded successfully")
        println("📐 Dimensions: $(size(img))")
        println("🎨 Format: $(typeof(img))")
    catch e
        println("⚠️ Image loading failed: $e")
        println("💡 Try: using Pkg; Pkg.add([\"Images\", \"FileIO\"])")
    end
    
    # Test actual upload
    try
        notifyme(msg="🧪 **Debug Upload Test**", image_path=image_path, zulip_channel="mera-personal")
        println("✅ Upload successful!")
    catch e
        println("❌ Upload failed: $e")
    end
end

# Usage:
debug_image_upload("my_plot.png")
```

#### **Supported vs Unsupported Formats**
```julia
# ✅ Fully supported formats:
supported_formats = ["PNG", "JPEG", "JPG", "TIFF", "BMP", "GIF", "WebP", "SVG", "PDF"]

# 🔄 Format conversion for unsupported files:
function convert_to_supported_format(input_path, output_path="converted.png")
    using Images
    img = load(input_path)
    save(output_path, img)
    println("Converted $input_path → $output_path")
    return output_path
end

# Example:
# convert_to_supported_format("data.tiff", "data.png")
# notifyme(msg="Converted image", image_path="data.png")
```

### 🖥️ **Output Capture Issues**

#### **Command Capture Problems**
```julia
# ❌ Problem: Shell operators in backticks fail
# Wrong: notifyme(capture_output=`ls | head -5`)  # Fails!

# ✅ Solution: Use strings for complex commands
# Correct: notifyme(capture_output="ls | head -5")  # Works!

# Platform-specific command issues:
function test_command_capture()
    try
        # Simple command (backticks OK)
        notifyme(msg="Simple command test:", capture_output=`pwd`)
        
        # Complex command (string required)  
        if Sys.iswindows()
            notifyme(msg="Windows dir:", capture_output="dir | findstr /i txt")
        else
            notifyme(msg="Unix listing:", capture_output="ls -la | grep -v '^d'")
        end
        
        println("✅ Command capture tests passed!")
    catch e
        println("❌ Command capture failed: $e")
    end
end

test_command_capture()
```

#### **Function Capture Debugging**
```julia
# Debug function output capture
function debug_function_capture()
    println("Testing function capture...")
    
    # Test function that prints and returns
    test_function = () -> begin
        println("Function is running...")
        println("Computing result...")
        result = 42
        println("Result computed: $result")
        return result
    end
    
    notifyme(msg="🔍 **Function Debug Test**", 
             capture_output=test_function,
             zulip_channel="mera-personal", 
             zulip_topic="Debug Tests")
end

debug_function_capture()
```

### 🔄 **Multi-platform Compatibility**

#### **Platform-Specific Command Examples**
```julia
# Cross-platform example for computational tasks
notifyme(msg="📊 **Current Working Directory**", 
         capture_output=`pwd`,
         zulip_channel="mera-personal")

# Check Julia environment details
notifyme(msg="💾 **Julia Version Info**", 
         capture_output=`julia --version`,
         zulip_channel="mera-personal")

# Cross-platform disk information
notifyme(msg="� **Disk Usage Information**", 
         capture_output=`find . -name "*.jl" | wc -l`,
         zulip_channel="mera-personal")

# Cross-platform network information
notifyme(msg="🌐 **Network Configuration**", 
         capture_output=`git status --porcelain`,
         zulip_channel="mera-personal")

# Cross-platform process information
notifyme(msg="⚙️ **Running Processes**", 
         capture_output=`date`,
         zulip_channel="mera-personal")

# Cross-platform network info
function get_network_info()
    if Sys.iswindows()
        return "ipconfig /all"
    elseif Sys.islinux()
        return "ip addr show && netstat -rn"  
    else  # macOS
        return "ifconfig && netstat -rn"
    end
end

notifyme(msg="🌐 **Network Configuration**", 
         capture_output=get_network_info(),
         zulip_channel="mera-personal")
```

### 📧 **Email Issues**

#### **Email Configuration Problems**
```julia
# Test email setup
function test_email_setup()
    email_file = homedir() * "/email.txt"
    
    if !isfile(email_file)
        println("⚠️ No email.txt found - email notifications disabled")
        println("💡 Create $(email_file) with your email address")
        return
    end
    
    email = strip(read(email_file, String))
    println("📧 Email configured: $email")
    
    # Test if mail command works
    try
        if Sys.iswindows()
            println("⚠️ Windows: Email requires additional setup")
        else
            run(`which mail`)
            println("✅ Mail command available")
        end
    catch
        println("❌ Mail command not found")
        println("💡 Install mail utility (e.g., mailutils on Ubuntu)")
    end
end

test_email_setup()
```

### 🚨 **Error Monitoring and Recovery**

#### **Automatic Error Recovery**
```julia
# Robust notification with fallbacks
function robust_notifyme(msg; retries=3, fallback_channel="general")
    for attempt in 1:retries
        try
            notifyme(msg=msg, zulip_channel="mera-personal")
            println("✅ Notification sent successfully (attempt $attempt)")
            return true
        catch e
            println("⚠️ Attempt $attempt failed: $e")
            if attempt == retries
                # Last attempt - try fallback channel
                try
                    notifyme(msg="[FALLBACK] $msg", zulip_channel=fallback_channel)
                    println("✅ Fallback notification sent")
                    return true
                catch fallback_error
                    println("❌ All notification attempts failed: $fallback_error")
                    return false
                end
            end
            sleep(2^attempt)  # Exponential backoff
        end
    end
end

# Usage:
robust_notifyme("🔄 **Robust Test Message**")
```

#### **Comprehensive Status Check**
```julia
function notifyme_health_check()
    println("🔍 **Mera.jl Notification Health Check**\n")
    
    # 1. Check configuration files
    email_file = homedir() * "/email.txt"
    zulip_file = homedir() * "/zulip.txt"
    
    println("📁 Configuration Files:")
    println("   Email: $(isfile(email_file) ? "✅ Found" : "❌ Missing")")
    println("   Zulip: $(isfile(zulip_file) ? "✅ Found" : "❌ Missing")")
    
    # 2. Check required packages
    println("\n📦 Package Dependencies:")
    for pkg in ["HTTP", "JSON"]
        try
            eval(Meta.parse("using $pkg"))
            println("   $pkg: ✅ Available")
        catch
            println("   $pkg: ❌ Missing")
        end
    end
    
    # 3. Check optional packages  
    println("\n🎨 Optional Packages (for image optimization):")
    for pkg in ["Images", "FileIO", "ImageTransformations"]
        try
            eval(Meta.parse("using $pkg"))
            println("   $pkg: ✅ Available")
        catch
            println("   $pkg: ⚠️ Missing (image optimization disabled)")
        end
    end
    
    # 4. Test basic notification
    println("\n🧪 Testing Basic Notification:")
    try
        notifyme("🔍 **Health Check Test**\n\nAll systems appear functional!")
        println("   ✅ Test notification sent successfully")
    catch e
        println("   ❌ Test failed: $e")
    end
    
    println("\n🎉 Health check complete!")
end

# Run comprehensive check:
notifyme_health_check()
```

### 💡 **Performance Optimization Tips**

#### **Efficient Large-Scale Notifications**
```julia
# ❌ Inefficient: Many small notifications
for i in 1:100
    notifyme("Step $i complete")  # 100 API calls!
end

# ✅ Efficient: Batched progress updates
progress_updates = String[]
for i in 1:100
    # Do work...
    push!(progress_updates, "Step $i: $(rand())")
    
    # Send updates in batches
    if i % 25 == 0 || i == 100
        batch_msg = "🔄 **Progress Update (1-$i)**\n\n" * join(progress_updates[end-min(24,length(progress_updates)-1):end], "\n")
        notifyme(msg=batch_msg, zulip_topic="Batch Progress")
    end
end
```

#### **Memory Management for Large Images**
```julia
# For very large image processing workflows
function memory_efficient_plot_upload(data)
    # Create plot
    using PyPlot
    figure(figsize=(12, 8))
    plot(data)
    
    # Save with explicit cleanup
    plot_file = tempname() * ".png"
    savefig(plot_file, dpi=300, bbox_inches="tight")
    close()  # Free matplotlib memory
    
    # Upload with automatic optimization
    notifyme(msg="📊 **Large Dataset Plot**", image_path=plot_file)
    
    # Manual cleanup
    rm(plot_file)
    GC.gc()  # Force garbage collection
end
```

---

### 🆘 **Getting Additional Help**

If you're still experiencing issues:

1. **📋 Collect debug information**:
   ```julia
   notifyme_health_check()  # Run the comprehensive check above
   ```

2. **🐛 Create minimal test case**:
   ```julia
   # Test with simplest possible case
   notifyme("Basic test")
   ```

3. **📖 Check Zulip server logs**: Ask your Zulip administrator to check server logs for API errors

4. **🔄 Try alternative channels**: Test with different channels to isolate permission issues

5. **📧 Contact Mera.jl maintainers**: Provide output from `notifyme_health_check()` and specific error messages

---

## 🎯 Production-Ready Templates

### Template 1: Scientific Computing Workflow
```julia
function scientific_workflow_with_notifications(experiment_name, data_params)
    start_time = now()
    
    # Stage 1: Setup notification
    notifyme(msg="""
🔬 **$(experiment_name) - STARTED**

📋 **Experiment Parameters:**
$(join(["• $k: $v" for (k,v) in data_params], "\n"))

⏰ **Started**: $(start_time)
🔄 **Status**: Initializing...
""", zulip_channel="research-log", zulip_topic=experiment_name)
    
    try
        # Your scientific computation here
        results = perform_computation(data_params)
        
        # Generate analysis plots
        create_analysis_plots(results, experiment_name)
        
        # Success notification with results
        end_time = now()
        duration = end_time - start_time
        
        notifyme(msg="""
✅ **$(experiment_name) - COMPLETED**

📊 **Results Summary:**
$(format_results_summary(results))

⏱️ **Duration**: $(duration)
🎯 **Status**: Success

Analysis plots attached! 📈
""", 
                 image_path="$(experiment_name)_analysis.png",
                 zulip_channel="research-log", 
                 zulip_topic=experiment_name)
        
        return results
        
    catch e
        # Error notification with diagnostics
        notifyme(msg="""
❌ **$(experiment_name) - FAILED**

🐛 **Error**: $(string(e))
⏰ **Failed at**: $(now())
🔍 **System status at failure:**
""", 
                 capture_output="top -l 1 | head -15",
                 zulip_channel="research-alerts", 
                 zulip_topic="Failures")
        rethrow(e)
    end
end
```

### Template 2: Data Processing Pipeline
```julia
function data_pipeline_with_monitoring(input_files, output_dir)
    pipeline_id = "pipeline_$(round(Int, time()))"
    
    # Initialize progress tracking
    total_files = length(input_files)
    processed = 0
    
    notifyme(msg="""
⚙️ **Data Pipeline Started**

🆔 **Pipeline ID**: $(pipeline_id)
📁 **Input files**: $(total_files)
📂 **Output directory**: $(output_dir)
🔄 **Progress**: 0% (0/$(total_files))
""", zulip_channel="data-pipeline", zulip_topic="Processing Status")
    
    results = []
    for (i, file) in enumerate(input_files)
        try
            # Process individual file
            result = process_file(file, output_dir)
            push!(results, result)
            processed += 1
            
            # Progress updates every 25% or every 10 files
            if (i % max(1, total_files ÷ 4) == 0) || (i % 10 == 0) || (i == total_files)
                progress_pct = round(100 * processed / total_files, digits=1)
                
                notifyme(msg="""
📊 **Pipeline Progress Update**

🆔 **Pipeline ID**: $(pipeline_id)
✅ **Completed**: $(processed)/$(total_files) files ($(progress_pct)%)
⏱️ **Current file**: $(basename(file))
🎯 **Status**: $(i == total_files ? "COMPLETED" : "Processing...")
""", zulip_channel="data-pipeline", zulip_topic="Processing Status")
            end
            
        catch e
            # Handle individual file errors
            notifyme(msg="""
⚠️ **File Processing Error**

🆔 **Pipeline ID**: $(pipeline_id)
❌ **Failed file**: $(basename(file))
🐛 **Error**: $(string(e))
🔄 **Continuing with remaining files...**
""", zulip_channel="data-pipeline", zulip_topic="Processing Errors")
        end
    end
    
    # Final summary with statistics
    success_rate = round(100 * length(results) / total_files, digits=1)
    
    notifyme(msg="""
🎉 **Data Pipeline Complete**

🆔 **Pipeline ID**: $(pipeline_id)
✅ **Success rate**: $(success_rate)% ($(length(results))/$(total_files))
📊 **Summary statistics:**
""", 
             capture_output=() -> generate_pipeline_stats(results),
             zulip_channel="data-pipeline", 
             zulip_topic="Final Results")
    
    return results
end
```

### Template 3: Machine Learning Training Monitor
```julia
function ml_training_with_notifications(model_config, training_data)
    experiment_id = "exp_$(round(Int, time()))"
    
    # Training start notification
    notifyme(msg="""
🤖 **ML Training Started**

🔬 **Experiment ID**: $(experiment_id)
🏗️ **Model**: $(model_config["type"])
📊 **Training samples**: $(size(training_data, 1))
🎯 **Target metric**: $(model_config["target_metric"])
⚙️ **Hyperparameters**: $(model_config["hyperparameters"])

Training in progress... ⏳
""", zulip_channel="ml-experiments", zulip_topic="Training Status")
    
    # Training loop with periodic updates
    best_score = -Inf
    scores_history = Float64[]
    
    for epoch in 1:model_config["epochs"]
        # Train one epoch
        epoch_score = train_epoch(model_config, training_data)
        push!(scores_history, epoch_score)
        
        # Track best performance
        if epoch_score > best_score
            best_score = epoch_score
            save_model_checkpoint(model_config, experiment_id)
        end
        
        # Send updates every 10 epochs or at key milestones
        if (epoch % 10 == 0) || (epoch == model_config["epochs"]) || (epoch_score > best_score)
            # Create training progress plot
            using PyPlot
            figure(figsize=(10, 6))
            plot(1:length(scores_history), scores_history, linewidth=2, marker='o')
            title("Training Progress - $(experiment_id)")
            xlabel("Epoch")
            ylabel(model_config["target_metric"])
            grid(true)
            axhline(y=best_score, color='r', linestyle='--', label="Best: $(round(best_score, digits=4))")
            legend()
            savefig("training_progress_$(experiment_id).png", dpi=300, bbox_inches="tight")
            close()
            
            status = epoch == model_config["epochs"] ? "COMPLETE" : "IN PROGRESS"
            notifyme(msg="""
📈 **Training Update - Epoch $(epoch)**

🔬 **Experiment ID**: $(experiment_id)
📊 **Current $(model_config["target_metric"])**: $(round(epoch_score, digits=4))
🏆 **Best $(model_config["target_metric"])**: $(round(best_score, digits=4))
📈 **Progress**: $(round(100*epoch/model_config["epochs"], digits=1))%
🎯 **Status**: $(status)

Training curve attached! 📊
""", 
                     image_path="training_progress_$(experiment_id).png",
                     zulip_channel="ml-experiments", 
                     zulip_topic="Training Status")
        end
    end
    
    # Final model evaluation and results
    test_score = evaluate_model(model_config, experiment_id)
    
    notifyme(msg="""
🎉 **ML Training Complete!**

🔬 **Experiment ID**: $(experiment_id)
🏆 **Final Training Score**: $(round(best_score, digits=4))
🧪 **Test Score**: $(round(test_score, digits=4))
📈 **Total Epochs**: $(model_config["epochs"])
💾 **Model saved**: checkpoint_$(experiment_id).jld2

Ready for deployment! 🚀
""", zulip_channel="ml-experiments", zulip_topic="Final Results")
    
    return experiment_id, best_score, test_score
end
```

### Template 4: Cross-Platform System Monitoring
```julia
function cross_platform_system_monitor()
    # Get system information for any platform
    try
        notifyme(msg="""
🖥️ **System Health Check**

Platform: $(Sys.iswindows() ? "Windows" : Sys.islinux() ? "Linux" : "macOS")
Timestamp: $(now())

Simple system check completed.
""", 
                 capture_output=`pwd && hostname`,
                 zulip_channel="system-monitoring", 
                 zulip_topic="Health Checks")
        
        # Memory-specific monitoring
        notifyme(msg="""
💾 **Memory Status Report**

Detailed memory analysis for performance monitoring:
""", 
                 capture_output=`julia --version`,
                 zulip_channel="system-monitoring", 
                 zulip_topic="Memory Status")
        
        # Network status
        notifyme(msg="""
🌐 **Network Configuration**

Current network interfaces and connections:
""", 
                 capture_output=`git status --porcelain`,
                 zulip_channel="system-monitoring", 
                 zulip_topic="Network Status")
        
        # Disk status
        notifyme(msg="""
💿 **Storage Analysis**

Disk usage and storage information:
""", 
                 capture_output=`find . -name "*.jl" | wc -l`,
                 zulip_channel="system-monitoring", 
                 zulip_topic="Storage Status")
        
        # Process monitoring
        notifyme(msg="""
⚙️ **Process Overview**

Top processes by CPU and memory usage:
""", 
                 capture_output=`date`,
                 zulip_channel="system-monitoring", 
                 zulip_topic="Process Status")
        
        println("✅ Cross-platform system monitoring complete!")
        
    catch e
        # Error handling with platform info
        notifyme(msg="""
❌ **System Monitoring Error**

Platform: $(Sys.KERNEL)
Error: $(string(e))
Timestamp: $(now())

Please check system monitoring setup.
""", zulip_channel="system-alerts", zulip_topic="Monitoring Errors")
    end
end

# Usage: Run monitoring for any platform
cross_platform_system_monitor()
```

### Template 5: Multi-Platform Computational Workflow
```julia
function computational_workflow_with_cross_platform_monitoring(computation_name, parameters)
    start_time = now()
    
    # Initial notification with platform detection
    platform_name = Sys.iswindows() ? "Windows" : Sys.islinux() ? "Linux" : "macOS"
    
    notifyme(msg="""
🚀 **Computation Started: $(computation_name)**

🖥️ **Platform**: $(platform_name)
📋 **Parameters**: $(parameters)
⏰ **Started**: $(start_time)
🔄 **Status**: Initializing...

System baseline captured below:
""", 
             capture_output=`hostname && pwd`,
             zulip_channel="computational-log", 
             zulip_topic=computation_name)
    
    try
        # Your computation here
        println("Starting computation: $computation_name")
        result = perform_heavy_computation(parameters)
        
        # Success with system state
        end_time = now()
        duration = end_time - start_time
        
        notifyme(msg="""
✅ **Computation Complete: $(computation_name)**

🎯 **Result**: $(result)
⏱️ **Duration**: $(duration)
🖥️ **Platform**: $(platform_name)
📊 **Final system state**:
""", 
                 capture_output=`julia --version`,
                 zulip_channel="computational-log", 
                 zulip_topic=computation_name)
        
        return result
        
    catch e
        # Error with diagnostic information
        notifyme(msg="""
❌ **Computation Failed: $(computation_name)**

🐛 **Error**: $(string(e))
🖥️ **Platform**: $(platform_name)
⏰ **Failed at**: $(now())
🔍 **System diagnostics**:
""", 
                 capture_output=`date`,
                 zulip_channel="computational-alerts", 
                 zulip_topic="Failed Computations")
        rethrow(e)
    end
end

# Example usage for cross-platform computational monitoring
function example_cross_platform_computation()
    # This works identically on Windows, Linux, and macOS
    computational_workflow_with_cross_platform_monitoring(
        "Cross-Platform Matrix Analysis", 
        Dict("matrix_size" => 1000, "iterations" => 100)
    )
end
```

### Template 6: Advanced System Monitoring and Alerts
```julia
function system_health_monitor()
    while true
        try
            # Collect system metrics
            cpu_usage = get_cpu_usage()
            memory_usage = get_memory_usage()
            disk_usage = get_disk_usage()
            
            # Check for alerts
            alerts = []
            if cpu_usage > 90
                push!(alerts, "🔥 **HIGH CPU**: $(cpu_usage)%")
            end
            if memory_usage > 85
                push!(alerts, "💾 **HIGH MEMORY**: $(memory_usage)%")
            end
            if disk_usage > 90
                push!(alerts, "💿 **HIGH DISK**: $(disk_usage)%")
            end
            
            # Send alerts if any issues detected
            if !isempty(alerts)
                notifyme(msg="""
🚨 **SYSTEM ALERT**

$(join(alerts, "\n"))

⏰ **Time**: $(now())
📊 **Full system status:**
""", 
                         capture_output="top -l 1 | head -20 && df -h",
                         zulip_channel="system-alerts", 
                         zulip_topic="Critical Alerts")
            end
            
            # Regular health report (every hour)
            if minute(now()) == 0  # Top of the hour
                notifyme(msg="""
💚 **Hourly Health Report**

🖥️ **CPU Usage**: $(cpu_usage)%
💾 **Memory Usage**: $(memory_usage)%
💿 **Disk Usage**: $(disk_usage)%
⏰ **Timestamp**: $(now())

System running smoothly! ✅
""", zulip_channel="system-monitoring", zulip_topic="Health Reports")
            end
            
        catch e
            # Monitoring system failure alert
            notifyme(msg="""
❌ **MONITORING SYSTEM ERROR**

🐛 **Error**: $(string(e))
⏰ **Time**: $(now())
🔄 **Will retry in 5 minutes**

Please check monitoring system! 🔧
""", zulip_channel="system-alerts", zulip_topic="Monitoring Errors")
        end
        
        # Wait 5 minutes before next check
        sleep(300)
    end
end
```

## 📖 Best Practices Summary

### 🧪 **Testing Your Setup**

Mera.jl includes comprehensive tests for all Zulip notification features. To run the notification tests:

```julia
# Run all tests including Zulip notifications (if configured)
using Pkg; Pkg.test("Mera")

# Or run just the Zulip notification tests
using Test
include("test/zulip_notification_tests.jl")
```

**Important Notes:**
- Tests only run if `~/zulip.txt` exists and is properly configured
- All test messages are sent to the `"runtests"` channel to avoid spam
- Tests cover all functionality: text messages, image uploads, output capture, cross-platform helpers, and error handling
- The test suite automatically creates and cleans up test files

**Before running tests, create the `runtests` channel in your Zulip:**
1. Go to your Zulip web interface
2. Click gear icon (⚙️) → "Manage channels"  
3. Click "Create channel"
4. Name: `runtests`, Description: "Channel for Mera.jl test notifications"
5. Add your bot as a subscriber

### 🏗️ **Organization**
- **Use dedicated channels** for different types of notifications (e.g., `mera-personal`, `research-log`, `system-alerts`)
- **Consistent topic naming** helps with message organization and searchability
- **Channel privacy**: Use private channels for personal work, shared channels for team updates

### 🎯 **Cross-Platform Excellence**
- **Automatic platform detection** with `Sys.iswindows()`, `Sys.islinux()`, and macOS support
- **Native command usage** for optimal performance on each platform
- **Unified API** - same function calls work everywhere
- **Comprehensive coverage** - system info, memory, disk, network, processes
- **Error resilience** with platform-specific fallbacks

### 📝 **Message Formatting**
- **Use emojis** to make messages visually scannable (🔬 for experiments, 📊 for data, ⚠️ for warnings)
- **Structured content** with clear sections (Status, Results, Duration, etc.)
- **Progress indicators** for long-running tasks (percentages, progress bars)

### 🎯 **Notification Strategy**
- **Start/Progress/Complete** pattern for workflows
- **Error notifications** with diagnostic information
- **Batch updates** for repetitive tasks (every 25% or every N iterations)
- **Rich context** with system information for debugging

### 🖼️ **Image Management**
- **Automatic optimization** handles file sizes - no manual resizing needed
- **Descriptive filenames** help with organization
- **Plot quality**: Use high DPI (300+) for publication-quality images
- **Format choice**: PNG for plots/diagrams, JPEG for photos

### 🔧 **Technical Excellence**
- **Error handling** with try/catch blocks and fallback notifications
- **Resource cleanup** for temporary files and large objects
- **Cross-platform compatibility** with OS-specific commands
- **Performance monitoring** to avoid overwhelming the chat

---

For further help, see the Mera.jl documentation or contact your Zulip administrator.
