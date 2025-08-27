// Enhanced Persistent Music Player for MERA.jl Documentation
// Now with seamless popup transfer functionality
// This creates a truly persistent top bar that survives page navigation

(function() {
    'use strict';
    
    // Track script execution count to detect reloads
    if (typeof window.meraScriptCounter === 'undefined') {
        window.meraScriptCounter = 0;
    }
    window.meraScriptCounter++;
    console.log(`🎵 ENHANCED SCRIPT EXECUTION #${window.meraScriptCounter} - URL: ${window.location.pathname}`);
    
    // Calculate correct music path for current page
    function getMusicPath(filename) {
        const currentUrl = window.location.href;
        const currentPath = window.location.pathname;
        
        // Handle local file:// protocol
        if (currentUrl.startsWith('file://')) {
            const pathSegments = currentPath.split('/');
            const buildIndex = pathSegments.indexOf('build');
            
            if (buildIndex !== -1 && pathSegments.length > buildIndex + 1) {
                const levelsDeep = pathSegments.length - buildIndex - 2;
                if (levelsDeep > 0) {
                    const backPath = '../'.repeat(levelsDeep);
                    return `${backPath}assets/music/${filename}`;
                } else {
                    return `assets/music/${filename}`;
                }
            } else {
                return `assets/music/${filename}`;
            }
        }
        
        // Handle web URLs (GitHub Pages, etc.)
        if (currentPath === '/' || currentPath.endsWith('/index.html') || currentPath === '/Mera.jl/' || currentPath === '/Mera.jl/dev/' || currentPath.endsWith('/dev/')) {
            return `assets/music/${filename}`;
        } else if (currentPath.includes('/Mera.jl/dev/')) {
            const pathAfterDev = currentPath.split('/dev/')[1];
            if (pathAfterDev) {
                const pathSegments = pathAfterDev.split('/').filter(segment => segment);
                const levelsDeep = pathSegments.length > 0 && !pathSegments[pathSegments.length - 1].includes('.') ? 
                                 pathSegments.length : pathSegments.length - 1;
                const backPath = '../'.repeat(Math.max(0, levelsDeep));
                return `${backPath}assets/music/${filename}`;
            } else {
                return `assets/music/${filename}`;
            }
        } else if (currentPath.includes('/Mera.jl/')) {
            const pathSegments = currentPath.split('/').filter(segment => segment && segment !== 'Mera.jl');
            const backPath = '../'.repeat(Math.max(0, pathSegments.length - 1));
            return `${backPath}assets/music/${filename}`;
        } else {
            return `/assets/music/${filename}`;
        }
    }
    
    // Enhanced audio system with popup support
    if (!window.meraEnhancedAudioSystem) {
        window.meraEnhancedAudioSystem = {
            audio: new Audio(),
            isPlaying: false,
            currentTrack: '',
            volume: 0.15,
            currentTime: 0,
            activePlayer: 'topbar', // 'topbar' or 'popup'
            popupWindow: null,
            tracks: [
                'alpha_centauri.mp3', 'andromeda_galaxy.mp3', 'betelgeuse_supergiant.mp3',
                'black_hole.mp3', 'cassiopeia_constellation.mp3', 'crab_nebula.mp3', 
                'eagle_nebula.mp3', 'europa_moon.mp3', 'horsehead_nebula.mp3', 
                'milky_way_galaxy.mp3', 'orion_nebula.mp3', 'proxima_centauri.mp3',
                'ring_nebula.mp3', 'sagittarius_a_star.mp3', 'titan_moon.mp3', 
                'vega.mp3', 'whirlpool_galaxy.mp3'
            ],
            musicLibrary: [
                { file: 'alpha_centauri.mp3', name: 'Alpha Centauri' },
                { file: 'andromeda_galaxy.mp3', name: 'Andromeda Galaxy' },
                { file: 'betelgeuse_supergiant.mp3', name: 'Betelgeuse Supergiant' },
                { file: 'black_hole.mp3', name: 'Black Hole' },
                { file: 'cassiopeia_constellation.mp3', name: 'Cassiopeia Constellation' },
                { file: 'crab_nebula.mp3', name: 'Crab Nebula' },
                { file: 'eagle_nebula.mp3', name: 'Eagle Nebula' },
                { file: 'europa_moon.mp3', name: 'Europa Moon' },
                { file: 'horsehead_nebula.mp3', name: 'Horsehead Nebula' },
                { file: 'milky_way_galaxy.mp3', name: 'Milky Way Galaxy' },
                { file: 'orion_nebula.mp3', name: 'Orion Nebula' },
                { file: 'proxima_centauri.mp3', name: 'Proxima Centauri' },
                { file: 'ring_nebula.mp3', name: 'Ring Nebula' },
                { file: 'sagittarius_a_star.mp3', name: 'Sagittarius A Star' },
                { file: 'titan_moon.mp3', name: 'Titan Moon' },
                { file: 'vega.mp3', name: 'Vega' },
                { file: 'whirlpool_galaxy.mp3', name: 'Whirlpool Galaxy' }
            ]
        };
        
        const sys = window.meraEnhancedAudioSystem;
        sys.audio.volume = sys.volume;
        sys.audio.loop = false;
        sys.audio.preload = 'auto';
        
        // Enhanced event handlers with popup support
        sys.audio.addEventListener('ended', () => {
            if (sys.isPlaying && sys.activePlayer === 'topbar') {
                console.log('🎵 Track ended, playing next...');
                const nextTrack = sys.tracks[Math.floor(Math.random() * sys.tracks.length)];
                sys.playTrack(nextTrack);
            }
        });
        
        sys.audio.addEventListener('play', () => {
            if (sys.activePlayer === 'topbar') {
                sys.isPlaying = true;
                localStorage.setItem('mera-was-playing', 'true');
                localStorage.setItem('mera-current-track', sys.currentTrack);
                localStorage.setItem('mera-audio-time', sys.audio.currentTime.toString());
                console.log('🎵 Audio started playing in top bar');
            }
        });
        
        sys.audio.addEventListener('pause', () => {
            if (sys.activePlayer === 'topbar') {
                sys.isPlaying = false;
                localStorage.setItem('mera-was-playing', 'false');
                console.log('🎵 Audio paused in top bar');
            }
        });
        
        sys.audio.addEventListener('timeupdate', () => {
            if (sys.isPlaying && sys.activePlayer === 'topbar') {
                sys.currentTime = sys.audio.currentTime;
                localStorage.setItem('mera-audio-time', sys.audio.currentTime.toString());
                localStorage.setItem('mera-current-track', sys.currentTrack);
            }
        });
        
        // Enhanced functions with popup support
        sys.playTrack = async (filename) => {
            const path = getMusicPath(filename);
            console.log(`🎵 Playing: ${path}`);
            sys.currentTrack = filename;
            sys.audio.src = path;
            try {
                await sys.audio.play();
                sys.isPlaying = true;
            } catch (e) {
                console.error('🎵 Play error:', e);
                sys.isPlaying = false;
            }
        };
        
        sys.pause = () => {
            sys.audio.pause();
            sys.isPlaying = false;
        };
        
        sys.playRandom = () => {
            const randomTrack = sys.tracks[Math.floor(Math.random() * sys.tracks.length)];
            return sys.playTrack(randomTrack);
        };
        
        // NEW: Popup transfer functions
        sys.transferToPopup = () => {
            sys.currentTime = sys.audio.currentTime;
            sys.activePlayer = 'popup';
            sys.audio.pause();
            console.log('🎵 Transferred playback to popup');
        };
        
        sys.transferFromPopup = (state) => {
            sys.activePlayer = 'topbar';
            sys.currentTrack = state.track;
            sys.volume = state.volume;
            sys.currentTime = state.currentTime;
            sys.isPlaying = state.isPlaying;
            
            if (state.track) {
                const path = getMusicPath(state.track);
                sys.audio.src = path;
                sys.audio.volume = sys.volume;
                sys.audio.currentTime = sys.currentTime;
                
                if (state.isPlaying) {
                    sys.audio.play().then(() => {
                        console.log('🎵 Successfully transferred from popup');
                    }).catch(e => {
                        console.error('🎵 Transfer from popup failed:', e);
                        sys.isPlaying = false;
                    });
                }
            }
            
            // Close popup
            if (sys.popupWindow && !sys.popupWindow.closed) {
                sys.popupWindow.close();
            }
            sys.popupWindow = null;
        };
        
        sys.getCurrentState = () => {
            return {
                track: sys.currentTrack,
                isPlaying: sys.isPlaying,
                currentTime: sys.audio.currentTime || sys.currentTime,
                volume: sys.volume,
                trackName: getTrackDisplayName(sys.currentTrack)
            };
        };
        
        // Save state before page unload
        window.addEventListener('beforeunload', () => {
            if (sys.isPlaying && sys.activePlayer === 'topbar') {
                localStorage.setItem('mera-was-playing', 'true');
                localStorage.setItem('mera-current-track', sys.currentTrack);
                localStorage.setItem('mera-audio-time', sys.audio.currentTime.toString());
                console.log('🎵 Enhanced state saved before page unload');
            }
        });
        
        console.log('🎵 Enhanced audio system created');
    }
    
    // Setup popup communication
    window.addEventListener('message', (event) => {
        const sys = window.meraEnhancedAudioSystem;
        
        if (event.data.type === 'popupReady') {
            // Send current state to popup
            const currentState = sys.getCurrentState();
            event.source.postMessage({
                type: 'initializePopup',
                state: currentState,
                musicLibrary: sys.musicLibrary
            }, '*');
            
            // Transfer control to popup
            sys.transferToPopup();
            updateUI();
            
        } else if (event.data.type === 'transferFromPopup') {
            // Receive state back from popup
            sys.transferFromPopup(event.data.state);
            updateUI();
            
        } else if (event.data.type === 'popupStateUpdate') {
            // Update our tracking of popup state
            sys.currentTime = event.data.currentTime;
            sys.isPlaying = event.data.isPlaying;
            updateUI();
        }
    });
    
    // Music library for display
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
    
    // Use enhanced global system
    if (typeof window.meraIsPlaying === 'undefined') {
        window.meraIsPlaying = false;
    }
    
    // Synchronize with enhanced system
    const sys = window.meraEnhancedAudioSystem;
    if (sys) {
        window.meraIsPlaying = sys.isPlaying;
        console.log(`🎵 Enhanced script loaded - Audio state: playing=${window.meraIsPlaying}, activePlayer=${sys.activePlayer}`);
    }
    
    // Get track display name
    function getTrackDisplayName(filename) {
        if (!filename) return 'Unknown Track';
        return filename.replace(/\.(wav|mp3)$/, '').replace(/_/g, ' ')
            .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
    }
    
    // Get current track name
    function getCurrentTrackName() {
        const sys = window.meraEnhancedAudioSystem;
        if (!sys.currentTrack) return 'Unknown Track';
        return getTrackDisplayName(sys.currentTrack);
    }
    
    // Enhanced UI update with popup support
    function updateUI() {
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        const status = document.getElementById('mera-top-status');
        const popupBtn = document.getElementById('mera-popup-btn');
        
        const sys = window.meraEnhancedAudioSystem;
        if (playBtn && pauseBtn && status && sys) {
            
            if (sys.activePlayer === 'popup') {
                // Show popup status
                playBtn.style.display = 'none';
                pauseBtn.style.display = 'none';
                status.textContent = '🪟 Playing in popup window';
                status.style.color = 'rgba(255, 255, 255, 0.9)';
                status.style.fontWeight = '600';
                
                if (popupBtn) {
                    popupBtn.textContent = '🪟 Active';
                    popupBtn.style.background = 'rgba(76, 175, 80, 0.3)';
                    popupBtn.style.borderColor = 'rgba(76, 175, 80, 0.5)';
                    popupBtn.disabled = true;
                }
                
            } else {
                // Regular top bar mode
                if (popupBtn) {
                    popupBtn.textContent = '🪟 Popup';
                    popupBtn.style.background = 'rgba(255,255,255,0.15)';
                    popupBtn.style.borderColor = 'rgba(255,255,255,0.25)';
                    popupBtn.disabled = false;
                }
                
                const shouldRestore = localStorage.getItem('mera-was-playing') === 'true' && 
                                     !sys.isPlaying && sys.audio.src;
                
                if (sys.isPlaying) {
                    playBtn.style.display = 'none';
                    pauseBtn.style.display = 'inline-block';
                    status.textContent = `Playing: ${getCurrentTrackName()}`;
                    status.style.color = 'rgba(255, 255, 255, 0.9)';
                    status.style.fontWeight = 'normal';
                } else if (shouldRestore) {
                    playBtn.style.display = 'inline-block';
                    pauseBtn.style.display = 'none';
                    playBtn.textContent = '▶️ Resume Music';
                    playBtn.style.backgroundColor = 'rgba(255,255,255,0.3)';
                    status.textContent = `Click to resume: ${getCurrentTrackName()}`;
                    status.style.color = 'rgba(255, 255, 255, 0.9)';
                    status.style.fontWeight = 'normal';
                } else {
                    playBtn.style.display = 'inline-block';
                    pauseBtn.style.display = 'none';
                    playBtn.textContent = '🔀 Play Random';
                    playBtn.style.backgroundColor = 'rgba(255,255,255,0.2)';
                    if (sys.audio.src) {
                        status.textContent = `Ready: ${getCurrentTrackName()}`;
                    } else {
                        status.textContent = 'Ready to play';
                    }
                    status.style.color = 'rgba(255, 255, 255, 0.9)';
                    status.style.fontWeight = 'normal';
                }
            }
        }
    }
    
    // Load and play track
    async function playRandomTrack() {
        const sys = window.meraEnhancedAudioSystem;
        if (sys.activePlayer === 'popup') return; // Let popup handle it
        
        const track = musicTracks[Math.floor(Math.random() * musicTracks.length)];
        const musicPath = getMusicPath(track.file);
        
        console.log(`🎵 Loading track from: ${musicPath}`);
        
        sys.audio.pause();
        sys.audio.currentTime = 0;
        sys.audio.src = musicPath;
        sys.currentTrack = track.file;
        
        return new Promise((resolve, reject) => {
            const onCanPlay = async () => {
                sys.audio.removeEventListener('canplaythrough', onCanPlay);
                sys.audio.removeEventListener('error', onError);
                
                try {
                    await sys.audio.play();
                    sys.isPlaying = true;
                    window.meraIsPlaying = true;
                    updateUI();
                    console.log(`🎵 Playing: ${track.name}`);
                    resolve();
                } catch (error) {
                    console.error('Error playing music:', error);
                    const status = document.getElementById('mera-top-status');
                    if (status) status.textContent = 'Error playing music';
                    sys.isPlaying = false;
                    window.meraIsPlaying = false;
                    updateUI();
                    reject(error);
                }
            };
            
            const onError = (error) => {
                sys.audio.removeEventListener('canplaythrough', onCanPlay);
                sys.audio.removeEventListener('error', onError);
                console.error('Audio loading error:', error);
                const status = document.getElementById('mera-top-status');
                if (status) status.textContent = 'Music file not found';
                sys.isPlaying = false;
                window.meraIsPlaying = false;
                updateUI();
                reject(error);
            };
            
            sys.audio.addEventListener('canplaythrough', onCanPlay, { once: true });
            sys.audio.addEventListener('error', onError, { once: true });
            sys.audio.load();
        });
    }
    
    // Pause music
    function pauseMusic() {
        const sys = window.meraEnhancedAudioSystem;
        if (sys.activePlayer === 'topbar') {
            sys.audio.pause();
            sys.isPlaying = false;
            window.meraIsPlaying = false;
            updateUI();
        }
    }
    
    // Set volume
    function setVolume(volume) {
        const sys = window.meraEnhancedAudioSystem;
        sys.volume = volume;
        sys.audio.volume = volume;
        
        const volumeDisplay = document.getElementById('mera-top-volume-display');
        if (volumeDisplay) {
            volumeDisplay.textContent = `${Math.round(volume * 100)}%`;
        }
    }
    
    // NEW: Open popup with seamless transfer
    function openMusicPopup() {
        const sys = window.meraEnhancedAudioSystem;
        
        // Create popup window
        const popup = window.open('', 'MeraMusicPlayer', 
            'width=400,height=600,scrollbars=no,resizable=yes,status=no,toolbar=no,menubar=no');
        
        if (!popup) {
            alert('Please allow popups for this site to use the music player');
            return;
        }
        
        sys.popupWindow = popup;
        
        // Create popup content
        const popupHTML = `
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>MERA.jl Ambient Music Player</title>
                <style>
                    body {
                        font-family: system-ui, -apple-system, sans-serif;
                        margin: 0;
                        padding: 20px;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        min-height: calc(100vh - 40px);
                    }
                    
                    .popup-header {
                        text-align: center;
                        margin-bottom: 30px;
                    }
                    
                    .popup-header h1 {
                        margin: 0 0 10px 0;
                        font-size: 24px;
                        font-weight: 300;
                    }
                    
                    .popup-header p {
                        margin: 0;
                        opacity: 0.9;
                        font-size: 14px;
                    }
                    
                    .popup-player {
                        background: rgba(255, 255, 255, 0.1);
                        border-radius: 12px;
                        padding: 25px;
                        backdrop-filter: blur(10px);
                        border: 1px solid rgba(255, 255, 255, 0.2);
                    }
                    
                    .popup-controls {
                        display: flex;
                        gap: 12px;
                        margin-bottom: 20px;
                    }
                    
                    .popup-btn {
                        flex: 1;
                        padding: 12px;
                        background: rgba(255, 255, 255, 0.2);
                        color: white;
                        border: 1px solid rgba(255, 255, 255, 0.3);
                        border-radius: 8px;
                        cursor: pointer;
                        font-size: 14px;
                        transition: all 0.2s;
                    }
                    
                    .popup-btn:hover {
                        background: rgba(255, 255, 255, 0.3);
                    }
                    
                    .popup-btn:disabled {
                        opacity: 0.5;
                        cursor: not-allowed;
                    }
                    
                    .popup-volume {
                        margin-bottom: 20px;
                    }
                    
                    .popup-volume label {
                        display: block;
                        margin-bottom: 8px;
                        font-size: 14px;
                        opacity: 0.9;
                    }
                    
                    .popup-volume input {
                        width: 100%;
                        margin-bottom: 5px;
                    }
                    
                    .popup-volume-display {
                        text-align: center;
                        font-size: 12px;
                        opacity: 0.8;
                    }
                    
                    .popup-status {
                        text-align: center;
                        padding: 15px;
                        background: rgba(255, 255, 255, 0.1);
                        border-radius: 8px;
                        font-size: 14px;
                        line-height: 1.4;
                    }
                    
                    .popup-track-list {
                        margin-top: 25px;
                        max-height: 200px;
                        overflow-y: auto;
                        background: rgba(255, 255, 255, 0.1);
                        border-radius: 8px;
                        padding: 15px;
                    }
                    
                    .popup-track-item {
                        padding: 8px 12px;
                        margin: 2px 0;
                        background: rgba(255, 255, 255, 0.1);
                        border-radius: 6px;
                        cursor: pointer;
                        font-size: 12px;
                        transition: background 0.2s;
                    }
                    
                    .popup-track-item:hover {
                        background: rgba(255, 255, 255, 0.2);
                    }
                    
                    .popup-track-item.active {
                        background: rgba(255, 255, 255, 0.3);
                        font-weight: bold;
                    }
                </style>
            </head>
            <body>
                <div class="popup-header">
                    <h1>🎵 MERA.jl</h1>
                    <p>Astrophysical Ambient Music for Data Analysis</p>
                </div>
                
                <div class="popup-player">
                    <div class="popup-controls">
                        <button class="popup-btn" onclick="popupPlayer.playRandomTrack()">🔀 Random</button>
                        <button id="popup-play-pause" class="popup-btn" onclick="popupPlayer.togglePlayPause()">▶️ Play</button>
                        <button class="popup-btn" onclick="popupPlayer.returnToMain()">↩️ Return</button>
                    </div>
                    
                    <div class="popup-volume">
                        <label for="popup-volume">🔊 Volume</label>
                        <input type="range" id="popup-volume" min="0" max="100" value="15" 
                               onchange="popupPlayer.updateVolume(this.value)">
                        <div class="popup-volume-display" id="popup-volume-display">15%</div>
                    </div>
                    
                    <div id="popup-status" class="popup-status">
                        Initializing...
                    </div>
                    
                    <div class="popup-track-list">
                        <div style="font-size: 12px; opacity: 0.8; margin-bottom: 10px; text-align: center;">
                            🌌 Ambient Track Library
                        </div>
                        <div id="track-list-container">
                            <!-- Tracks will be loaded here -->
                        </div>
                    </div>
                </div>
                
                <script>
                    class PopupMusicPlayer {
                        constructor() {
                            this.audio = new Audio();
                            this.isPlaying = false;
                            this.currentTrack = null;
                            this.volume = 0.15;
                            this.musicLibrary = [];
                            
                            this.audio.volume = this.volume;
                            this.audio.loop = true;
                            
                            // Setup audio event listeners
                            this.audio.addEventListener('play', () => {
                                this.isPlaying = true;
                                this.updateUI();
                                this.notifyParent();
                            });
                            
                            this.audio.addEventListener('pause', () => {
                                this.isPlaying = false;
                                this.updateUI();
                                this.notifyParent();
                            });
                            
                            this.audio.addEventListener('timeupdate', () => {
                                this.notifyParent();
                            });
                            
                            // Request initialization from parent
                            if (window.opener) {
                                window.opener.postMessage({ type: 'popupReady' }, '*');
                            }
                            
                            // Handle popup close
                            window.addEventListener('beforeunload', () => {
                                this.returnToMain();
                            });
                        }
                        
                        // GoatCounter tracking helper for popup events
                        trackPopupEvent(action, trackName = '') {
                            // Check GoatCounter in popup window or parent window
                            const gc = window.goatcounter || (window.opener && window.opener.goatcounter);
                            const hostname = window.location.hostname || (window.opener && window.opener.location.hostname);
                            
                            // Only track if GoatCounter is available and on production
                            if (gc && gc.count && hostname === 'manuelbehrendt.github.io') {
                                const path = `music-popup-${action}`;
                                const title = trackName ? `Music Popup: ${action} - ${trackName}` : `Music Popup: ${action}`;
                                
                                gc.count({
                                    path: path,
                                    title: title,
                                    event: true
                                });
                                
                                console.log(`📊 Tracked popup event: ${action}${trackName ? ` - ${trackName}` : ''}`);
                            }
                        }
                        
                        initialize(state, musicLibrary) {
                            console.log('🎵 Initializing popup with state:', state);
                            this.musicLibrary = musicLibrary;
                            this.volume = state.volume || 0.15;
                            
                            // Track popup opening
                            this.trackPopupEvent('opened');
                            
                            // Update volume UI
                            document.getElementById('popup-volume').value = Math.round(this.volume * 100);
                            document.getElementById('popup-volume-display').textContent = Math.round(this.volume * 100) + '%';
                            
                            // Create track list
                            this.createTrackList();
                            
                            // Load current track if exists
                            if (state.track) {
                                this.loadTrack(state.track, state.currentTime || 0);
                                this.currentTrack = state.track;
                                
                                if (state.isPlaying) {
                                    this.audio.play().then(() => {
                                        console.log('🎵 Popup playback started');
                                    }).catch(e => {
                                        console.error('🎵 Popup playback failed:', e);
                                    });
                                } else {
                                    this.updateStatus(\`⏸️ Paused: \${state.trackName}\`);
                                }
                            } else {
                                this.updateStatus('Click Random to start music');
                            }
                            
                            this.updateUI();
                        }
                        
                        loadTrack(filename, startTime = 0) {
                            const musicPath = this.calculateMusicPath(filename);
                            console.log(\`🎵 Loading in popup: \${musicPath} (start time: \${startTime})\`);
                            
                            this.audio.src = musicPath;
                            this.audio.currentTime = startTime;
                            this.currentTrack = filename;
                            
                            // Add load event listener to debug loading issues
                            this.audio.addEventListener('loadstart', () => {
                                console.log(\`🎵 Started loading: \${musicPath}\`);
                            });
                            
                            this.audio.addEventListener('canplay', () => {
                                console.log(\`🎵 Can play: \${musicPath}\`);
                            });
                            
                            this.audio.addEventListener('error', (e) => {
                                console.error(\`🎵 Audio loading error for \${musicPath}:\`, e);
                            });
                        }
                        
                        calculateMusicPath(filename) {
                            // Use same logic as parent window
                            if (window.opener && window.opener.meraGetMusicPath) {
                                return window.opener.meraGetMusicPath(filename);
                            }
                            
                            // Fallback path calculation for popup
                            const parentUrl = window.opener ? window.opener.location.href : '';
                            const parentPath = window.opener ? window.opener.location.pathname : '';
                            
                            // Handle local file:// protocol
                            if (parentUrl.startsWith('file://')) {
                                const pathSegments = parentPath.split('/');
                                const buildIndex = pathSegments.indexOf('build');
                                
                                if (buildIndex !== -1 && pathSegments.length > buildIndex + 1) {
                                    const levelsDeep = pathSegments.length - buildIndex - 2;
                                    if (levelsDeep > 0) {
                                        const backPath = '../'.repeat(levelsDeep);
                                        return \`\${backPath}assets/music/\${filename}\`;
                                    } else {
                                        return \`assets/music/\${filename}\`;
                                    }
                                } else {
                                    return \`assets/music/\${filename}\`;
                                }
                            }
                            
                            // Handle web URLs (GitHub Pages, etc.)
                            if (parentPath === '/' || parentPath.endsWith('/index.html') || parentPath === '/Mera.jl/' || parentPath === '/Mera.jl/dev/' || parentPath.endsWith('/dev/')) {
                                return \`assets/music/\${filename}\`;
                            } else if (parentPath.includes('/Mera.jl/dev/')) {
                                const pathAfterDev = parentPath.split('/dev/')[1];
                                if (pathAfterDev) {
                                    const pathSegments = pathAfterDev.split('/').filter(segment => segment);
                                    const levelsDeep = pathSegments.length > 0 && !pathSegments[pathSegments.length - 1].includes('.') ? 
                                                     pathSegments.length : pathSegments.length - 1;
                                    const backPath = '../'.repeat(Math.max(0, levelsDeep));
                                    return \`\${backPath}assets/music/\${filename}\`;
                                } else {
                                    return \`assets/music/\${filename}\`;
                                }
                            } else if (parentPath.includes('/Mera.jl/')) {
                                const pathSegments = parentPath.split('/').filter(segment => segment && segment !== 'Mera.jl');
                                const backPath = '../'.repeat(Math.max(0, pathSegments.length - 1));
                                return \`\${backPath}assets/music/\${filename}\`;
                            } else {
                                return \`/assets/music/\${filename}\`;
                            }
                        }
                        
                        createTrackList() {
                            const container = document.getElementById('track-list-container');
                            container.innerHTML = this.musicLibrary.map((track, index) => 
                                \`<div class="popup-track-item" onclick="popupPlayer.playTrack(\${index})">
                                    \${track.name}
                                </div>\`
                            ).join('');
                        }
                        
                        playTrack(index) {
                            console.log(\`🎵 Popup playTrack called with index: \${index}\`);
                            const track = this.musicLibrary[index];
                            if (track) {
                                console.log(\`🎵 Playing track: \${track.name} (\${track.file})\`);
                                this.loadTrack(track.file);
                                
                                // Add error handling and better promise handling
                                this.audio.play().then(() => {
                                    console.log(\`🎵 Successfully started playing: \${track.name}\`);
                                    this.updateStatus(\`🎵 Playing: \${track.name}\`);
                                    this.updateTrackHighlight(track.name);
                                    
                                    // Track specific track play
                                    this.trackPopupEvent('track-played', track.name);
                                }).catch(error => {
                                    console.error(\`🎵 Failed to play track: \${track.name}\`, error);
                                    this.updateStatus(\`❌ Failed to play: \${track.name}\`);
                                    
                                    // Try alternative path
                                    const altPath = \`assets/music/\${track.file}\`;
                                    console.log(\`🎵 Trying alternative path: \${altPath}\`);
                                    this.audio.src = altPath;
                                    this.audio.play().then(() => {
                                        console.log(\`🎵 Alternative path worked: \${altPath}\`);
                                        this.updateStatus(\`🎵 Playing: \${track.name}\`);
                                        this.updateTrackHighlight(track.name);
                                    }).catch(altError => {
                                        console.error(\`🎵 Alternative path also failed: \${altPath}\`, altError);
                                        this.updateStatus(\`❌ Music file not accessible: \${track.name}\`);
                                    });
                                });
                            } else {
                                console.error(\`🎵 No track found at index: \${index}\`);
                                this.updateStatus('❌ Track not found');
                            }
                        }
                        
                        playRandomTrack() {
                            console.log(\`🎵 Popup playRandomTrack called, library size: \${this.musicLibrary.length}\`);
                            if (this.musicLibrary.length > 0) {
                                const randomIndex = Math.floor(Math.random() * this.musicLibrary.length);
                                console.log(\`🎵 Selected random index: \${randomIndex}\`);
                                this.updateStatus('🔀 Selecting random track...');
                                
                                // Track random play action
                                this.trackPopupEvent('random-played');
                                
                                this.playTrack(randomIndex);
                            } else {
                                console.error('🎵 Music library is empty!');
                                this.updateStatus('❌ No tracks available');
                            }
                        }
                        
                        togglePlayPause() {
                            if (!this.currentTrack) {
                                this.playRandomTrack();
                                return;
                            }
                            
                            if (this.isPlaying) {
                                this.audio.pause();
                                this.trackPopupEvent('paused');
                            } else {
                                this.audio.play();
                                this.trackPopupEvent('resumed');
                            }
                        }
                        
                        updateVolume(value) {
                            this.volume = value / 100;
                            this.audio.volume = this.volume;
                            document.getElementById('popup-volume-display').textContent = value + '%';
                        }
                        
                        updateStatus(message) {
                            document.getElementById('popup-status').innerHTML = message;
                        }
                        
                        updateUI() {
                            const playPauseBtn = document.getElementById('popup-play-pause');
                            if (playPauseBtn) {
                                playPauseBtn.textContent = this.isPlaying ? '⏸️ Pause' : '▶️ Play';
                            }
                            
                            if (this.currentTrack && this.isPlaying) {
                                const trackName = this.getTrackDisplayName(this.currentTrack);
                                this.updateStatus(\`🎵 Playing: \${trackName}\`);
                                this.updateTrackHighlight(trackName);
                            }
                        }
                        
                        updateTrackHighlight(trackName) {
                            document.querySelectorAll('.popup-track-item').forEach(item => {
                                item.classList.toggle('active', item.textContent.trim() === trackName);
                            });
                        }
                        
                        getTrackDisplayName(filename) {
                            if (!filename) return 'Unknown Track';
                            return filename.replace(/\\.(wav|mp3)$/, '').replace(/_/g, ' ')
                                .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
                        }
                        
                        returnToMain() {
                            // Track popup closing
                            this.trackPopupEvent('closed');
                            
                            const transferState = {
                                track: this.currentTrack,
                                isPlaying: this.isPlaying,
                                currentTime: this.audio.currentTime || 0,
                                volume: this.volume
                            };
                            
                            // Pause audio
                            this.audio.pause();
                            
                            // Send state to parent
                            if (window.opener) {
                                window.opener.postMessage({
                                    type: 'transferFromPopup',
                                    state: transferState
                                }, '*');
                            }
                            
                            window.close();
                        }
                        
                        notifyParent() {
                            if (window.opener) {
                                window.opener.postMessage({
                                    type: 'popupStateUpdate',
                                    currentTime: this.audio.currentTime,
                                    isPlaying: this.isPlaying
                                }, '*');
                            }
                        }
                    }
                    
                    // Initialize popup player
                    const popupPlayer = new PopupMusicPlayer();
                    
                    // Listen for initialization message
                    window.addEventListener('message', (event) => {
                        if (event.data.type === 'initializePopup') {
                            popupPlayer.initialize(event.data.state, event.data.musicLibrary);
                        }
                    });
                </script>
            </body>
            </html>
        `;
        
        popup.document.write(popupHTML);
        popup.document.close();
        
        // Handle popup close
        popup.addEventListener('beforeunload', () => {
            if (sys.activePlayer === 'popup') {
                sys.activePlayer = 'topbar';
                sys.popupWindow = null;
                updateUI();
            }
        });
        
        console.log('🎵 Music popup opened');
    }
    
    // Create the enhanced persistent top bar
    function createTopBar() {
        if (document.getElementById('mera-top-bar')) {
            return;
        }
        
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
                <button id="mera-popup-btn" style="
                    padding: 4px 8px;
                    background: rgba(255,255,255,0.15);
                    border: 1px solid rgba(255,255,255,0.25);
                    border-radius: 4px;
                    color: rgba(255,255,255,0.9);
                    cursor: pointer;
                    font-size: 11px;
                    border: none;
                    outline: none;
                " title="Open music player in popup window for seamless listening">🪟 Popup</button>
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
        
        document.body.insertBefore(topBar, document.body.firstChild);
        document.body.style.paddingTop = '45px';
        
        setupEventListeners();
        updateUI();
        
        console.log('🎵 Enhanced persistent music player top bar created');
    }
    
    // Enhanced event listeners with popup support
    function setupEventListeners() {
        const playBtn = document.getElementById('mera-top-play-btn');
        const pauseBtn = document.getElementById('mera-top-pause-btn');
        const volumeSlider = document.getElementById('mera-top-volume');
        const popupBtn = document.getElementById('mera-popup-btn');
        
        if (playBtn) {
            playBtn.addEventListener('click', async () => {
                const sys = window.meraEnhancedAudioSystem;
                if (sys.activePlayer === 'popup') return;
                
                try {
                    const shouldRestore = localStorage.getItem('mera-was-playing') === 'true' && 
                                         !sys.isPlaying && sys.audio.src;
                    
                    if (shouldRestore) {
                        console.log('🎵 Resuming music from user interaction...');
                        const savedTime = parseFloat(localStorage.getItem('mera-audio-time') || '0');
                        sys.audio.currentTime = Math.max(0, savedTime - 1);
                        await sys.audio.play();
                        sys.isPlaying = true;
                        window.meraIsPlaying = true;
                    } else {
                        await playRandomTrack();
                    }
                    updateUI();
                } catch (error) {
                    console.error('🎵 Failed to start/resume music:', error);
                }
            });
        }
        
        if (pauseBtn) {
            pauseBtn.addEventListener('click', () => {
                pauseMusic();
            });
        }
        
        if (volumeSlider) {
            volumeSlider.addEventListener('input', function(e) {
                setVolume(e.target.value / 100);
            });
        }
        
        // NEW: Enhanced popup button with transfer functionality
        if (popupBtn) {
            popupBtn.addEventListener('click', () => {
                const sys = window.meraEnhancedAudioSystem;
                if (sys.activePlayer === 'popup') return;
                
                openMusicPopup();
            });
            
            popupBtn.addEventListener('mouseenter', () => {
                const sys = window.meraEnhancedAudioSystem;
                if (sys.activePlayer !== 'popup') {
                    popupBtn.style.background = 'rgba(255,255,255,0.25)';
                }
            });
            
            popupBtn.addEventListener('mouseleave', () => {
                const sys = window.meraEnhancedAudioSystem;
                if (sys.activePlayer !== 'popup') {
                    popupBtn.style.background = 'rgba(255,255,255,0.15)';
                }
            });
        }
    }
    
    // Enhanced initialization with popup support
    async function initialize() {
        createTopBar();
        
        // Try to restore previous audio state
        const sys = window.meraEnhancedAudioSystem;
        const savedState = localStorage.getItem('mera-was-playing');
        const savedTrack = localStorage.getItem('mera-current-track');
        const savedTime = parseFloat(localStorage.getItem('mera-audio-time') || '0');
        
        if (savedState === 'true' && savedTrack) {
            console.log(`🎵 Enhanced player - attempting to restore: ${savedTrack} at ${savedTime}s`);
            const path = getMusicPath(savedTrack);
            sys.audio.src = path;
            sys.currentTrack = savedTrack;
            sys.audio.currentTime = Math.max(0, savedTime - 1);
            
            // Don't auto-play, just prepare for resume
            sys.isPlaying = false;
        }
        
        updateUI();
        
        // Monitor for navigation and recreate if needed
        let currentUrl = window.location.href;
        
        const checkForNavigation = async () => {
            const newUrl = window.location.href;
            if (newUrl !== currentUrl) {
                currentUrl = newUrl;
                console.log(`🎵 Enhanced player navigation: ${newUrl}`);
                
                setTimeout(() => {
                    if (!document.getElementById('mera-top-bar')) {
                        console.log('🎵 Recreating enhanced player UI...');
                        createTopBar();
                    }
                    updateUI();
                }, 50);
            }
        };
        
        setInterval(checkForNavigation, 500);
        window.addEventListener('popstate', checkForNavigation);
        window.addEventListener('hashchange', checkForNavigation);
        
        // DOM observer for recreation
        if ('MutationObserver' in window) {
            const observer = new MutationObserver(() => {
                if (!document.getElementById('mera-top-bar')) {
                    setTimeout(() => {
                        if (!document.getElementById('mera-top-bar')) {
                            createTopBar();
                        }
                    }, 50);
                }
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        }
        
        // Periodic state saving
        setInterval(() => {
            if (sys.isPlaying && sys.activePlayer === 'topbar' && !sys.audio.paused) {
                localStorage.setItem('mera-was-playing', 'true');
                localStorage.setItem('mera-current-track', sys.currentTrack);
                localStorage.setItem('mera-audio-time', sys.audio.currentTime.toString());
            }
        }, 2000);
    }
    
    // Make path calculation globally available
    window.meraGetMusicPath = getMusicPath;
    
    // Initialize
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
    
})();