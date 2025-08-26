# ====================================================================================
# Notifications Module for MERA
# 
# This module contains all notification-related functionality including:
# - Email notifications (bell, notifyme)
# - Zulip messaging with image support
# - Cross-platform system information helpers
# - Output capturing capabilities
# ====================================================================================

function bell()
    # Sound folder
    sounddir = joinpath(@__DIR__, "../sounds/")
    y, fs = wavread(sounddir * "strum.wav")
    wavplay(y, fs)
    return
end



# Image optimization function for Zulip uploads using existing Mera dependencies
function optimize_image_for_zulip(image_path::String; max_dimension=1024, max_file_size=1_000_000)
    try
        # Check file size first
        current_size = stat(image_path).size
        
        # If file is already small enough, no need to optimize
        if current_size <= max_file_size
            # Still check image dimensions if we have ImageTransformations
            try
                @eval using ImageTransformations, FileIO, Images
                img = load(image_path)
                img_size = size(img)
                max_current_dim = max(img_size...)
                
                if max_current_dim <= max_dimension
                    return image_path, false  # No optimization needed
                end
                
                # Resize only
                scale_factor = max_dimension / max_current_dim
                new_height = round(Int, img_size[1] * scale_factor)
                new_width = round(Int, img_size[2] * scale_factor)
                resized_img = imresize(img, (new_height, new_width))
                
                # Create temporary file
                temp_dir = mktempdir()
                file_ext = lowercase(splitext(image_path)[2])
                optimized_path = joinpath(temp_dir, "resized" * file_ext)
                save(optimized_path, resized_img)
                
                return optimized_path, true
                
            catch e
                # If image processing fails, use original
                return image_path, false
            end
        end
        
        # File is too large - try to optimize
        @eval using ImageTransformations, FileIO, Images
        img = load(image_path)
        img_size = size(img)
        max_current_dim = max(img_size...)
        
        # Calculate resize factor considering both dimension and file size
        dimension_factor = max_current_dim > max_dimension ? max_dimension / max_current_dim : 1.0
        
        # Estimate size reduction needed (rough heuristic)
        size_factor = current_size > max_file_size ? sqrt(max_file_size / current_size) : 1.0
        
        # Use the more aggressive factor
        scale_factor = min(dimension_factor, size_factor)
        
        if scale_factor < 1.0
            new_height = round(Int, img_size[1] * scale_factor)
            new_width = round(Int, img_size[2] * scale_factor)
            resized_img = imresize(img, (new_height, new_width))
            
            # Create temporary file
            temp_dir = mktempdir()
            file_ext = lowercase(splitext(image_path)[2])
            optimized_path = joinpath(temp_dir, "optimized" * file_ext)
            save(optimized_path, resized_img)
            
            return optimized_path, true
        else
            return image_path, false
        end
        
    catch e
        # If any optimization fails, return original
        println("Note: Image optimization skipped (error: $e)")
        return image_path, false
    end
end

# Simple base64 encoding function for Zulip authentication
function simple_base64encode(s::String)
    # Base64 encoding table
    table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    
    # Convert string to bytes
    bytes = Vector{UInt8}(s)
    result = ""
    
    # Process in groups of 3 bytes
    for i in 1:3:length(bytes)
        # Get up to 3 bytes
        b1 = bytes[i]
        b2 = i+1 <= length(bytes) ? bytes[i+1] : 0
        b3 = i+2 <= length(bytes) ? bytes[i+2] : 0
        
        # Convert to 4 base64 characters
        n = (Int(b1) << 16) | (Int(b2) << 8) | Int(b3)
        result *= table[(n >> 18) & 63 + 1]
        result *= table[(n >> 12) & 63 + 1]
        result *= i+1 <= length(bytes) ? table[(n >> 6) & 63 + 1] : "="
        result *= i+2 <= length(bytes) ? table[n & 63 + 1] : "="
    end
    
    return result
end

function notifyme(msg::String; kwargs...)
    # If no keyword arguments provided, use the simple version
    if isempty(kwargs)
        return notifyme(msg=msg)
    else
        return notifyme(msg=msg; kwargs...)
    end
end

