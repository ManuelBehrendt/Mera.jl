# File Attachments and Size Management

Learn how to attach files, images, and manage upload sizes effectively.

## 📎 File Attachment Options

### Single Image
```julia
notifyme("Plot ready!", image_path="analysis.png")
```

### Multiple Files
```julia
notifyme("Results package!", 
         attachments=["plot1.png", "plot2.png", "data.csv"])
```

### Folder Attachments
```julia
# Attach all images from a folder (newest first)
notifyme("All plots from analysis!", 
         attachment_folder="./plots/",
         max_attachments=5)  # Limit to 5 newest files
```

## 📏 File Size Management

### Default Limits
- **Images**: Auto-optimized to ≤1 MB, max dimension 1024px
- **Non-images**: 25 MB default limit
- **Server limits**: Zulip servers typically allow 25-50 MB

### Custom Size Limits
```julia
# Allow larger files (50 MB)
notifyme("Large dataset!", 
         attachments=["results.tar.gz"],
         max_file_size=50_000_000)

# Restrict to smaller files (5 MB) for slow connections
notifyme("Quick summary!", 
         attachments=["summary.log"],
         max_file_size=5_000_000)
```

### Size Check Behavior
- **Oversized files**: Skipped with warning message
- **Notification still succeeds**: Other files upload normally
- **Clear feedback**: Shows actual vs. limit sizes

Example output for oversized file:
```
⚠️ File too large: bigdata.csv (47.3 MB > 25.0 MB limit)
```

## 🖼️ Image Optimization

### Automatic Processing
Images are automatically optimized for faster uploads:

1. **Size check**: If ≤1 MB and ≤1024px, no changes needed
2. **Dimension resize**: Scale down to max 1024px on longest side  
3. **File size optimization**: Reduce quality/compression if still too large
4. **Fallback**: Use original if optimization fails

### Supported Formats
- PNG, JPG/JPEG, GIF, SVG, WebP, BMP, TIFF/TIF

### Best Practices for Images

```julia
# Good: Generate plots with reasonable size
using Plots
plot(data, size=(800, 600), dpi=150)
savefig("plot.png")
notifyme("Analysis complete!", image_path="plot.png")

# Good: Use PNG for plots, JPEG for photos
savefig("scientific_plot.png")    # Crisp lines and text
savefig("photo_result.jpg")       # Natural images

# Avoid: Extremely high DPI unless necessary
# plot(data, dpi=600)  # Creates very large files
```

## 📦 Batch File Handling

### Process Multiple Results
```julia
# Send all CSV files from results folder
result_files = filter(f -> endswith(f, ".csv"), readdir("results", join=true))
notifyme("All CSV results ready!", 
         attachments=result_files,
         max_attachments=10)

# Send plots with size control
plot_files = filter(f -> endswith(f, r"\.(png|jpg)$"i), readdir("plots", join=true))
notifyme("Plot gallery!", 
         attachments=plot_files,
         max_file_size=10_000_000,  # 10 MB limit per file
         zulip_channel="plots")
```

### Smart File Selection
```julia
# Send only recent files (last 24 hours)
recent_files = filter(readdir("output", join=true)) do file
    stat(file).mtime > time() - 24*3600  # 24 hours ago
end

notifyme("Recent outputs!", attachments=recent_files)

# Send largest files first (for data summaries)
data_files = readdir("data", join=true)
sorted_files = sort(data_files, by=filesize, rev=true)
notifyme("Top 3 largest results!", 
         attachments=sorted_files[1:min(3, end)])
```

## 🚫 File Upload Errors

### Common Issues and Solutions

**File not found:**
```julia
# Check file exists before sending
file_path = "results.png"
if isfile(file_path)
    notifyme("Results!", image_path=file_path)
else
    notifyme("❌ Results file missing: $file_path")
end
```

**Server rejection (413 error):**
- File exceeds Zulip server limit
- Try increasing `max_file_size` if server allows
- Split large files or compress data
- Upload to external storage and share link instead

**Image optimization failed:**
- Install image processing packages: `Pkg.add(["Images", "FileIO", "ImageTransformations"])`
- Use original file if optimization not critical
- Convert to supported format (PNG/JPEG)

### Fallback Strategies
```julia
# Try attachment, fallback to message-only
function safe_notify_with_file(msg, file_path)
    try
        if isfile(file_path) && filesize(file_path) < 25_000_000
            notifyme(msg, image_path=file_path)
        else
            size_mb = round(filesize(file_path) / 1_000_000, digits=1)
            notifyme("$msg\n\n📎 File available locally: $file_path ($(size_mb) MB)")
        end
    catch e
        notifyme("$msg\n\n⚠️ File attachment failed: $e")
    end
end
```

## 📋 Summary

**Best Practices:**
1. Keep images reasonably sized (PNG for plots, moderate DPI)
2. Use `max_file_size` for network-aware uploads
3. Test file uploads with small files first  
4. Monitor server limits and adjust accordingly
5. Implement fallbacks for critical notifications

**Default Behavior:**
- Images: Auto-optimized to ≤1 MB, ≤1024px
- Non-images: 25 MB limit, skipped if larger
- Multiple files: Processed individually, failures don't stop others
- Folders: Newest files first, respects `max_attachments`
