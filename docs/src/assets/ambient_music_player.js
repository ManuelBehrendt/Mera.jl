/**
 * MERA.jl Documentation - Ambient Study Music Player
 * Optional background music for enhanced coding/analysis experience
 */

class MeraAmbientPlayer {
    constructor() {
        // Create a truly persistent iframe for the audio element
        this.ensurePersistentAudio();
        
        // Use global audio element to persist across page navigation
        if (!window.meraGlobalAudio) {
            window.meraGlobalAudio = new Audio();
            window.meraGlobalAudio.volume = 0.15;
            
            // Set up continuous state saving (store reference to avoid memory leaks)
            const saveState = () => {
                if (window.meraAmbientPlayer) {
                    window.meraAmbientPlayer.saveCurrentAudioState();
                }
            };
            
            // Save state more frequently for better persistence
            window.meraGlobalAudio.addEventListener('timeupdate', saveState);
            window.meraGlobalAudio.addEventListener('play', saveState);
            window.meraGlobalAudio.addEventListener('pause', saveState);
            window.addEventListener('beforeunload', saveState);
            
            // Also save state every 2 seconds during playback
            setInterval(() => {
                if (!window.meraGlobalAudio.paused && window.meraAmbientPlayer) {
                    window.meraAmbientPlayer.saveCurrentAudioState();
                }
            }, 2000);
        }
        this.audio = window.meraGlobalAudio;
        
        // Restore previous audio state
        this.restoreAudioState();
        
        this.isPlaying = this.audio && !this.audio.paused;
        this.volume = 0.15; // Default volume (15%) - perfect for studying
        this.musicUrl = null; // Will be set when music file is available
        this.playerVisible = false;
        this.currentTrack = null;
        this.availableTracks = [];
        this.unloadListenerSet = false;
        this.timeUpdateListenerSet = false;
        
        this.init();
    }
    
    init() {
        this.createPlayerUI();
        this.loadUserPreferences();
        this.setupEventListeners();
        
        // Restore player state if music was playing before page navigation
        if (this.isPlaying) {
            this.updatePlayButtonState();
            this.updateStatus(`Playing: ${this.getCurrentTrackName()}`);
        }
    }
    