"""
### Get an email and/or Zulip notification, e.g., when your calculations are finished.

Email notification:
- Requires the email client "mail" to be installed
- Put a file with the name "email.txt" in your home folder that contains your email address in the first line 

Zulip notification (optional):
- Put a file with the name "zulip.txt" in your home folder with three lines:
  - Line 1: Your Zulip bot email (e.g., mybot@zulip.yourdomain.com)
  - Line 2: Your Zulip API key
  - Line 3: Your Zulip server URL (e.g., https://zulip.yourdomain.com)

Output Capture (optional):
- capture_output: Can be a Cmd, Function, or String to capture terminal/function output
- The captured output will be appended to your message

File Attachments (optional):
- image_path: Single image file to attach
- attachments: Vector of file paths to attach (multiple files)
- attachment_folder: Path to folder - all image files (.png, .jpg, .jpeg, .gif, .svg) will be attached
- max_attachments: Maximum number of files to attach when using attachment_folder (default: 10)
 - max_file_size: Maximum file size in bytes for non-image attachments (default: 25_000_000 ≈ 25 MB). Files larger than this are skipped with an explanatory warning (Zulip itself may enforce stricter limits – typical defaults are 25–50 MB). For images a stricter 1 MB optimization target is applied automatically to keep uploads fast and reliable; large images are resized down to <=1024px on the longest side.

Time Tracking (optional):
- start_time: Start time for execution tracking (use time() or now())
- include_timing: Boolean to include automatic timing information (default: false)
- timing_details: Include detailed performance metrics (memory, allocations)

Exception Handling (optional):
- exception_context: Exception object to include stack trace and error details
- include_stacktrace: Boolean to include full stack trace (default: true when exception_context provided)

```julia
julia> notifyme()
```

```julia
julia> notifyme("Calculation 1 finished!")
```

```julia
julia> notifyme(msg="Calculation finished!", zulip_channel="alerts", zulip_topic="Run Status")
```

```julia
julia> notifyme(msg="Plot ready!", zulip_channel="plots", zulip_topic="Results", image_path="result.png")
```

```julia
julia> notifyme(msg="Multiple results!", attachments=["plot1.png", "plot2.png", "data.csv"])
```

```julia
julia> notifyme(msg="All plots from analysis!", attachment_folder="./plots/")
```

```julia
julia> notifyme(msg="Limited plots!", attachment_folder="./plots/", max_attachments=5)
```

```julia
julia> notifyme(msg="Large dataset results!", attachments=["data.csv"], max_file_size=50_000_000)  # 50MB limit
```

```julia
# Example: enforce a tighter 5 MB limit to avoid heavy uploads when on slow networks
julia> notifyme(msg="Quick summary only", attachments=["summary.log"], max_file_size=5_000_000)
```

```julia
# Time tracking examples
julia> start = time(); heavy_computation(); notifyme("Computation done!", start_time=start)
```

```julia
julia> notifyme("Analysis finished!", include_timing=true, timing_details=true)
```

```julia
# Exception handling examples  
julia> try
           risky_computation()
       catch e
           notifyme("Computation failed!", exception_context=e)
       end
```

```julia
julia> notifyme(msg="Directory listing:", capture_output=`ls`)
```

```julia
julia> notifyme(msg="Function output:", capture_output=() -> sum(rand(100)))
```

"""
function notifyme(;msg="done!", zulip_channel="alerts", zulip_topic="MERA Notification", 
                  image_path=nothing, attachments=nothing, attachment_folder=nothing, 
                  max_attachments=10, max_file_size=25_000_000, capture_output=nothing, start_time=nothing,
                  include_timing=false, timing_details=false, exception_context=nothing,
                  include_stacktrace=true)
    
    # Handle time tracking and performance metrics
    timing_info = ""
    if start_time !== nothing || include_timing
        current_time = time()
        
        if start_time !== nothing
            elapsed_time = current_time - start_time
            timing_info = "\n\n⏱️ **Execution Time:** $(round(elapsed_time, digits=2)) seconds"
            
            # Add human-readable time formatting for longer durations
            if elapsed_time >= 60
                hours = floor(elapsed_time / 3600)
                minutes = floor((elapsed_time % 3600) / 60)
                seconds = elapsed_time % 60
                
                if hours > 0
                    timing_info *= " ($(Int(hours))h $(Int(minutes))m $(round(seconds, digits=1))s)"
                else
                    timing_info *= " ($(Int(minutes))m $(round(seconds, digits=1))s)"
                end
            end
        end
        
        if timing_details
            # Collect performance metrics
            try
                gc_stats = Base.gc_num()
                timing_info *= "\n📊 **Performance Metrics:**"
                timing_info *= "\n   • Memory allocations: $(gc_stats.malloc) bytes"
                timing_info *= "\n   • GC runs: $(gc_stats.total_time)"
                timing_info *= "\n   • Julia version: $(VERSION)"
                timing_info *= "\n   • Timestamp: $(now())"
            catch e
                timing_info *= "\n⚠️ Could not collect detailed metrics: $e"
            end
        end
        
        # Append timing info to message
        msg = msg * timing_info
    end
    
    # Handle exception context and stack traces
    if exception_context !== nothing
        exception_info = "\n\n❌ **Exception Details:**"
        exception_info *= "\n**Error Type:** $(typeof(exception_context))"
        exception_info *= "\n**Error Message:** $(string(exception_context))"
        
        if include_stacktrace
            try
                # Get stack trace information
                st = stacktrace(catch_backtrace())
                exception_info *= "\n\n**Stack Trace:**"
                
                # Limit stack trace to most relevant frames (first 10)
                max_frames = min(10, length(st))
                for (i, frame) in enumerate(st[1:max_frames])
                    exception_info *= "\n$(i). $(frame.func) in $(frame.file):$(frame.line)"
                end
                
                if length(st) > max_frames
                    exception_info *= "\n... ($(length(st) - max_frames) more frames)"
                end
                
            catch st_error
                exception_info *= "\n⚠️ Could not generate stack trace: $st_error"
            end
        end
        
        # Add exception timestamp
        exception_info *= "\n\n🕐 **Exception Time:** $(now())"
        
        # Append exception info to message
        msg = msg * exception_info
    end

    # Email notification (existing)
    if isfile(homedir() * "/email.txt")
        f = open(homedir() * "/email.txt")
        email = read(f, String)
        close(f)
        email = strip(email, '\n')
        email = filter(x -> !isspace(x), email)
        run(pipeline(`echo "$msg"`, `mail -s "MERA" $email`));
    end

    # Handle output capturing if requested
    if capture_output !== nothing
        captured_text = ""
        try
            if isa(capture_output, Cmd)
                # Execute command and capture output
                captured_text = read(capture_output, String)
            elseif isa(capture_output, Function)
                # Capture output from function execution with timeout protection
                timeout_seconds = try
                    parse(Float64, get(ENV, "MERA_CAPTURE_TIMEOUT", "3"))
                catch
                    3.0
                end
                
                # Use safer capture method with explicit timeout handling
                captured_text = ""
                result_ref = Ref{Any}(nothing)
                err_ref = Ref{Any}(nothing)
                output_buffer = IOBuffer()
                
                # Create task with proper error handling
                task = @async begin
                    try
                        # Redirect stdout to buffer
                        old_stdout = stdout
                        redirect_stdout(output_buffer)
                        try
                            result_ref[] = capture_output()
                        finally
                            redirect_stdout(old_stdout)
                        end
                    catch e
                        err_ref[] = e
                    end
                end

                # Wait for completion with timeout
                start_time = time()
                timeout_reached = false
                
                while !istaskdone(task) && (time() - start_time) < timeout_seconds
                    sleep(0.01)  # Smaller sleep for better responsiveness
                end
                
                if !istaskdone(task)
                    timeout_reached = true
                    # Force task termination
                    try
                        Base.throwto(task, InterruptException())
                        sleep(0.1)  # Give task time to clean up
                    catch
                    end
                end
                
                # Extract captured output
                try
                    captured_text = String(take!(output_buffer))
                catch
                    captured_text = ""
                end
                
                # Add timeout message if needed
                if timeout_reached
                    captured_text *= "\n⚠️ Function capture timed out after $(timeout_seconds)s"
                elseif err_ref[] !== nothing
                    captured_text *= "\n⚠️ Function raised error: $(err_ref[])"
                elseif result_ref[] !== nothing && !isa(result_ref[], Nothing)
                    captured_text *= "\nFunction result: $(result_ref[])"
                end
            elseif isa(capture_output, String)
                # Treat as a shell command string - use shell to handle pipes and operators
                if Sys.iswindows()
                    captured_text = read(`cmd /c $capture_output`, String)
                else
                    captured_text = read(`sh -c $capture_output`, String)
                end
            else
                captured_text = "Unsupported capture_output type: $(typeof(capture_output))"
            end
            
            # Append captured output to message
            if !isempty(strip(captured_text))
                msg = msg * "\n\n--- Captured Output ---\n" * captured_text
            end
            
        catch e
            # If capture fails, add error info to message
            msg = msg * "\n\n--- Capture Error ---\nFailed to capture output: $e"
        end
    end

    # Process file attachments - consolidate all attachment sources into a single list
    files_to_attach = String[]
    
    # Add single image if specified (backward compatibility)
    if image_path !== nothing && isfile(image_path)
        push!(files_to_attach, image_path)
    elseif image_path !== nothing
        # Handle error case for single image
        msg = msg * "\n\n⚠️ Warning: Image file not found: $image_path"
    end
    
    # Add multiple attachments if specified
    if attachments !== nothing
        for file_path in attachments
            if isfile(file_path)
                push!(files_to_attach, file_path)
            else
                msg = msg * "\n\n⚠️ Warning: Attachment file not found: $file_path"
            end
        end
    end
    
    # Add files from folder if specified
    if attachment_folder !== nothing
        if isdir(attachment_folder)
            # Define supported image extensions
            image_extensions = [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".bmp", ".tiff", ".tif"]
            
            # Get all files in the folder
            all_files = []
            try
                all_files = readdir(attachment_folder, join=true)
            catch e
                msg = msg * "\n\n⚠️ Warning: Could not read attachment folder: $attachment_folder (Error: $e)"
            end
            
            # Filter for image files
            image_files = filter(f -> isfile(f) && any(lowercase(splitext(f)[2]) .== image_extensions), all_files)
            
            # Sort by modification time (newest first) and limit count
            try
                image_files = sort(image_files, by=f -> stat(f).mtime, rev=true)
                if length(image_files) > max_attachments
                    msg = msg * "\n\n📁 Note: Found $(length(image_files)) image files in folder, attaching newest $max_attachments"
                    image_files = image_files[1:max_attachments]
                elseif length(image_files) > 0
                    msg = msg * "\n\n📁 Found $(length(image_files)) image files in folder: $(attachment_folder)"
                end
            catch e
                msg = msg * "\n\n⚠️ Warning: Error sorting files in folder: $e"
            end
            
            # Add to attachment list
            append!(files_to_attach, image_files)
        else
            msg = msg * "\n\n⚠️ Warning: Attachment folder not found: $attachment_folder"
        end
    end
    
    # Remove duplicates while preserving order
    unique_files = String[]
    for file in files_to_attach
        if !(file in unique_files)
            push!(unique_files, file)
        end
    end
    files_to_attach = unique_files

    # Zulip notification
    zulip_config_path = homedir() * "/zulip.txt"
    if isfile(zulip_config_path)
        try
            # Configuration / behavior controls
            zulip_timeout = try
                parse(Float64, get(ENV, "MERA_ZULIP_TIMEOUT", "10"))
            catch
                10.0
            end
            zulip_dry_run = get(ENV, "MERA_ZULIP_DRY_RUN", "false") == "true"

            if zulip_dry_run
                println("[Zulip dry-run] Would send message to channel='$(zulip_channel)' topic='$(zulip_topic)' (attachments=$(length(files_to_attach)))")
                return
            end

            zulip_config = split(read(zulip_config_path, String), '\n')
            zulip_email = strip(zulip_config[1])
            zulip_api_key = strip(zulip_config[2])
            zulip_server = strip(zulip_config[3])

            # Send initial message (with timeouts)
            url = zulip_server * "/api/v1/messages"
            headers = [
                "Authorization" => "Basic " * simple_base64encode(zulip_email * ":" * zulip_api_key)
            ]
            form_data = [
                "type" => "stream",
                "to" => zulip_channel,
                "topic" => zulip_topic,
                "content" => msg
            ]
            try
                HTTP.request("POST", url, headers, HTTP.Form(form_data); connect_timeout=Int(zulip_timeout), readtimeout=Int(zulip_timeout))
            catch e
                println("Warning: Zulip primary message POST failed (timeout=$(zulip_timeout)s): $e")
            end

            # Handle file attachments
            if !isempty(files_to_attach)
                upload_url = zulip_server * "/api/v1/user_uploads"
                attachment_links = String[]
                for (i, file_path) in enumerate(files_to_attach)
                    try
                        file_ext = lowercase(splitext(file_path)[2])
                        image_extensions = [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".bmp", ".tiff", ".tif"]
                        optimized_path = file_path
                        was_optimized = false
                        if file_ext in image_extensions
                            optimized_path, was_optimized = optimize_image_for_zulip(file_path, max_dimension=1024, max_file_size=1_000_000)
                        else
                            file_size = stat(optimized_path).size
                            if file_size > max_file_size
                                size_mb = round(file_size / 1_000_000, digits=2)
                                limit_mb = round(max_file_size / 1_000_000, digits=2)
                                error_msg = "⚠️ File too large: $(basename(file_path)) ($(size_mb) MB > $(limit_mb) MB limit)"
                                push!(attachment_links, error_msg)
                                println("Warning: Skipping large file: $(file_path) ($(size_mb) MB)")
                                continue
                            end
                        end
                        boundary = "----WebKitFormBoundary" * string(rand(UInt64), base=16)
                        content_type = "multipart/form-data; boundary=" * boundary
                        file_content = read(optimized_path)
                        filename = basename(file_path)
                        body = "--" * boundary * "\r\n"
                        body *= "Content-Disposition: form-data; name=\"file\"; filename=\"" * filename * "\"\r\n"
                        body *= "Content-Type: application/octet-stream\r\n\r\n"
                        body_bytes = Vector{UInt8}(body)
                        append!(body_bytes, file_content)
                        append!(body_bytes, Vector{UInt8}("\r\n--" * boundary * "--\r\n"))
                        img_headers = [
                            "Authorization" => "Basic " * simple_base64encode(zulip_email * ":" * zulip_api_key),
                            "Content-Type" => content_type
                        ]
                        try
                            resp = HTTP.request("POST", upload_url, img_headers, body_bytes; connect_timeout=Int(zulip_timeout), readtimeout=Int(zulip_timeout))
                            file_info = JSON.parse(String(resp.body))
                            if was_optimized && optimized_path != file_path
                                try
                                    rm(dirname(optimized_path), recursive=true)
                                catch
                                end
                            end
                            returned_filename = file_info["filename"]
                            file_url = file_info["url"]
                            clean_filename = replace(returned_filename, "[" => "", "]" => "")
                            push!(attachment_links, "[$(clean_filename)]($(file_url))")
                        catch e
                            push!(attachment_links, "⚠️ Failed to upload $(basename(file_path)): $e")
                            println("Warning: File upload failed for $(file_path): $e")
                        end
                    catch e
                        push!(attachment_links, "⚠️ Attachment processing error for $(basename(file_path)): $e")
                        println("Warning: Attachment processing error for $(file_path): $e")
                    end
                end
                if !isempty(attachment_links)
                    attachments_msg = if length(files_to_attach) == 1
                        "📎 **Attachment:**\n" * join(attachment_links, "\n")
                    else
                        "📎 **Attachments ($(length(attachment_links))):**\n" * join(attachment_links, "\n")
                    end
                    attachment_form_data = [
                        "type" => "stream",
                        "to" => zulip_channel,
                        "topic" => zulip_topic,
                        "content" => attachments_msg
                    ]
                    try
                        HTTP.request("POST", url, headers, HTTP.Form(attachment_form_data); connect_timeout=Int(zulip_timeout), readtimeout=Int(zulip_timeout))
                    catch e
                        println("Warning: Zulip attachment message POST failed: $e")
                    end
                end
            end
        catch e
            println("Warning: Zulip notification failed: ", e)
            if !isempty(files_to_attach)
                println("Note: $(length(files_to_attach)) file(s) were not uploaded due to Zulip error")
            end
        end
    end
    return
