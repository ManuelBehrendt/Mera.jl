// Persistent Music Player for MERA.jl Documentation
// This creates a truly persistent top bar that survives page navigation

(function() {
    'use strict';
    
    // Global audio element that persists across all pages
    if (!window.meraGlobalAudio) {
        window.meraGlobalAudio = new Audio();
        window.meraGlobalAudio.volume = 0.15;
        
        // Save state continuously
        window.meraGlobalAudio.addEventListener('timeupdate', saveAudioState);
        window.meraGlobalAudio.addEventListener('play', saveAudioState);
        window.meraGlobalAudio.addEventListener('pause', saveAudioState);
        
        // Save state before page unload
        window.addEventListener('beforeunload', saveAudioState);
    }
    
    // Music library
    const musicTracks = [
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
    
    let isPlaying = false;
    
    // Save audio state to localStorage
    function saveAudioState() {
        if (window.meraGlobalAudio && window.meraGlobalAudio.src) {
            const state = {
                src: window.meraGlobalAudio.src,
                currentTime: window.meraGlobalAudio.currentTime,
                volume: window.meraGlobalAudio.volume,
                paused: window.meraGlobalAudio.paused,
                timestamp: Date.now()
            };
            localStorage.setItem('mera-audio-state', JSON.stringify(state));
        }
    }
    
    // Restore audio state from localStorage
    function restoreAudioState() {
        try {
            const savedState = localStorage.getItem('mera-audio-state');
            if (savedState) {
                const state = JSON.parse(savedState);
                
                // Only restore if state is recent (within 10 seconds)
                if (Date.now() - state.timestamp < 10000) {
                    window.meraGlobalAudio.src = state.src;
                    window.meraGlobalAudio.volume = state.volume;
                    
                    // Set the time and play state
                    window.meraGlobalAudio.currentTime = state.currentTime;
                    
                    if (!state.paused) {
                        isPlaying = true;
                        window.meraGlobalAudio.play().then(() => {
                            console.log('🎵 Audio restored and playing');
                            updateUI();
                        }).catch(e => {
                            console.log('Auto-resume prevented by browser policy:', e);
                            isPlaying = false;
                            updateUI();
                        });
                    } else {
                        isPlaying = false;
                        updateUI();
                    }
                    
                    console.log('🎵 Audio state restored:', state);
                    return true;
                }
            }
        } catch (e) {
            console.error('Error restoring audio state:', e);
        }
        return false;
    }
    
    // Get random track
    function getRandomTrack() {
        const randomIndex = Math.floor(Math.random() * musicTracks.length);
        return musicTracks[randomIndex];
    }
    
    // Get track display name
    function getTrackDisplayName(filename) {
        if (!filename) return 'Unknown Track';
        return filename.replace(/\.(wav|mp3)$/, '').replace(/_/g, ' ')
            .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
    }
    
    // Get current track name
    function getCurrentTrackName() {
        if (!window.meraGlobalAudio.src) return 'Unknown Track';
        const filename = window.meraGlobalAudio.src.split('/').pop();
        return getTrackDisplayName(filename);
    }
    
    // Update UI
    function updateUI() {
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        const status = document.getElementById('mera-top-status');
        
        if (playBtn && pauseBtn && status) {
            if (isPlaying) {
                playBtn.style.display = 'none';
                pauseBtn.style.display = 'inline-block';
                status.textContent = `Playing: ${getCurrentTrackName()}`;
            } else {
                playBtn.style.display = 'inline-block';
                pauseBtn.style.display = 'none';
                if (window.meraGlobalAudio.src) {
                    status.textContent = `Ready: ${getCurrentTrackName()}`;
                } else {
                    status.textContent = 'Ready to play';
                }
            }
        }
    }
    
    // Load and play track
    async function playRandomTrack() {
        const track = getRandomTrack();
        const musicPath = `assets/music/${track.file}`;
        
        window.meraGlobalAudio.src = musicPath;
        
        try {
            await window.meraGlobalAudio.play();
            isPlaying = true;
            updateUI();
            console.log(`🎵 Playing: ${track.name}`);
        } catch (error) {
            console.error('Error playing music:', error);
            const status = document.getElementById('mera-top-status');
            if (status) status.textContent = 'Error playing music';
        }
    }
    
    // Pause music
    function pauseMusic() {
        window.meraGlobalAudio.pause();
        isPlaying = false;
        updateUI();
    }
    
    // Set volume
    function setVolume(volume) {
        window.meraGlobalAudio.volume = volume;
        const volumeDisplay = document.getElementById('mera-top-volume-display');
        if (volumeDisplay) {
            volumeDisplay.textContent = `${Math.round(volume * 100)}%`;
        }
    }
    
    // Create the persistent top bar
    function createTopBar() {
        // Don't create if already exists
        if (document.getElementById('mera-top-bar')) {
            return;
        }
        
        // Create top bar element
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
                    border: none;
                    outline: none;
                ">🔀 Play Random</button>
                <button id="mera-top-pause-btn" style="
                    padding: 4px 12px;
                    background: rgba(255,255,255,0.2);
                    border: 1px solid rgba(255,255,255,0.3);
                    border-radius: 4px;
                    color: white;
                    cursor: pointer;
                    font-size: 12px;
                    border: none;
                    outline: none;
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
                    -webkit-appearance: none;
                ">
                <span id="mera-top-volume-display" style="color: rgba(255,255,255,0.9); font-size: 12px;">15%</span>
            </div>
        `;
        
        // Insert at the very beginning of the page
        document.body.insertBefore(topBar, document.body.firstChild);
        
        // Adjust page content to account for top bar
        document.body.style.paddingTop = '45px';
        
        // Set up event listeners
        setupEventListeners();
        
        // Update UI
        updateUI();
        
        console.log('🎵 Persistent music player top bar created');
    }
    
    // Set up event listeners
    function setupEventListeners() {
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        const volumeSlider = document.getElementById('mera-top-volume');
        
        if (playBtn) {
            playBtn.addEventListener('click', playRandomTrack);
        }
        
        if (pauseBtn) {
            pauseBtn.addEventListener('click', pauseMusic);
        }
        
        if (volumeSlider) {
            volumeSlider.addEventListener('input', function(e) {
                setVolume(e.target.value / 100);
            });
        }
        
        // Handle audio events
        window.meraGlobalAudio.addEventListener('ended', () => {
            if (isPlaying) {
                playRandomTrack(); // Play next random track
            }
        });
        
        window.meraGlobalAudio.addEventListener('pause', () => {
            isPlaying = false;
            updateUI();
        });
        
        window.meraGlobalAudio.addEventListener('play', () => {
            isPlaying = true;
            updateUI();
        });
    }
    
    // Initialize immediately when script loads
    function initialize() {
        createTopBar();
        
        // Try to restore previous audio state immediately
        const restored = restoreAudioState();
        if (!restored) {
            updateUI();
        }
        
        // Monitor for page changes and recreate if needed
        let currentUrl = window.location.href;
        setInterval(() => {
            if (window.location.href !== currentUrl) {
                currentUrl = window.location.href;
                console.log('🎵 Page change detected, ensuring music player persistence...');
                
                setTimeout(() => {
                    if (!document.getElementById('mera-top-bar')) {
                        console.log('🎵 Recreating music player after page change...');
                        createTopBar();
                    }
                    
                    // Always try to restore audio state after page change
                    const restored = restoreAudioState();
                    if (!restored) {
                        updateUI();
                    }
                }, 100);
            }
        }, 500);
        
        // Also save state every 2 seconds during playback
        setInterval(() => {
            if (!window.meraGlobalAudio.paused) {
                saveAudioState();
            }
        }, 2000);
    }
    
    // Run initialization as soon as possible
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
    
})();