    createPlayerUI() {
        // Check if player UI already exists
        if (document.getElementById('mera-persistent-frame') || document.getElementById('mera-ambient-player')) {
            console.log('🎵 Player UI already exists, skipping creation');
            return;
        }
        
        // Create compact music player below MERA logo
        const playerHTML = `
            <div id="mera-ambient-player" class="mera-music-player">
                <div class="mera-player-toggle" id="mera-player-toggle">
                    🎵 Study Music
                </div>
                <div class="mera-player-controls" id="mera-player-controls" style="display: none;">
                    <div class="mera-player-header">
                        <span class="mera-player-title">🎵 Study Music</span>
                        <button class="mera-player-close" id="mera-player-close">×</button>
                    </div>
                    <div class="mera-player-buttons">
                        <button id="mera-play-btn" class="mera-btn mera-play">🔀 Random Track</button>
                        <button id="mera-pause-btn" class="mera-btn mera-pause" style="display: none;">⏸️ Pause</button>
                    </div>
                    <div class="mera-volume-control">
                        <label for="mera-volume">🔊 Volume:</label>
                        <input type="range" id="mera-volume" min="0" max="100" value="15">
                        <span id="mera-volume-display">15%</span>
                    </div>
                    <div class="mera-player-status">
                        <div id="mera-status-text">Ready to play</div>
                        <div id="mera-current-track"></div>
                        <div class="mera-music-credit">
                            <small>🎼 M. Behrendt</small>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // Try to add below MERA logo in navigation with retry mechanism
        let attempts = 0;
        const maxAttempts = 5;
        
        const tryInjectPlayer = () => {
            // Create persistent top bar that never reloads
            if (!document.getElementById('mera-top-bar')) {
                // Create fixed top bar
                const topBar = document.createElement('div');
                topBar.id = 'mera-top-bar';
                topBar.style.cssText = `
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    height: 45px;
                    background: linear-gradient(135deg, rgba(102, 126, 234, 0.95) 0%, rgba(118, 75, 162, 0.95) 100%);
                    z-index: 999999;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 0 20px;
                    backdrop-filter: blur(10px);
                    border-bottom: 1px solid rgba(255,255,255,0.2);
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    box-sizing: border-box;
                `;
                
                topBar.innerHTML = `
                    <div style="display: flex; align-items: center; gap: 15px;">
                        <span style="color: white; font-weight: 600; font-size: 14px;">🎵 MERA Study Music</span>
                        <button id="mera-top-play-btn" style="
                            padding: 4px 12px;
                            background: rgba(255,255,255,0.2);
                            border: 1px solid rgba(255,255,255,0.3);
                            border-radius: 4px;
                            color: white;
                            cursor: pointer;
                            font-size: 12px;
                        ">🔀 Play Random</button>
                        <button id="mera-top-pause-btn" style="
                            padding: 4px 12px;
                            background: rgba(255,255,255,0.2);
                            border: 1px solid rgba(255,255,255,0.3);
                            border-radius: 4px;
                            color: white;
                            cursor: pointer;
                            font-size: 12px;
                            display: none;
                        ">⏸️ Pause</button>
                    </div>
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <span id="mera-top-status" style="color: rgba(255,255,255,0.9); font-size: 12px;">Ready to play</span>
                        <input type="range" id="mera-top-volume" min="0" max="100" value="15" style="
                            width: 80px;
                            height: 4px;
                            background: rgba(255,255,255,0.3);
                            outline: none;
                            border-radius: 2px;
                        ">
                        <span style="color: rgba(255,255,255,0.9); font-size: 12px;">15%</span>
                    </div>
                `;
                
                // Insert at the very beginning of document.body
                document.body.insertBefore(topBar, document.body.firstChild);
                
                // Make the top bar more persistent by using a higher z-index and attaching to documentElement
                try {
                    document.documentElement.appendChild(topBar);
                    document.body.removeChild(topBar);
                    console.log('🎵 Top bar attached to documentElement for better persistence');
                } catch (e) {
                    console.log('🎵 Top bar remains in document.body');
                }
                
                // Adjust main content to account for top bar with extra space for MERA logo
                document.documentElement.style.paddingTop = '45px';
                document.body.style.paddingTop = '45px';
                
                // Force any existing content down with margin
                const allElements = document.querySelectorAll('body > *:not(#mera-top-bar)');
                allElements.forEach(el => {
                    if (el.style.marginTop === '' || parseInt(el.style.marginTop) < 45) {
                        el.style.marginTop = '45px';
                    }
                });
                
                // Set up event listeners for top bar controls
                this.setupTopBarControls();
                
                // Set up page change monitoring to recreate the bar if needed
                this.setupPageChangeMonitoring();
                
                console.log('🎵 Persistent top bar music player created');
                return true;
            }
            
            return false;
        };
        
        // Retry mechanism for sidebar injection
        if (!tryInjectPlayer()) {
            let retryCount = 0;
            const retryInterval = setInterval(() => {
                if (tryInjectPlayer() || retryCount++ > 10) {
                    clearInterval(retryInterval);
                }
            }, 200);
        }
        
        // Add CSS styles
        this.addStyles();
    }
    
    addStyles() {
        const styles = `
            <style id="mera-player-styles">
                .mera-music-player {
                    position: relative;
                    margin: 0;
                    z-index: 100;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 220px;
                }
                
                .mera-player-toggle {
                    padding: 1px 8px;
                    background: linear-gradient(135deg, rgba(102, 126, 234, 0.5) 0%, rgba(118, 75, 162, 0.5) 100%);
                    border-radius: 2px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    cursor: pointer;
                    box-shadow: 0 0 2px rgba(0,0,0,0.05);
                    transition: transform 0.2s ease, box-shadow 0.2s ease, background 0.2s ease;
                    font-size: 9px;
                    color: rgba(255,255,255,0.8);
                    font-weight: 300;
                    border: none;
                    width: 100%;
                    height: 12px;
                }
                
                .mera-player-toggle:hover {
                    transform: translateY(-1px);
                    box-shadow: 0 2px 8px rgba(0,0,0,0.2);
                    background: linear-gradient(135deg, rgba(102, 126, 234, 0.6) 0%, rgba(118, 75, 162, 0.6) 100%);
                    color: rgba(255,255,255,0.9);
                }
                
                .mera-player-controls {
                    position: relative;
                    margin-top: 6px;
                    width: 100%;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                    border: 1px solid #e1e5e9;
                    overflow: hidden;
                    animation: mera-slideDown 0.2s ease-out;
                }
                
                @keyframes mera-slideDown {
                    from { opacity: 0; transform: translateY(-5px); }
                    to { opacity: 1; transform: translateY(0); }
                }
                
                .mera-player-header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 8px 10px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }
                
                .mera-player-title {
                    font-weight: 600;
                    font-size: 12px;
                }
                