end

"""
### Send multiple plots or results with a single notification

Convenience function for common research workflows where you want to share
multiple files (plots, data, results) at once.

**Parameters:**
- msg: Message to send
- folder: Path to folder containing files to attach
- file_pattern: Pattern to match files (default: images only)
- max_files: Maximum number of files to attach (default: 10)
- zulip_channel: Zulip channel/stream name (default: "results")
- zulip_topic: Zulip topic name (default: "Analysis Results")

**Examples:**
```julia
# Send all plots from analysis folder
send_results("Temperature analysis complete!", "./plots/")

# Send specific files
send_results("Key results ready!", ["figure1.png", "data.csv", "summary.txt"])

# Send with custom channel and topic
send_results("Paper plots ready!", "./figures/", 
             zulip_channel="publications", zulip_topic="Paper 1 - Figures")
```
"""
function send_results(msg::String, source; 
                     file_pattern=r"\.(png|jpg|jpeg|gif|svg|webp|bmp|tiff|tif)$"i,
                     max_files=10,
                     max_file_size=25_000_000,
                     zulip_channel="results", 
                     zulip_topic="Analysis Results")
    if isa(source, String) && isdir(source)
        # Source is a folder - attach matching files
        notifyme(msg=msg, 
                attachment_folder=source, 
                max_attachments=max_files,
                max_file_size=max_file_size,
                zulip_channel=zulip_channel, 
                zulip_topic=zulip_topic)
    elseif isa(source, Vector)
        # Source is a list of files
        notifyme(msg=msg, 
                attachments=source,
                max_file_size=max_file_size,
                zulip_channel=zulip_channel, 
                zulip_topic=zulip_topic)
    else
        error("Source must be either a folder path (String) or list of file paths (Vector)")
    end
