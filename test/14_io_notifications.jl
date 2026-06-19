# 14_io_notifications.jl  --  I/O Helpers & Notification Stack
# =============================================================
#
# Scope
# -----
# Two clearly separated groups of tests:
#
#   PART A (data-dependent, inside `if DATA_AVAILABLE`)
#     * bell()                         -- audio helper with documented audio-failure fallback
#     * simple_base64encode()          -- basic + empty-string sanity
#     * checkoutputs / checksimulations -- output-numbering helpers
#     * printtime()                    -- verbose/silent mode via capture_stdout
#
#   PART B (data-free, always runs)
#     * System info command helpers (5 OS-aware command-string functions)
#     * simple_base64encode extended (RFC 4648 test vectors)
#     * Progress trackers (create / update without Zulip)
#     * optimize_image_for_zulip (non-existent / small file)
#     * Zulip messaging stack (when ~/zulip.txt credentials present):
#         - notifyme: basic / positional / dry-run / start_time / timing_details
#         - capture_output: Cmd / Function / String
#         - exception_context + include_stacktrace
#         - image_path / attachment_folder / attachments  (missing-path warnings)
#         - attachments / attachment_folder with REAL files
#         - max_file_size rejection
#         - max_attachments limit
#         - send_results: folder / file-list / invalid source
#         - timed_notify: success / failure
#         - safe_execute: success / failure
#         - complete_progress! after update_progress!
#     * Email notifications (when ~/email.txt present):
#         - Email is a SIDE EFFECT of notifyme: if ~/email.txt exists,
#           every notifyme call ALSO pipes the message through the
#           system `mail` command (notifications.jl:313-319).  There is
#           no separate email function or opt-out kwarg.  The
#           EMAIL_AVAILABLE block below tests that notifyme returns
#           cleanly when email config is present.  WARNING: with
#           ~/email.txt present, running this test suite WILL send real
#           emails -- the test framework cannot suppress that.
#
# notifyme() full kwarg surface (from src/functions/notifications.jl:231)
# -----------------------------------------------------------------------
# Documented in docs/zulip_notification_tutorial.md.  Kwargs:
#   msg, zulip_channel, zulip_topic, image_path, attachments,
#   attachment_folder, max_attachments (default 10), max_file_size
#   (default 25 MB), capture_output, start_time, include_timing,
#   timing_details, exception_context, include_stacktrace.
#
# What is INTENTIONALLY NOT here
# ------------------------------
# Helper-function tests that 13 owns (after the 13 consolidation):
#   * getunit() with kpc/Msol/Myr/km_s -> 13 section 9
#   * namelist / makefile / timerfile / patchfile -> 13 section 12
#   * usedmemory thresholds -> 13 section 12
#   * checkverbose -> 13 section 10
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Used by PART A only (printtime, bell, checkoutputs context).
# Required configuration files
# ----------------------------
#   ~/zulip.txt  (optional, gates the Zulip Messaging block)
#
# If DATA_AVAILABLE is false, PART A is skipped; PART B always runs.
# If ZULIP_AVAILABLE is false, the Zulip-specific block is skipped.

using Dates

@testset "I/O and Notifications" begin

# ============================================================================
# PART A -- data-dependent tests
# ============================================================================
if DATA_AVAILABLE

    info  = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
    hydro = gethydro(info, verbose=false, show_progress=false)

    # bell() depends on the host audio stack.  On headless systems
    # (CoreAudio missing in Docker, ALSA absent, etc.) it may legitimately
    # throw.  Accept either a clean return or a recognised audio
    # exception type; do NOT silently swallow arbitrary exceptions.
    @testset "bell()" begin
        outcome = try
            bell()
            :ok
        catch e
            msg = sprint(showerror, e)
            if occursin(r"audio|AudioQueue|ALSA|CoreAudio|device"i, msg)
                :audio_unavailable
            else
                rethrow()
            end
        end
        @test outcome in (:ok, :audio_unavailable)
    end

    @testset "simple_base64encode() basic" begin
        @test Mera.simple_base64encode("test string") isa String
        @test Mera.simple_base64encode("test string") != ""
        @test Mera.simple_base64encode("")  == ""
        # Base64 always expands its input by ~33%.
        @test length(Mera.simple_base64encode("Hello")) > length("Hello")
    end

    @testset "checkoutputs / checksimulations" begin
        outputs = checkoutputs("$SIMULATION_PATH/spiral_clumps", verbose=false)
        @test outputs isa Mera.CheckOutputNumberType
        @test hasfield(typeof(outputs), :outputs)
        @test hasfield(typeof(outputs), :miss)

        sims = checksimulations(dirname("$SIMULATION_PATH/spiral_clumps"),
                                verbose=false)
        @test sims isa Dict
    end

    @testset "printtime() verbose vs silent" begin
        # verbose=true must include the message in stdout.
        out_v = capture_stdout(() -> printtime("Test message", true))
        @test contains(out_v, "Test message")
        # verbose=false must produce NO output.
        out_s = capture_stdout(() -> printtime("Silent", false))
        @test isempty(out_s)
    end