                .mera-player-close {
                    background: none;
                    border: none;
                    color: white;
                    font-size: 14px;
                    cursor: pointer;
                    padding: 0;
                    width: 16px;
                    height: 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 50%;
                    transition: background 0.2s ease;
                }
                
                .mera-player-close:hover {
                    background: rgba(255,255,255,0.2);
                }
                
                .mera-player-buttons {
                    padding: 10px;
                    text-align: center;
                    border-bottom: 1px solid #f0f0f0;
                }
                
                .mera-btn {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border: none;
                    padding: 6px 12px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 11px;
                    font-weight: 500;
                    transition: transform 0.2s ease;
                }
                
                .mera-btn:hover {
                    transform: translateY(-1px);
                }
                
                .mera-volume-control {
                    padding: 8px 10px;
                    border-bottom: 1px solid #f0f0f0;
                }
                
                .mera-volume-control label {
                    display: block;
                    font-size: 10px;
                    font-weight: 600;
                    color: #666;
                    margin-bottom: 4px;
                }
                
                #mera-volume {
                    width: 100%;
                    height: 4px;
                    margin-bottom: 3px;
                }
                
                #mera-volume-display {
                    font-size: 10px;
                    color: #888;
                }
                
                .mera-player-status {
                    padding: 6px 10px;
                    background: #fafafa;
                }
                
                #mera-status-text {
                    font-size: 10px;
                    color: #666;
                    margin-bottom: 2px;
                }
                
                #mera-current-track {
                    font-size: 9px;
                    color: #888;
                    font-style: italic;
                    margin-bottom: 3px;
                    text-align: center;
                }
                
                .mera-music-credit {
                    text-align: center;
                }
                
                .mera-music-credit small {
                    color: #888;
                    font-size: 9px;
                }
                
                /* Dark theme support */
                @media (prefers-color-scheme: dark) {
                    .mera-player-controls {
                        background: #2d3748;
                        border-color: #4a5568;
                        color: white;
                    }
                    
                    .mera-player-info {
                        border-color: #4a5568;
                    }
                    
                    .mera-music-title {
                        color: white;
                    }
                    
                    .mera-music-subtitle {
                        color: #a0aec0;
                    }
                    
                    .mera-player-buttons {
                        border-color: #4a5568;
                    }
                    
                    .mera-volume-control {
                        border-color: #4a5568;
                    }
                    
                    .mera-volume-control label {
                        color: #a0aec0;
                    }
                    
                    .mera-player-status {
                        background: #1a202c;
                        border-color: #4a5568;
                    }
                    
                    #mera-status-text {
                        color: #a0aec0;
                    }
                    
                    .mera-music-credit small {
                        color: #718096;
                    }
                }
                
                /* Mobile responsive */
                @media (max-width: 768px) {
                    .mera-music-player {
                        margin: 6px;
                        max-width: calc(100% - 12px);
                    }
                    
                    .mera-player-controls {
                        width: 100%;
                    }
                    
                    .mera-player-toggle {
                        font-size: 11px;
                        padding: 5px 10px;
                    }
                }
            </style>
        `;
        
        document.head.insertAdjacentHTML('beforeend', styles);
    }
    
    getPlayerCSS() {
        return `
            .mera-music-player {
                position: relative;
                margin: 0;
                z-index: 100;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                max-width: 220px;
            }
            
            .mera-player-toggle {
                padding: 1px 8px;
                background: linear-gradient(135deg, rgba(102, 126, 234, 0.5) 0%, rgba(118, 75, 162, 0.5) 100%);
                border-radius: 2px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                box-shadow: 0 0 2px rgba(0,0,0,0.05);
                transition: transform 0.2s ease, box-shadow 0.2s ease, background 0.2s ease;
                font-size: 9px;
                color: rgba(255,255,255,0.8);
                font-weight: 300;
                border: none;
                width: 100%;
                height: 12px;
            }
            
            .mera-player-toggle:hover {
                transform: translateY(-1px);
                box-shadow: 0 2px 8px rgba(0,0,0,0.2);
                background: linear-gradient(135deg, rgba(102, 126, 234, 0.6) 0%, rgba(118, 75, 162, 0.6) 100%);
                color: rgba(255,255,255,0.9);
            }
            
            .mera-player-controls {
                background: rgba(255, 255, 255, 0.98);
                border-radius: 8px;
                padding: 12px;
                margin-top: 6px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.15);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255,255,255,0.2);
            }
            
            .mera-player-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 10px;
            }
            
            .mera-player-title {
                font-weight: 600;
                font-size: 12px;
                color: #333;
            }
            
            .mera-player-close {
                background: none;
                border: none;
                font-size: 16px;
                cursor: pointer;
                color: #666;
                padding: 0;
                width: 20px;
                height: 20px;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            
            .mera-player-buttons {
                display: flex;
                gap: 8px;
                margin-bottom: 10px;
            }
            
            .mera-btn {
                padding: 6px 12px;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 11px;
                font-weight: 500;
                transition: all 0.2s;
            }
            
            .mera-play, .mera-pause {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            
            .mera-play:hover, .mera-pause:hover {
                transform: translateY(-1px);
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
            }
            
            .mera-volume-control {
                display: flex;
                align-items: center;
                gap: 8px;
                margin-bottom: 8px;
            }
            
            .mera-volume-control label {
                font-size: 10px;
                color: #666;
                min-width: 40px;
            }
            
            .mera-volume-control input[type="range"] {
                flex: 1;
                height: 4px;
                border-radius: 2px;
                background: #ddd;
                outline: none;
            }
            
            .mera-player-status {
                font-size: 10px;
                color: #666;
                text-align: center;
            }
        `;
    }
    
    ensurePersistentAudio() {
        // Create a hidden iframe with a data URL that contains the audio element
        if (!document.getElementById('mera-audio-frame')) {
            const iframe = document.createElement('iframe');
            iframe.id = 'mera-audio-frame';
            iframe.style.cssText = 'position:fixed;top:-1000px;left:-1000px;width:1px;height:1px;opacity:0;pointer-events:none;';
            iframe.src = 'data:text/html,<html><body><script>window.persistentAudio=new Audio();window.persistentAudio.volume=0.15;</script></body></html>';
            
            document.documentElement.appendChild(iframe);
            console.log('🎵 Created persistent audio iframe');
        }
    }
    
    saveCurrentAudioState() {
        if (window.meraGlobalAudio && window.meraGlobalAudio.src) {
            const state = {
                src: window.meraGlobalAudio.src,
                currentTime: window.meraGlobalAudio.currentTime,
                volume: window.meraGlobalAudio.volume,
                paused: window.meraGlobalAudio.paused,
                timestamp: Date.now()
            };
            localStorage.setItem('mera-audio-state', JSON.stringify(state));
            console.log('🎵 Audio state saved:', state);
        }
    }
    
    restoreAudioState() {
        try {
            const savedState = localStorage.getItem('mera-audio-state');
            if (savedState && window.meraGlobalAudio) {
                const state = JSON.parse(savedState);
                
                // Only restore if state is recent (within 30 seconds)
                if (Date.now() - state.timestamp < 30000) {
                    window.meraGlobalAudio.src = state.src;
                    window.meraGlobalAudio.volume = state.volume;
                    
                    // Wait for audio to load before setting time and playing
                    window.meraGlobalAudio.addEventListener('loadedmetadata', () => {
                        window.meraGlobalAudio.currentTime = state.currentTime;
                        
                        if (!state.paused) {
                            this.isPlaying = true;
                            window.meraGlobalAudio.play().then(() => {
                                console.log('🎵 Audio restored and playing');
                                this.updatePlayButton();
                                this.updateStatus(`Resumed: ${this.getCurrentTrackName()}`);
                            }).catch(e => {
                                console.log('Auto-resume prevented:', e);
                                this.updateStatus(`Click play to resume: ${this.getCurrentTrackName()}`);
                            });
                        }
                    }, { once: true });
                    
                    console.log('🎵 Audio state restored:', state);
                }
            }
        } catch (e) {
            console.error('Error restoring audio state:', e);
        }
    }
    
    setupTopBarControls() {
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        const volumeSlider = document.getElementById('mera-top-volume');
        
        if (playBtn) {
            playBtn.addEventListener('click', () => {
                if (this.availableTracks.length === 0) {
                    this.initializeMusicLibrary();
                }
                this.play();
            });
        }
        
        if (pauseBtn) {
            pauseBtn.addEventListener('click', () => {
                this.pause();
            });
        }
        
        if (volumeSlider) {
            volumeSlider.addEventListener('input', (e) => {
                this.setVolume(e.target.value / 100);
                // Update volume display
                const volumeDisplay = volumeSlider.nextElementSibling;
                if (volumeDisplay) {
                    volumeDisplay.textContent = `${e.target.value}%`;
                }
            });
        }
    }
    
    setupPageChangeMonitoring() {
        // Monitor for URL changes (Documenter navigation)
        let currentUrl = window.location.href;
        const checkForPageChange = () => {
            if (window.location.href !== currentUrl) {
                currentUrl = window.location.href;
                console.log('🎵 Page change detected, ensuring top bar persistence...');
                
                // Save current audio state
                this.saveCurrentAudioState();
                
                // Small delay to let new page load, then recreate top bar if needed
                setTimeout(() => {
                    if (!document.getElementById('mera-top-bar')) {
                        console.log('🎵 Top bar missing after page change, recreating...');
                        this.createPlayerUI();
                        this.setupTopBarControls();
                        
                        // Restore audio state
                        this.restoreAudioState();
                        
                        // Update UI state
                        if (window.meraGlobalAudio && !window.meraGlobalAudio.paused) {
                            this.isPlaying = true;
                            this.updatePlayButton();
                            this.updateStatus(`Playing: ${this.getCurrentTrackName()}`);
                        }
                    } else {
                        // Top bar exists, just update its state
                        this.restoreAudioState();
                        if (window.meraGlobalAudio && !window.meraGlobalAudio.paused) {
                            this.updatePlayButton();
                            this.updateStatus(`Playing: ${this.getCurrentTrackName()}`);
                        }
                    }
                }, 200);
            }
        };
        
        // Check for URL changes more frequently
        if (!window.meraPageMonitor) {
            window.meraPageMonitor = setInterval(checkForPageChange, 500);
        }
    }
    
    setupEventListeners() {
        console.log('🎵 Setting up event listeners...');
        
        // Save state before page unload (only set once)
        if (!this.unloadListenerSet) {
            window.addEventListener('beforeunload', () => {
                this.saveUserPreferences();
            });
            this.unloadListenerSet = true;
        }
        
        // Also save state periodically during playback
        if (this.audio && !this.timeUpdateListenerSet) {
            this.audio.addEventListener('timeupdate', () => {
                if (this.isPlaying) {
                    this.saveUserPreferences();
                }
            });
            this.timeUpdateListenerSet = true;
        }
        
        // Toggle player visibility
        const toggleButton = document.getElementById('mera-player-toggle');
        if (toggleButton) {
            console.log('✅ Found toggle button, setting up click handler');
            // Remove any existing listeners first
            if (this.togglePlayerHandler) {
                toggleButton.removeEventListener('click', this.togglePlayerHandler);
            }
            // Bind the handler to preserve 'this' context
            this.togglePlayerHandler = () => {
                console.log('🎵 Study Music button clicked!');
                this.togglePlayer();
            };
            toggleButton.addEventListener('click', this.togglePlayerHandler);
        } else {
            console.error('❌ Toggle button not found - ID: mera-player-toggle');
        }
        
        // Close player
        const closeBtn = document.getElementById('mera-player-close');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.hidePlayer();
            });
        }
        
        // Play button
        const playBtn = document.getElementById('mera-play-btn');
        if (playBtn) {
            playBtn.addEventListener('click', () => {
                this.play();
            });
        }
        
        // Pause button  
        const pauseBtn = document.getElementById('mera-pause-btn');
        if (pauseBtn) {
            pauseBtn.addEventListener('click', () => {
                this.pause();
            });
        }
        
        // Volume control
        const volumeSlider = document.getElementById('mera-volume');
        if (volumeSlider) {
            volumeSlider.addEventListener('input', (e) => {
                this.setVolume(e.target.value / 100);
            });
        }
        
        // Optional: Click outside to close (disabled for sidebar integration)
        // document.addEventListener('click', (e) => {
        //     if (!e.target.closest('.mera-music-player') && this.playerVisible) {
        //         this.hidePlayer();
        //     }
        // });
    }
    
    togglePlayer() {
        console.log('🎵 togglePlayer() called, playerVisible:', this.playerVisible);
        const controls = document.getElementById('mera-player-controls');
        if (this.playerVisible) {
            this.hidePlayer();
        } else {
            this.showPlayer();
        }
    }
    
    showPlayer() {
        const controls = document.getElementById('mera-player-controls');
        if (controls) {
            console.log('✅ Found controls element, making visible');
            controls.style.display = 'block';
            this.playerVisible = true;
        } else {
            console.error('❌ Controls element not found - ID: mera-player-controls');
        }
        
        // Initialize with ready status - music files are available in the library
        if (this.availableTracks.length > 0) {
            this.updateStatus('Ready to play ambient music');
        } else {
            this.updateStatus('Music library loading...');
        }
    }
    
    hidePlayer() {
        document.getElementById('mera-player-controls').style.display = 'none';
        this.playerVisible = false;
    }
    
    initializeMusicLibrary() {
        // Complete astrophysical ambient music library (MP3 format for web compatibility)
        this.availableTracks = [
            { file: 'alpha_centauri.mp3', name: 'Alpha Centauri' },
            { file: 'andromeda_galaxy.mp3', name: 'Andromeda Galaxy' },
            { file: 'betelgeuse_supergiant.mp3', name: 'Betelgeuse Supergiant' },
            { file: 'cassiopeia_constellation.mp3', name: 'Cassiopeia Constellation' },
            { file: 'crab_nebula.mp3', name: 'Crab Nebula' },
            { file: 'eagle_nebula.mp3', name: 'Eagle Nebula' },
            { file: 'horsehead_nebula.mp3', name: 'Horsehead Nebula' },
            { file: 'orion_nebula.mp3', name: 'Orion Nebula' },
            { file: 'proxima_centauri.mp3', name: 'Proxima Centauri' },
            { file: 'sagittarius_a_star.mp3', name: 'Sagittarius A Star' },
            { file: 'vega.mp3', name: 'Vega' }
        ];
    }
    
    getRandomTrack() {
        if (this.availableTracks.length === 0) return null;
        const randomIndex = Math.floor(Math.random() * this.availableTracks.length);
        const selectedTrack = this.availableTracks[randomIndex];
        console.log(`Selected random track: ${selectedTrack.name} (index: ${randomIndex})`);
        return selectedTrack;
    }
    
    getCurrentTrackName() {
        if (!this.audio || !this.audio.src) return 'Unknown Track';
        const filename = this.audio.src.split('/').pop();
        return this.getTrackDisplayName(filename);
    }
    
    getTrackDisplayName(filename) {
        if (!filename) return '';
        // Convert filename to display name (handles both .wav and .mp3)
        return filename.replace(/\.(wav|mp3)$/, '').replace(/_/g, ' ')
            .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
    }
    
    async loadRandomTrack() {
        if (this.availableTracks.length === 0) {
            this.updateStatus('No music tracks available');
            return false;
        }
        
        const track = this.getRandomTrack();
        console.log(`Loading track: ${track.name}`);
        this.updateStatus(`Loading ${track.name}...`);
        
        // Determine the correct path based on context (Documenter vs local)
        let musicPath;
        const currentPath = window.location.pathname;
        const currentUrl = window.location.href;
        const hasDocumenterScript = document.querySelector('script[src*="documenter.js"]') !== null;
        const isDocumenterBuild = currentPath.includes('/build/') || 
                                  currentPath.endsWith('.html') || 
                                  hasDocumenterScript;
        
        // Debug information
        console.log(`🔍 Path Detection Debug:`);
        console.log(`  Current URL: ${currentUrl}`);
        console.log(`  Current path: ${currentPath}`);
        console.log(`  Has documenter.js: ${hasDocumenterScript}`);
        console.log(`  Detected Documenter build: ${isDocumenterBuild}`);
        
        if (window.location.protocol === 'file:' && currentPath.includes('/build/')) {
            // Direct file access to Documenter build - music files are in assets/music/ relative to index.html
            musicPath = `assets/music/${track.file}`;
        } else if (isDocumenterBuild && currentPath.includes('/build/')) {
            // Web server access to /docs/build/ path
            musicPath = `assets/music/${track.file}`;
        } else if (currentUrl.includes('localhost') || currentUrl.includes('127.0.0.1')) {
            // Local development/testing
            musicPath = `docs/src/assets/music/${track.file}`;
        } else {
            // GitHub Pages or other web deployment
            musicPath = `assets/music/${track.file}`;
        }
        
        console.log(`🎵 Final music path: ${musicPath}`);
        
        // Create and configure audio element
        this.currentTrack = track;
        this.musicUrl = musicPath;
        
        if (this.audio) {
            this.audio.pause();
            this.audio = null;
        }
        
        try {
            this.audio = new Audio(musicPath);
            this.audio.loop = true;
            this.audio.preload = 'metadata'; // Better browser compatibility
            this.audio.volume = this.volume;
            
            // Cross-browser compatibility
            this.audio.crossOrigin = 'anonymous';
            
            // Set up event listeners for working music player
            this.audio.addEventListener('canplaythrough', () => {
                console.log(`✅ ${track.name} ready to play`);
                this.updateStatus(`Ready - Click Play to start`);
                this.updateCurrentTrack(track.name);
                const playBtn = document.getElementById('mera-play-btn');
                if (playBtn) playBtn.disabled = false;
            });
            
            this.audio.addEventListener('canplay', () => {
                console.log(`Can play: ${track.name}`);
                this.updateStatus(`Ready - Click Play to start`);
                const playBtn = document.getElementById('mera-play-btn');
                if (playBtn) playBtn.disabled = false;
            });
            
            this.audio.addEventListener('loadstart', () => {
                console.log(`Loading ${track.name}...`);
            });
            
            this.audio.addEventListener('ended', () => {
                if (this.isPlaying) {
                    this.loadRandomTrack().then(() => {
                        if (this.audio) {
                            this.audio.play();
                        }
                    });
                }
            });
            
            this.audio.addEventListener('error', (e) => {
                console.error('Audio error:', e);
                if (window.location.protocol === 'file:') {
                    this.updateStatus('❗ Music requires web server (use localhost:8080)');
                } else {
                    this.updateStatus('Music file not accessible');
                }
                const playBtn = document.getElementById('mera-play-btn');
                if (playBtn) playBtn.disabled = true;
            });
            
            return true;
            
        } catch (error) {
            console.error(`Error setting up audio: ${error.message}`);
            this.updateStatus('Music not available');
            return false;
        }
    }
    
    async play() {
        // Load and play a random track
        const trackLoaded = await this.loadRandomTrack();
        
        if (!trackLoaded || !this.audio) {
            this.updateStatus('No music available');
            return;
        }
        
        try {
            // Create a promise to handle play() with timeout for better browser support
            const playPromise = this.audio.play();
            
            if (playPromise !== undefined) {
                await playPromise;
                this.isPlaying = true;
                this.updatePlayButton();
                console.log(`Now playing: ${this.currentTrack.name}`);
                this.updateStatus(`🎵 Playing - Volume ${Math.round(this.volume * 100)}%`);
                this.updateCurrentTrack(this.currentTrack.name);
                this.saveUserPreferences();
            }
        } catch (error) {
            console.error('Error playing music:', error);
            
            // Handle specific browser autoplay policies
            if (error.name === 'NotAllowedError') {
                this.updateStatus('Click Play to start music (browser requires interaction)');
            } else if (error.name === 'NotSupportedError') {
                this.updateStatus('Music format not supported by browser');
            } else {
                this.updateStatus(`Error playing music: ${error.message}`);
            }
        }
    }
    
    pause() {
        if (this.audio) {
            this.audio.pause();
            this.isPlaying = false;
            this.updatePlayButton();
            this.updateStatus('Music paused');
            this.saveUserPreferences();
        }
    }
    
    setVolume(volume) {
        this.volume = Math.max(0, Math.min(1, volume));
        if (this.audio) {
            this.audio.volume = this.volume;
        }
        
        // Update volume display - check iframe first, then main document
        const iframe = document.getElementById('mera-persistent-frame');
        let volumeSlider = null;
        let volumeDisplay = null;
        
        if (iframe && iframe.contentDocument) {
            volumeSlider = iframe.contentDocument.getElementById('mera-volume');
            volumeDisplay = iframe.contentDocument.getElementById('mera-volume-display');
        } else {
            volumeSlider = document.getElementById('mera-volume');
            volumeDisplay = document.getElementById('mera-volume-display');
        }
        
        if (volumeSlider) {
            volumeSlider.value = this.volume * 100;
        }
        if (volumeDisplay) {
            volumeDisplay.textContent = Math.round(this.volume * 100) + '%';
        }
        
        this.saveUserPreferences();
    }
    
    updatePlayButton() {
        // Update play buttons in top bar
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        
        if (playBtn && pauseBtn) {
            if (this.isPlaying) {
                playBtn.style.display = 'none';
                pauseBtn.style.display = 'inline-block';
            } else {
                playBtn.style.display = 'inline-block';
                pauseBtn.style.display = 'none';
            }
        }
    }
    
    updateStatus(message) {
        // Update status in top bar
        const topBarStatus = document.getElementById('mera-top-status');
        if (topBarStatus) {
            topBarStatus.textContent = message;
        }
    }
    
    updateCurrentTrack(trackName) {
        // Update current track in iframe first, then main document
        const iframe = document.getElementById('mera-persistent-frame');
        let trackElement = null;
        
        if (iframe && iframe.contentDocument) {
            trackElement = iframe.contentDocument.getElementById('mera-current-track');
        } else {
            trackElement = document.getElementById('mera-current-track');
        }
        
        if (trackElement) {
            trackElement.textContent = trackName ? `♪ ${trackName}` : '';
        }
    }
    
    saveUserPreferences() {
        const prefs = {
            volume: this.volume,
            wasPlaying: this.isPlaying,
            currentTrack: this.audio ? this.audio.src : null,
            currentTime: this.audio ? this.audio.currentTime : 0
        };
        localStorage.setItem('mera-music-prefs', JSON.stringify(prefs));
    }
    
    loadUserPreferences() {
        const prefs = localStorage.getItem('mera-music-prefs');
        if (prefs) {
            const parsed = JSON.parse(prefs);
            this.setVolume(parsed.volume || 0.15);
            
            // Restore track info but don't auto-play
            if (parsed.wasPlaying && parsed.currentTrack && window.meraGlobalAudio) {
                window.meraGlobalAudio.src = parsed.currentTrack;
                window.meraGlobalAudio.currentTime = parsed.currentTime || 0;
                this.isPlaying = false; // Don't auto-play
                this.updateStatus(`Ready to resume: ${this.getCurrentTrackName()}`);
                this.updatePlayButton();
            }
        }
    }
    
    // Legacy method - now uses random track selection
    setMusicUrl(url) {
        console.log('setMusicUrl called - now using random track selection instead');
    }
    
    // Method to show introduction message
    showIntroduction() {
        if (!localStorage.getItem('mera-music-intro-shown')) {
            setTimeout(() => {
                this.showPlayer();
                this.updateStatus('🎵 New: Optional ambient study music!');
                localStorage.setItem('mera-music-intro-shown', 'true');
                
                // Auto-hide after 5 seconds if user doesn't interact
                setTimeout(() => {
                    if (this.playerVisible && !this.isPlaying) {
                        this.hidePlayer();
                    }
                }, 5000);
            }, 2000); // Show after 2 seconds on page load
        }
    }
}

// Store player initialization in window for persistence across page reloads
if (!window.meraPlayerPersistent) {
    window.meraPlayerPersistent = true;
    
    // Create a persistent interval that checks for and recreates the player
    setInterval(() => {
        if (!document.getElementById('mera-top-bar') && document.body) {
            console.log('🎵 Recreating music player after page reload...');
            initializeMeraPlayer();
        }
    }, 100);
}

// Initialize player when DOM is ready with multiple fallbacks
function initializeMeraPlayer() {
    console.log('🎵 Starting MERA music player initialization...');
    
    // Check if player already exists
    if (window.meraAmbientPlayer) {
        console.log('🎵 Player instance already exists, reconnecting...');
        // Ensure the existing player reconnects to the UI
        window.meraAmbientPlayer.createPlayerUI();
        window.meraAmbientPlayer.setupEventListeners();
        
        // Make sure music library is initialized
        if (window.meraAmbientPlayer.availableTracks.length === 0) {
            window.meraAmbientPlayer.initializeMusicLibrary();
        }
        
        // Sync player state with actual audio state
        if (window.meraGlobalAudio) {
            window.meraAmbientPlayer.isPlaying = !window.meraGlobalAudio.paused;
            if (window.meraAmbientPlayer.isPlaying) {
                window.meraAmbientPlayer.updatePlayButton();
                window.meraAmbientPlayer.updateStatus(`Playing: ${window.meraAmbientPlayer.getCurrentTrackName()}`);
            } else {
                window.meraAmbientPlayer.updatePlayButton();
                if (window.meraGlobalAudio.src) {
                    window.meraAmbientPlayer.updateStatus(`Ready: ${window.meraAmbientPlayer.getCurrentTrackName()}`);
                }
            }
        }
        return;
    }
    
    window.meraAmbientPlayer = new MeraAmbientPlayer();
    
    // Initialize music library with astrophysical tracks
    window.meraAmbientPlayer.initializeMusicLibrary();
    
    // Show introduction for new users
    window.meraAmbientPlayer.showIntroduction();
    
    console.log('🎵 MERA Ambient Player initialized with', window.meraAmbientPlayer.availableTracks.length, 'astrophysical ambient tracks');
    console.log('Available tracks:', window.meraAmbientPlayer.availableTracks.map(track => track.name).join(', '));
}

// Try multiple initialization methods for maximum compatibility
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeMeraPlayer);
} else if (document.readyState === 'interactive') {
    setTimeout(initializeMeraPlayer, 100);
} else {
    // DOM is already loaded
    initializeMeraPlayer();
}

// Fallback for Documenter's dynamic content loading
setTimeout(() => {
    if (!window.meraAmbientPlayer) {
        console.log('🎵 Fallback initialization triggered');
        initializeMeraPlayer();
    }
}, 1000);