end

"""
### Get cross-platform system information command string

Returns the appropriate command string for getting system information 
(memory, disk, CPU) based on the current operating system.

**Usage Examples (use carefully - exposes system info):**
```julia
julia> cmd = get_system_info_command()  # Get command string
julia> notifyme(msg="System status:", capture_output=cmd)  # Consider privacy implications
```

```julia
julia> cmd = get_memory_info_command()  
julia> notifyme(msg="Memory status:", capture_output=cmd)
```

**Cross-platform compatibility:**
- **macOS**: Uses vm_stat, memory_pressure, df, sysctl
- **Linux**: Uses free, df, /proc/meminfo, /proc/cpuinfo  
- **Windows**: Uses wmic, systeminfo commands
"""
function get_system_info_command()
    if Sys.iswindows()
        # Windows: Use wmic and systeminfo for comprehensive system information
        return "systeminfo | findstr /B /C:\"OS Name\" /C:\"OS Version\" /C:\"System Type\" /C:\"Total Physical Memory\" /C:\"Available Physical Memory\" && echo. && echo --- Disk Information --- && wmic logicaldisk get size,freespace,caption,description /format:table && echo. && echo --- CPU Information --- && wmic cpu get name,maxclockspeed,numberofcores /format:table"
    elseif Sys.islinux()
        # Linux: Use standard Linux tools for system information
        return "echo '=== System Information ===' && uname -a && echo && echo '=== Memory Information ===' && free -h && echo && echo '=== Disk Information ===' && df -h && echo && echo '=== CPU Information ===' && cat /proc/cpuinfo | grep 'model name' | head -1 && cat /proc/cpuinfo | grep 'cpu cores' | head -1"
    else  # macOS
        # macOS: Use Darwin-specific tools for system information
        return "echo '=== System Information ===' && uname -a && echo && echo '=== Memory Information ===' && vm_stat && echo && echo '=== Memory Pressure ===' && memory_pressure && echo && echo '=== Disk Information ===' && df -h && echo && echo '=== CPU Information ===' && sysctl -n machdep.cpu.brand_string && sysctl -n hw.ncpu | sed 's/^/CPU Cores: /'"
    end