else
    @testset "PART A skipped (no simulation data)" begin
        @test_skip "Simulation data not available"
    end
end

# ============================================================================
# PART B -- data-free tests (always run)
# ============================================================================

# ----------------------------------------------------------------------------
# B.0  bell() sound selection — bundled sounds, ~/bell.txt default, list (data-free)
# ----------------------------------------------------------------------------
@testset "bell() sound selection" begin
    sounddir = joinpath(pkgdir(Mera), "src", "sounds")
    avail = sort([splitext(f)[1] for f in readdir(sounddir) if endswith(lowercase(f), ".wav")])
    # the bundled sounds are present and are real (non-empty) WAV files
    for s in ("ding", "chime", "arpeggio", "coin", "cosmic", "bloop", "done",
              "knock", "door", "bell", "gong", "strum",
              "bongo", "coindrop", "bird", "owl", "frog", "whistle", "oscillations")
        @test s in avail
        @test filesize(joinpath(sounddir, s * ".wav")) > 1000
    end
    # selection by name, Symbol and number all map to the same bundled file
    @test Mera._bell_resolve(:chime, avail) == "chime"
    @test Mera._bell_resolve("gong", avail) == "gong"
    @test Mera._bell_resolve(3, avail)      == avail[3]            # by index
    @test Mera._bell_resolve("3", avail)    == avail[3]            # numeric string
    @test Mera._bell_resolve(0, avail)      === nothing           # out of range
    @test Mera._bell_resolve(99, avail)     === nothing
    @test Mera._bell_resolve("nope", avail) === nothing           # unknown name
    # default resolution from a (temp) bell.txt — first line is a name OR a number
    mktempdir() do d
        cfg = joinpath(d, "bell.txt")
        write(cfg, "chime\n");        @test Mera._bell_default_sound(avail; cfg=cfg) == "chime"
        write(cfg, "  gong \n");      @test Mera._bell_default_sound(avail; cfg=cfg) == "gong"    # whitespace-tolerant
        write(cfg, "2\n");            @test Mera._bell_default_sound(avail; cfg=cfg) == avail[2]   # by number
        write(cfg, "nonsense\n");     @test Mera._bell_default_sound(avail; cfg=cfg) == "strum"    # unknown -> fallback
        @test Mera._bell_default_sound(avail; cfg=joinpath(d, "missing.txt")) == "strum"           # no file -> strum default
    end
    # bell(:list) prints the numbered catalogue and the bell.txt hint (no audio played)
    out = capture_stdout(() -> bell(:list))
    @test occursin("gong", out) && occursin("knock", out) && occursin("bell.txt", out)
end

# ----------------------------------------------------------------------------
# B.1  System info command helpers
# ----------------------------------------------------------------------------
# Return platform-appropriate shell-command strings.  The platform
# adaptation must be correct; we spot-check the command on macOS/Linux.
@testset "System info command helpers" begin

    @testset "get_system_info_command()" begin
        cmd = get_system_info_command()
        @test cmd isa String && length(cmd) > 10
        if Sys.isapple()
            @test contains(cmd, "vm_stat") || contains(cmd, "uname")
        elseif Sys.islinux()
            @test contains(cmd, "free")    || contains(cmd, "uname")
        end
    end

    @testset "get_memory_info_command()" begin
        cmd = get_memory_info_command()
        @test cmd isa String && length(cmd) > 10
        if Sys.isapple()
            @test contains(cmd, "vm_stat")
        elseif Sys.islinux()
            @test contains(cmd, "free") || contains(cmd, "/proc/meminfo")
        end
    end

    @testset "get_disk_info_command()" begin
        cmd = get_disk_info_command()
        @test cmd isa String
        @test contains(cmd, "df") || contains(cmd, "wmic")
    end

    @testset "get_network_info_command()" begin
        @test get_network_info_command() isa String
        @test length(get_network_info_command()) > 10
    end

    @testset "get_process_info_command()" begin
        @test get_process_info_command() isa String
        @test length(get_process_info_command()) > 10
    end
