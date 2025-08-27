"""
Enhanced MERA.jl Documentation Build Script with Ambient Music Support

This script extends the standard documentation build process to include
optional ambient study music for users working with MERA.jl documentation.

Usage:
    julia docs/make_with_music.jl

Features:
- Builds complete MERA.jl documentation
- Integrates ambient music player into all documentation pages
- Provides user controls for music playback
- Remembers user preferences
- Mobile-responsive design
"""

using Documenter
using Mera

# Enhanced documentation configuration with music support
makedocs(
    sitename = "Mera.jl",
    authors = "Manuel Behrendt",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = [
            "assets/ambient_music_player.js",  # Add music player script
            "assets/custom_docs.css"           # Add custom styling if needed
        ],
        footer = """
            <div style="text-align: center; margin-top: 20px; color: #666; font-size: 12px;">
                🎵 Optional ambient study music available - click the music icon in the bottom right
            </div>
        """
    ),
    pages = [
        "Home" => "index.md",
        
        "Getting Started" => [
            "First Steps" => "00_multi_FirstSteps.md",
            "Installation Guide" => "installation.md"
        ],
        
        "Tutorials" => [
            "Data Inspection" => [
                "Hydro Data" => "01_hydro_First_Inspection.md",
                "Particle Data" => "01_particles_First_Inspection.md",
                "Gravity Data" => "01_gravity_First_Inspection.md",
                "Clumps Data" => "01_clumps_First_Inspection.md"
            ],
            "Data Loading" => [
                "Hydro Selection" => "02_hydro_Load_Selections.md", 
                "Particle Selection" => "02_particles_Load_Selections.md",
                "Gravity Selection" => "02_gravity_Load_Selections.md",
                "Clumps Selection" => "02_clumps_Load_Selections.md"
            ],
            "Advanced Analysis" => [
                "Hydro Subregions" => "03_hydro_Get_Subregions.md",
                "Particle Subregions" => "03_particles_Get_Subregions.md",
                "Gravity Subregions" => "03_gravity_Get_Subregions.md",
                "Clumps Subregions" => "03_clumps_Get_Subregions.md"
            ],
            "Calculations" => "04_multi_Basic_Calculations.md",
            "Masking & Filtering" => "05_multi_Masking_Filtering.md",
            "Projections" => [
                "Hydro Projections" => "06_hydro_Projection.md",
                "Particle Projections" => "06_particles_Projection.md"
            ],
            "Data Management" => [
                "Mera Files" => "07_multi_Mera_Files.md",
                "File Conversion" => "07_1_multi_Mera_Files_Converter.md"
            ]
        ],
        
        "Advanced Features" => [
            "Multi-threading" => "multi-threading/multi-threading_intro.md",
            "ParaView Export" => "paraview/paraview_intro.md",
            "Notifications System" => [
                "Overview" => "notifications/index.md",
                "Quick Start" => "notifications/01_quick_start.md",
                "Setup Guide" => "notifications/02_setup.md",
                "Email Notifications" => "notifications/email.md",
                "Zulip Integration" => "notifications/zulip.md",
                "Zulip Templates" => "notifications/zulip_templates.md",
                "File Attachments" => "notifications/03_attachments.md",
                "Output Capture" => "notifications/04_output_capture.md",
                "Advanced Features" => "notifications/05_advanced.md",
                "Examples" => "notifications/06_examples.md",
                "Troubleshooting" => "notifications/07_troubleshooting.md",
                "Bell Notifications" => "notifications/bell.md"
            ],
            "Testing Guide" => "advanced_features/testing_guide.md"
        ],
        
        "Examples" => [
            "Overview" => "examples.md",
            "Load Existing Outputs" => "examples/LoadFromExistingOutputs.md",
            "Export/Import Data" => "examples/ExportImportData.md",
            "Miscellaneous" => "examples/Miscellaneous.md"
        ],
        
        "Benchmarks" => [
            "I/O Performance" => "benchmarks/IO/IOperformance.md",
            "RAMSES Reading" => "benchmarks/RAMSES_reading/ramses_reading.md",
            "Mera Files" => "benchmarks/JLD2_reading/Mera_files_reading.md",
            "Projections" => "benchmarks/Projection/multi_projections.md"
        ],
        
        "API Reference" => [
            "Complete API" => "api.md",
            "Data Loading" => "api/data_loading.md",
            "Data Inspection" => "api/data_inspection.md", 
            "Calculations" => "api/calculations.md",
            "Masking & Filtering" => "api/masking_filtering.md",
            "Projections" => "api/projections.md",
            "Subregions" => "api/subregions.md",
            "Mera Files" => "api/mera_files.md",
            "Multithreading" => "api/multithreading.md",
            "Notifications" => "api/notifications.md",
            "Volume Rendering" => "api/volume_rendering.md",
            "Miscellaneous" => "api/miscellaneous.md",
            "Examples" => "api/examples.md"
        ],
        
        "Quick Reference" => [
            "Julia Quick Reference" => "quickreference/Julia_Quick_Reference.md",
            "Mera Quick Reference" => "quickreference/Mera_Quick_Reference.md",
            "Getting Started" => "quickreference/01_getting_started.md",
            "Migrators" => "quickreference/02_migrators.md", 
            "Packages" => "quickreference/03_packages.md",
            "Mera Patterns" => "quickreference/04_mera_patterns.md",
            "Performance" => "quickreference/05_performance.md",
            "Resources" => "quickreference/06_resources.md"
        ],
        
        "Miscellaneous" => "Miscellaneous.md",
        "Recommended Packages" => "recommended_packages.md"
    ],
    
    # Add music support message to sidebar
    sidebar_sitename = "🎵 Mera.jl",
    
    # Enhanced clean and checkdocs for better build process
    clean = true,
    checkdocs = :exports
)

# Enhanced deployment with music file support
deploydocs(
    repo = "github.com/ManuelBehrendt/Mera.jl.git",
    push_preview = true,
    
    # Custom deployment message mentioning music feature
    deploy_config = Documenter.GitHubActions(),
    
    # Ensure music assets are included in deployment
    target = "build"
)

println("📚 MERA.jl Documentation built successfully!")
println("🎵 Ambient music player integrated")
println("💡 Users can now enjoy optional background music while coding")
println("🔧 Music controls available in bottom-right corner of all pages")
println("")
println("Next steps:")
println("1. Add your ambient music file as 'docs/src/assets/mera_ambient_music.wav'")
println("2. Test the music player in built documentation")
println("3. Deploy to activate music feature for all users")

"""
Music Integration Instructions:

1. MUSIC FILE SETUP:
   - Save your ambient music as: docs/src/assets/mera_ambient_music.wav
   - Ensure file size is reasonable (< 20MB for WAV, < 10MB for MP3)
   - WAV provides higher quality, MP3 is more compressed
   
2. CUSTOMIZATION OPTIONS:
   - Edit ambient_music_player.js to change music URL
   - Modify player appearance in the CSS section
   - Add multiple music tracks if desired
   
3. USER EXPERIENCE:
   - Music player appears as floating icon in bottom-right
   - Users can control play/pause/volume
   - Preferences are saved in browser localStorage
   - Works on desktop and mobile devices
   
4. ACCESSIBILITY:
   - Music is completely optional
   - No auto-play (user must click to start)
   - Volume controls and easy muting
   - Respects user's system dark/light theme
"""