end

"""
### Get cross-platform memory information command string

Returns the appropriate command string for getting detailed memory information 
based on the current operating system.

**Usage Example (use carefully - exposes system info):**
```julia
julia> cmd = get_memory_info_command()  # Get command string only
julia> notifyme(msg="Memory status:", capture_output=cmd)  # Use judiciously
```

**Platform-specific commands:**
- **macOS**: vm_stat + memory_pressure (native Darwin tools)
- **Linux**: free + /proc/meminfo (standard Linux memory tools)
- **Windows**: wmic memory queries (Windows Management Interface)
"""
function get_memory_info_command()
    if Sys.iswindows()
        # Windows: Use wmic for detailed memory information
        return "echo === Memory Summary === && wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /value && echo. && echo === Total Physical Memory === && wmic computersystem get TotalPhysicalMemory /value && echo. && echo === Memory Usage === && tasklist /fo csv | head -10"
    elseif Sys.islinux()
        # Linux: Use free and /proc/meminfo for comprehensive memory info
        return "echo '=== Memory Summary ===' && free -h && echo && echo '=== Detailed Memory Information ===' && cat /proc/meminfo | head -15 && echo && echo '=== Memory Usage by Process (Top 5) ===' && ps aux --sort=-%mem | head -6"
    else  # macOS
        # macOS: Use vm_stat and memory_pressure for Darwin memory info
        return "echo '=== Virtual Memory Statistics ===' && vm_stat && echo && echo '=== Memory Pressure ===' && memory_pressure && echo && echo '=== Memory Usage by Process (Top 5) ===' && top -l 1 -n 5 -o mem | head -15"
    end