end

# ----------------------------------------------------------------------------
# B.2  simple_base64encode RFC 4648 test vectors
# ----------------------------------------------------------------------------
# Standard test vectors from RFC 4648 § 10.  These uniquely identify
# the encoding -- any deviation (wrong padding, wrong alphabet) breaks
# them.
@testset "simple_base64encode RFC 4648 vectors" begin
    @test Mera.simple_base64encode("f")      == "Zg=="
    @test Mera.simple_base64encode("fo")     == "Zm8="
    @test Mera.simple_base64encode("foo")    == "Zm9v"
    @test Mera.simple_base64encode("foob")   == "Zm9vYg=="
    @test Mera.simple_base64encode("fooba")  == "Zm9vYmE="
    @test Mera.simple_base64encode("foobar") == "Zm9vYmFy"

    # Encoded characters must all be in the Base64 alphabet.
    encoded = Mera.simple_base64encode("user@example.com:apikey123")
    @test all(c -> c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",
              encoded)
end

# ----------------------------------------------------------------------------
# B.3  Progress trackers (no Zulip)
# ----------------------------------------------------------------------------
# create_progress_tracker / update_progress! / complete_progress! when
# called WITHOUT a Zulip channel must operate purely on the local Dict
# state.  We pass huge interval values so nothing actually triggers.
@testset "Progress tracker (no network)" begin
    @testset "create_progress_tracker" begin
        t = create_progress_tracker(100; task_name="Test task",
                                    time_interval=9999,
                                    progress_interval=9999)
        @test t isa Dict
        @test t[:total]             == 100
        @test t[:current]           == 0
        @test t[:task_name]         == "Test task"
        @test t[:start_time]         > 0
        @test t[:time_interval]     == 9999
        @test t[:progress_interval] == 9999
    end

    @testset "update_progress! mutates :current" begin
        t = create_progress_tracker(100; task_name="Update test",
                                    time_interval=9999,
                                    progress_interval=9999)
        update_progress!(t, 10)
        @test t[:current] == 10
        update_progress!(t, 50, "Halfway there")
        @test t[:current] == 50
        update_progress!(t, 100)
        @test t[:current] == 100
    end
end

# ----------------------------------------------------------------------------
# B.4  optimize_image_for_zulip
# ----------------------------------------------------------------------------
# Returns (path, optimized::Bool).  Non-existent path → pass-through;
# small file (< target size) → also pass-through.
@testset "optimize_image_for_zulip" begin
    @testset "Non-existent file: pass-through" begin
        path, opt = optimize_image_for_zulip("/nonexistent/image.png")
        @test path == "/nonexistent/image.png"
        @test opt == false
    end

    @testset "Small file: no optimization" begin
        mktempdir() do dir
            small = joinpath(dir, "small.txt")
            write(small, "tiny content")
            path, opt = optimize_image_for_zulip(small)
            @test path == small
            @test opt == false
        end
    end
end

# ----------------------------------------------------------------------------
# B.5  Zulip messaging stack (requires ~/zulip.txt credentials)
# ----------------------------------------------------------------------------
ZULIP_AVAILABLE = isfile(joinpath(homedir(), "zulip.txt"))