end

"""
### Get cross-platform disk information command string

Returns the appropriate command string for getting disk usage information
based on the current operating system.

**Usage Example (use carefully - exposes disk info):**
```julia
julia> cmd = get_disk_info_command()  # Get command string
julia> notifyme(msg="Disk status:", capture_output=cmd)  # Use only when necessary
```
"""
function get_disk_info_command()
    if Sys.iswindows()
        # Windows: Use wmic for disk information
        return "echo === Disk Usage === && wmic logicaldisk get size,freespace,caption,description,volumename /format:table"
    elseif Sys.islinux()
        # Linux: Use df and additional disk info
        return "echo '=== Disk Usage ===' && df -h && echo && echo '=== Disk I/O Statistics ===' && iostat -d 1 1 2>/dev/null || echo 'iostat not available'"
    else  # macOS
        # macOS: Use df and diskutil for comprehensive disk info
        return "echo '=== Disk Usage ===' && df -h && echo && echo '=== Disk Information ===' && diskutil list | head -20"
    end
end

"""
### Get cross-platform network information command string

Returns the appropriate command string for getting network configuration
based on the current operating system.

**Usage Example (use carefully - exposes network info):**
```julia
julia> cmd = get_network_info_command()  # Get command string
julia> notifyme(msg="Network status:", capture_output=cmd)  # Consider privacy implications
```
"""
function get_network_info_command()
    if Sys.iswindows()
        # Windows: Use ipconfig and netstat
        return "echo === Network Configuration === && ipconfig /all && echo. && echo === Network Connections === && netstat -an | findstr ESTABLISHED | head -5"
    elseif Sys.islinux()
        # Linux: Use ip and ss commands
        return "echo '=== Network Interfaces ===' && ip addr show && echo && echo '=== Network Connections ===' && ss -tuln | head -10"
    else  # macOS
        # macOS: Use ifconfig and netstat
        return "echo '=== Network Interfaces ===' && ifconfig && echo && echo '=== Network Connections ===' && netstat -an | grep ESTABLISHED | head -5"
    end
end