if ZULIP_AVAILABLE
    # Testing strategy for the Zulip block
    # ------------------------------------
    # Every call below sends a REAL message to the Zulip server.  End-to-
    # end verification (did the message arrive in the right channel?
    # with the right body?) would require inbox access, which the test
    # framework doesn't have.  We therefore assert only that:
    #   * notifyme/send_results/timed_notify/safe_execute return
    #     `nothing` (i.e. no exception leaked from the HTTP layer)
    #   * The wrapper functions (timed_notify, safe_execute) return the
    #     closure's value when it succeeds, and propagate the exception
    #     when it fails.
    # All messages are prefixed "[TEST] " so they can be filtered/deleted
    # from the Zulip server after a CI run.
    @testset "Zulip messaging" begin
        test_channel = "Coding"
        test_topic   = "CI Notification Tests $(Dates.format(now(), "yyyy-mm-dd HH:MM"))"

        # ---- basic + positional dispatch -------------------------------
        @testset "Basic notifyme()" begin
            @test notifyme(msg="[TEST] Basic notification",
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme positional String dispatch" begin
            @test notifyme("[TEST] Positional string dispatch") === nothing
        end

        # ---- timing ----------------------------------------------------
        @testset "notifyme with start_time + include_timing" begin
            t0 = time()
            sleep(0.1)
            @test notifyme(msg="[TEST] Timed notification",
                           start_time=t0, include_timing=true,
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme with timing_details (GC / version metrics)" begin
            @test notifyme(msg="[TEST] Detailed timing",
                           start_time=time(),
                           include_timing=true, timing_details=true,
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        # ---- capture_output: Cmd / Function / String -------------------
        @testset "notifyme capture_output Cmd" begin
            @test notifyme(msg="[TEST] Captured Cmd output",
                           capture_output=`echo "Hello from Mera tests"`,
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme capture_output Function" begin
            @test notifyme(msg="[TEST] Captured Function output",
                           capture_output=() -> println("Function output captured"),
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme capture_output String" begin
            @test notifyme(msg="[TEST] Captured String command",
                           capture_output="echo 'String command test'",
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        # ---- exception reporting ---------------------------------------
        @testset "notifyme exception_context + include_stacktrace" begin
            err = try
                error("Test exception for notification")
            catch e
                e
            end
            @test notifyme(msg="[TEST] Exception report",
                           exception_context=err,
                           include_stacktrace=true,
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        # ---- attachments: MISSING paths (warning paths) ----------------
        @testset "notifyme missing image_path warning" begin
            @test notifyme(msg="[TEST] Missing image",
                           image_path="/nonexistent/image.png",
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme missing attachment_folder warning" begin
            @test notifyme(msg="[TEST] Missing folder",
                           attachment_folder="/nonexistent/folder/",
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        @testset "notifyme missing attachments warning" begin
            @test notifyme(msg="[TEST] Missing attachments",
                           attachments=["/nonexistent/file1.png",
                                        "/nonexistent/file2.csv"],
                           zulip_channel=test_channel,
                           zulip_topic=test_topic) === nothing
        end

        # ---- attachments: REAL files (happy path, documented but
        # previously untested) ------------------------------------------
        @testset "notifyme attachments with REAL files" begin
            mktempdir() do dir
                f1 = joinpath(dir, "summary.txt")
                f2 = joinpath(dir, "log.csv")
                write(f1, "Mera test attachment 1")
                write(f2, "col1,col2\n1,2\n3,4\n")
                @test notifyme(msg="[TEST] Real attachments",
                               attachments=[f1, f2],
                               zulip_channel=test_channel,
                               zulip_topic=test_topic) === nothing
            end
        end

        @testset "notifyme attachment_folder with REAL folder" begin
            mktempdir() do dir
                for i in 1:3
                    write(joinpath(dir, "file_$i.txt"), "content $i")
                end
                @test notifyme(msg="[TEST] Real folder attachments",
                               attachment_folder=dir,
                               zulip_channel=test_channel,
                               zulip_topic=test_topic) === nothing
            end
        end

        # ---- attachment policy: max_file_size + max_attachments --------
        @testset "notifyme max_file_size kwarg accepted (smoke)" begin
            # API-acceptance smoke test only: asserts notifyme returns
            # cleanly when given a file larger than max_file_size.  The
            # actual rejection-vs-silent-include behaviour cannot be
            # verified without inbox access or mocking the HTTP layer.
            # A bug that silently IGNORED max_file_size and uploaded the
            # oversized file would still pass this test.
            mktempdir() do dir
                fbig = joinpath(dir, "big.dat")
                write(fbig, repeat("x", 200))
                @test notifyme(msg="[TEST] Oversized file (max_file_size smoke)",
                               attachments=[fbig],
                               max_file_size=100,
                               zulip_channel=test_channel,
                               zulip_topic=test_topic) === nothing
            end
        end

        @testset "notifyme max_attachments kwarg accepted (smoke)" begin
            # Same smoke-test scope as above: API acceptance only, no
            # delivery verification.  A bug that silently ignored
            # max_attachments and uploaded all 5 files would still pass.
            mktempdir() do dir
                for i in 1:5
                    write(joinpath(dir, "f_$i.txt"), "x")
                end
                @test notifyme(msg="[TEST] Limited attachments (max_attachments smoke)",
                               attachment_folder=dir,
                               max_attachments=2,
                               zulip_channel=test_channel,
                               zulip_topic=test_topic) === nothing
            end
        end

        # ---- dry-run mode ----------------------------------------------
        @testset "Zulip dry-run mode" begin
            # MERA_ZULIP_DRY_RUN=true must succeed locally WITHOUT
            # actually contacting Zulip.  Restore env var on exit.
            old = get(ENV, "MERA_ZULIP_DRY_RUN", nothing)
            ENV["MERA_ZULIP_DRY_RUN"] = "true"
            try
                @test notifyme(msg="[TEST] Dry-run (should NOT be sent)",
                               zulip_channel="Coding",
                               zulip_topic="dry-run") === nothing
            finally
                if old === nothing
                    delete!(ENV, "MERA_ZULIP_DRY_RUN")
                else
                    ENV["MERA_ZULIP_DRY_RUN"] = old
                end
            end
        end
    end

    # send_results: dispatches on String (raw message) + source (folder /
    # file list / invalid).
    @testset "send_results()" begin
        ch    = "Coding"
        topic = "CI send_results $(Dates.format(now(), "yyyy-mm-dd HH:MM"))"

        @testset "send_results with folder" begin
            mktempdir() do dir
                write(joinpath(dir, "data.txt"), "test data")
                @test send_results("[TEST] Folder results", dir,
                                   zulip_channel=ch,
                                   zulip_topic=topic) === nothing
            end
        end

        @testset "send_results with file list" begin
            @test send_results("[TEST] File list results",
                               ["/nonexistent/a.png"],
                               zulip_channel=ch,
                               zulip_topic=topic) === nothing
        end

        @testset "send_results invalid source type" begin
            @test_throws ErrorException send_results("test", 42)
        end
    end

    # timed_notify: wraps a closure; reports completion time and
    # propagates any exception the closure raises.
    @testset "timed_notify()" begin
        ch    = "Coding"
        topic = "CI timed_notify $(Dates.format(now(), "yyyy-mm-dd HH:MM"))"

        @testset "Successful timed task" begin
            result = redirect_stdout(devnull) do
                timed_notify("[TEST] Quick computation",
                             () -> sum(1:100),
                             zulip_channel=ch, zulip_topic=topic)
            end
            @test result == 5050
        end

        @testset "Failed timed task propagates exception" begin
            @test_throws Exception redirect_stdout(devnull) do
                timed_notify("[TEST] Failing task",
                             () -> error("Intentional test failure"),
                             zulip_channel=ch, zulip_topic=topic)
            end
        end
    end

    # safe_execute: catches exceptions and notifies, then re-throws.
    @testset "safe_execute()" begin
        @testset "Successful execution" begin
            result = redirect_stdout(devnull) do
                safe_execute("Test computation", () -> 2 + 2,
                             zulip_channel="Coding")
            end
            @test result == 4
        end

        @testset "Failed execution propagates exception" begin
            @test_throws Exception redirect_stdout(devnull) do
                safe_execute("Failing computation",
                             () -> error("Intentional failure"),
                             zulip_channel="Coding")
            end
        end
    end

    # complete_progress! sends a final notification using a populated
    # tracker.  Must not corrupt the existing tracker fields.
    @testset "Progress tracker with Zulip (complete_progress!)" begin
        ch    = "Coding"
        topic = "CI progress $(Dates.format(now(), "yyyy-mm-dd HH:MM"))"

        tracker = create_progress_tracker(10;
                                          task_name="[TEST] Progress tracking",
                                          time_interval=0,
                                          progress_interval=0,
                                          zulip_channel=ch,
                                          zulip_topic=topic)
        update_progress!(tracker, 5, "Half done")
        @test tracker[:current] == 5

        complete_progress!(tracker, "All done!")
        @test tracker[:total]   == 10
        @test tracker[:current] == 5   # complete_progress! does not modify :current
        @test haskey(tracker, :start_time)
    end

else
    @testset "Zulip messaging skipped (no ~/zulip.txt)" begin
        @test_skip "Zulip credentials not available (~/zulip.txt)"
    end
end

# ----------------------------------------------------------------------------
# B.6  Email notifications  (requires ~/email.txt + system `mail` command)
# ----------------------------------------------------------------------------
# Email is a SIDE EFFECT of notifyme().  When ~/email.txt exists, every
# notifyme call ALSO pipes the message through `mail -s "MERA" <addr>`
# (see notifications.jl:313-319).  There is NO opt-out kwarg, NO
# separate email function, and NO dry-run mode for the email path.
#
# Testing strategy AND its known weakness
# ----------------------------------------
# We cannot verify the email actually arrived (no inbox access from the
# test process).  We can only verify that notifyme() returns cleanly
# when ~/email.txt is present, i.e. the `mail` subprocess didn't throw
# at the Julia layer.
#
# CRUCIAL: `mail` typically exits 0 whenever the message is HANDED OFF
# to the local MTA, even if the MTA then queues the message locally
# and drops it (no SMTP relay configured).  On macOS this is the
# default Postfix state.  So this assertion is a WEAK contract -- "the
# subprocess didn't error", NOT "an email was delivered".
#
# If you ran the suite, ~/email.txt was present, and no email arrived
# in your inbox, the likely cause is:
#   * macOS: Postfix is unconfigured -> message dropped locally.
#     Check `mailq` and `sudo log show --predicate 'process ==
#     "postfix"' --last 5m`.
#   * Linux: no MTA installed at all, or `sendmail` is not in PATH.
#
# A proper end-to-end email test would require modifying notifyme() to
# use an SMTP library with a checkable response, OR adding a dry-run
# env var (analogous to MERA_ZULIP_DRY_RUN) so the test can verify the
# CONSTRUCTION of the email without depending on local MTA state.
#
# IMPORTANT: with ~/email.txt present, this block triggers ONE mail
# subprocess per test run.  No way to suppress it without modifying
# notifyme().  Remove ~/email.txt before running the suite to skip.
EMAIL_AVAILABLE = isfile(joinpath(homedir(), "email.txt"))

if EMAIL_AVAILABLE
    @info "Email config present (~/email.txt) — running notification " *
          "tests will trigger a real `mail` subprocess.  See " *
          "14_io_notifications.jl header for opt-out instructions."

    # Pre-flight: is the local MTA actually delivering mail?
    #
    # Two failure modes we detect:
    #   1. MTA process is dead:   `mailq` throws or prints "mail system
    #      is down"  ->  `mail` will fail to queue.
    #   2. MTA queue is backed up: many entries in the queue means
    #      Postfix is accepting messages but cannot deliver them
    #      (typically: no SMTP relay configured to forward to the
    #      remote domain).  notifyme() returns nothing, but no email
    #      ever leaves the machine.
    #
    # On macOS the default state is "MTA up, relay unconfigured" --
    # exactly mode 2.  The check below counts queue lines starting with
    # a hex queue ID; > 5 stuck messages strongly suggests broken
    # delivery and we surface that as @test_broken.
    @testset "MTA operational pre-flight" begin
        mta_status = try
            read(pipeline(`mailq`; stderr=devnull), String)
        catch
            "mailq-failed"
        end
        mta_down = occursin(r"mail system is down|connection refused|mailq-failed"i,
                            mta_status)

        # Count queue entries: each starts with a 12+-char hex ID at line start.
        queue_count = length(collect(eachmatch(r"^[0-9A-F]{12,}"m, mta_status)))
        relay_broken = !mta_down && queue_count > 5

        if mta_down
            @info "Local MTA is DOWN (`mailq` reports unavailable). " *
                  "Emails are dropped.  On macOS: " *
                  "`sudo postfix start` and configure an outgoing relay."
            @test_broken !mta_down
        elseif relay_broken
            @info "Local MTA is UP but has $(queue_count) STUCK messages " *
                  "in the queue.  Postfix is accepting mail but cannot " *
                  "relay it -- no SMTP relay is configured. " *
                  "Run `mailq` to inspect, `sudo postsuper -d ALL` to " *
                  "clear, and configure /etc/postfix/main.cf with a " *
                  "relayhost (e.g. Gmail SMTP + App Password) before " *
                  "expecting delivery."
            @test_broken !relay_broken
        else
            @test !mta_down && !relay_broken
        end
    end

    @testset "Email notification (side effect of notifyme)" begin
        # Use the Zulip dry-run env var so this call does NOT also fire
        # off a Zulip message -- we want to test the email path in
        # isolation.  Email itself has no dry-run, so a real email is
        # still sent.
        old = get(ENV, "MERA_ZULIP_DRY_RUN", nothing)
        ENV["MERA_ZULIP_DRY_RUN"] = "true"
        try
            @test notifyme(msg="[TEST] Email-only notification " *
                               "$(Dates.format(now(), "yyyy-mm-dd HH:MM"))",
                           zulip_channel="Coding",
                           zulip_topic="email-test") === nothing
        finally
            if old === nothing
                delete!(ENV, "MERA_ZULIP_DRY_RUN")
            else
                ENV["MERA_ZULIP_DRY_RUN"] = old
            end
        end
    end
else
    @testset "Email notification skipped (no ~/email.txt)" begin
        @test_skip "Email config not available (~/email.txt)"
    end
end

end  # @testset "I/O and Notifications"