"""
### Get cross-platform process information command string

Returns the appropriate command string for getting running process information
based on the current operating system.

**Usage Example (use carefully - exposes process info):**
```julia
julia> cmd = get_process_info_command()  # Get command string
julia> notifyme(msg="Process status:", capture_output=cmd)  # Use only when necessary
```
"""
function get_process_info_command()
    if Sys.iswindows()
        # Windows: Use tasklist and wmic
        return "echo === Top Processes by CPU === && wmic process get name,processid,percentprocessortime /format:table | head -10 && echo. && echo === Top Processes by Memory === && tasklist /fo table | head -10"
    elseif Sys.islinux()
        # Linux: Use ps and top
        return "echo '=== Top Processes by CPU ===' && ps aux --sort=-%cpu | head -6 && echo && echo '=== Top Processes by Memory ===' && ps aux --sort=-%mem | head -6"
    else  # macOS
        # macOS: Use top and ps
        return "echo '=== Top Processes by CPU ===' && top -l 1 -n 5 -o cpu | head -15 && echo && echo '=== Top Processes by Memory ===' && top -l 1 -n 5 -o mem | head -15"
    end
end

# ====================================================================================
# Time Tracking and Progress Notification Functions
# ====================================================================================

"""
### Track execution time and send notification with timing information

Convenience function that automatically tracks execution time of a code block
and sends a notification with timing details.

**Parameters:**
- task_name: Description of the task being timed
- code_block: Function or code to execute and time
- zulip_channel: Zulip channel for notification (default: "timing")
- zulip_topic: Zulip topic for notification (default: "Execution Times")
- include_details: Include detailed performance metrics (default: false)

**Examples:**
```julia
# Time a function execution
timed_notify("Data processing", () -> process_large_dataset())

# Time with detailed metrics
timed_notify("Complex analysis", () -> analyze_galaxy_formation(), 
             include_details=true, zulip_channel="research")

# Time with custom messaging
timed_notify("Simulation run #47", () -> run_simulation(params), 
             zulip_channel="simulations", zulip_topic="Run Times")
```
"""
function timed_notify(task_name::String, code_block::Function; 
                     zulip_channel="timing", zulip_topic="Execution Times",
                     include_details=false, max_file_size=25_000_000)
    start_time = time()
    
    try
        println("⏱️ Starting: $task_name")
        result = code_block()
        
        notifyme("✅ **$task_name** completed successfully!", 
                start_time=start_time,
                timing_details=include_details,
                max_file_size=max_file_size,
                zulip_channel=zulip_channel,
                zulip_topic=zulip_topic)
        
        return result
        
    catch e
        notifyme("❌ **$task_name** failed!", 
                start_time=start_time,
                exception_context=e,
                timing_details=include_details,
                max_file_size=max_file_size,
                zulip_channel=zulip_channel,
                zulip_topic=zulip_topic)
        
        rethrow(e)
    end
end

"""
### Progress tracking with automatic time-based notifications

Creates a progress tracker that automatically sends notifications at specified
time intervals or progress milestones.

**Parameters:**
- total_items: Total number of items to process
- time_interval: Send notification every N seconds (default: 300 = 5 minutes)
- progress_interval: Send notification every N% progress (default: 10%)
- task_name: Name of the task for notifications
- zulip_channel: Zulip channel (default: "progress")
- zulip_topic: Zulip topic (default: "Task Progress")

**Returns:** ProgressTracker object with update!() method

**Examples:**
```julia
# Create progress tracker for 1000 items, notify every 5 minutes or 10% progress
tracker = create_progress_tracker(1000, task_name="Galaxy analysis")

for i in 1:1000
    # Do some work
    process_galaxy(i)
    
    # Update progress (automatically sends notifications at intervals)
    update_progress!(tracker, i)
end

# Final completion notification
complete_progress!(tracker)
```
"""
function create_progress_tracker(total_items::Int; 
                               time_interval=300,  # 5 minutes
                               progress_interval=10,  # 10%
                               task_name="Processing",
                               zulip_channel="progress",
                               zulip_topic="Task Progress")
    
    return Dict(
        :total => total_items,
        :current => 0,
        :start_time => time(),
        :last_notification_time => time(),
        :last_notification_progress => 0,
        :time_interval => time_interval,
        :progress_interval => progress_interval,
        :task_name => task_name,
        :zulip_channel => zulip_channel,
        :zulip_topic => zulip_topic
    )
end

"""
### Update progress tracker and send notifications if thresholds are met

**Parameters:**
- tracker: Progress tracker created by create_progress_tracker()
- current_item: Current item number being processed
- custom_message: Optional custom message for this update

**Examples:**
```julia
tracker = create_progress_tracker(1000, task_name="Data analysis")

for i in 1:1000
    analyze_data_point(i)
    update_progress!(tracker, i)
    
    # Optional: Add custom message for specific milestones
    if i == 500
        update_progress!(tracker, i, "Reached halfway point - results looking good!")
    end
end
```
"""
function update_progress!(tracker::Dict, current_item::Int, custom_message::String="")
    tracker[:current] = current_item
    current_time = time()
    
    # Calculate progress percentage
    progress_percent = (current_item / tracker[:total]) * 100
    
    # Check if we should send a notification
    time_since_last = current_time - tracker[:last_notification_time]
    progress_since_last = progress_percent - tracker[:last_notification_progress]
    
    should_notify = false
    notification_reason = ""
    
    if time_since_last >= tracker[:time_interval]
        should_notify = true
        notification_reason = "time interval"
    elseif progress_since_last >= tracker[:progress_interval]
        should_notify = true
        notification_reason = "progress milestone"
    end
    
    if should_notify
        # Calculate estimated time remaining
        elapsed_time = current_time - tracker[:start_time]
        if current_item > 0
            estimated_total_time = elapsed_time * (tracker[:total] / current_item)
            remaining_time = estimated_total_time - elapsed_time
        else
            remaining_time = 0
        end
        
        # Format progress message
        progress_msg = "📊 **$(tracker[:task_name])** Progress Update"
        progress_msg *= "\n• **Progress:** $current_item/$(tracker[:total]) ($(round(progress_percent, digits=1))%)"
        progress_msg *= "\n• **Elapsed:** $(round(elapsed_time/60, digits=1)) minutes"
        
        if remaining_time > 0
            progress_msg *= "\n• **ETA:** $(round(remaining_time/60, digits=1)) minutes remaining"
        end
        
        progress_msg *= "\n• **Rate:** $(round(current_item/elapsed_time, digits=1)) items/second"
        progress_msg *= "\n• **Notification trigger:** $notification_reason"
        
        if !isempty(custom_message)
            progress_msg *= "\n\n💬 **Custom Update:** $custom_message"
        end
        
        notifyme(progress_msg,
                zulip_channel=tracker[:zulip_channel],
                zulip_topic=tracker[:zulip_topic])
        
        # Update tracking variables
        tracker[:last_notification_time] = current_time
        tracker[:last_notification_progress] = progress_percent
    end
end

"""
### Send final completion notification for progress tracker

**Parameters:**
- tracker: Progress tracker to complete
- final_message: Optional final message
- include_summary: Include full execution summary (default: true)

**Examples:**
```julia
tracker = create_progress_tracker(1000, task_name="Simulation")
# ... do work with update_progress! calls ...
complete_progress!(tracker, "All galaxies processed successfully!")
```
"""
function complete_progress!(tracker::Dict, final_message::String=""; include_summary=true)
    total_time = time() - tracker[:start_time]
    
    completion_msg = "🎉 **$(tracker[:task_name])** COMPLETED!"
    
    if !isempty(final_message)
        completion_msg *= "\n\n$final_message"
    end
    
    if include_summary
        completion_msg *= "\n\n📈 **Execution Summary:**"
        completion_msg *= "\n• **Total items:** $(tracker[:total])"
        completion_msg *= "\n• **Total time:** $(round(total_time/60, digits=1)) minutes"
        completion_msg *= "\n• **Average rate:** $(round(tracker[:total]/total_time, digits=1)) items/second"
        completion_msg *= "\n• **Completed at:** $(now())"
    end
    
    notifyme(completion_msg,
            start_time=tracker[:start_time],
            zulip_channel=tracker[:zulip_channel],
            zulip_topic=tracker[:zulip_topic])
end

"""
### Enhanced exception handler with automatic notification

Wraps risky code with automatic exception notification including full context.

**Parameters:**
- code_block: Function to execute with exception handling
- task_description: Description of what the code is doing
- zulip_channel: Channel for error notifications (default: "errors")
- zulip_topic: Topic for error notifications (default: "Exception Reports")
- include_context: Include system context in error report (default: true)

**Examples:**
```julia
# Basic exception handling with notification
result = safe_execute("Galaxy temperature calculation") do
    calculate_galaxy_temperatures(data)
end

# Custom error channel and additional context
result = safe_execute("Critical simulation step", 
                     zulip_channel="critical-errors",
                     include_context=true) do
    run_critical_simulation_step()
end
```
"""
function safe_execute(task_description::String, code_block::Function;
                     zulip_channel="errors", zulip_topic="Exception Reports",
                     include_context=true, max_file_size=25_000_000)
    start_time = time()
    
    try
        println("🔄 Executing: $task_description")
        result = code_block()
        
        # Success notification (optional - could be made configurable)
        println("✅ Completed: $task_description")
        return result
        
    catch e
        error_msg = "💥 **Exception in:** $task_description"
        
        if include_context
            error_msg *= "\n\n🖥️ **System Context:**"
            error_msg *= "\n• Julia version: $(VERSION)"
            error_msg *= "\n• Hostname: $(gethostname())"
            error_msg *= "\n• Working directory: $(pwd())"
            error_msg *= "\n• Available memory: $(Sys.free_memory() ÷ 1024^2) MB"
        end
        
        notifyme(error_msg,
                start_time=start_time,
                exception_context=e,
                max_file_size=max_file_size,
                zulip_channel=zulip_channel,
                zulip_topic=zulip_topic)
        
        rethrow(e)
    end
end
