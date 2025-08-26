// Persistent Music Player for MERA.jl Documentation
// This creates a truly persistent top bar that survives page navigation

(function() {
    'use strict';
    
    // Track script execution count to detect reloads
    if (typeof window.meraScriptCounter === 'undefined') {
        window.meraScriptCounter = 0;
    }
    window.meraScriptCounter++;
    console.log(`🎵 SCRIPT EXECUTION #${window.meraScriptCounter} - URL: ${window.location.pathname}`);
    
    // Global audio element that persists across all pages
    if (!window.meraGlobalAudio) {
        window.meraGlobalAudio = new Audio();
        window.meraGlobalAudio.volume = 0.15;
        
        // Save state continuously
        window.meraGlobalAudio.addEventListener('timeupdate', saveAudioState);
        window.meraGlobalAudio.addEventListener('play', saveAudioState);
        window.meraGlobalAudio.addEventListener('pause', saveAudioState);
        
        // Critical playback event listeners that must persist across pages
        const endedHandler = async () => {
            console.log(`🎵 ENDED EVENT FIRED - isPlaying: ${window.meraIsPlaying}, currentTime: ${window.meraGlobalAudio.currentTime}`);
            if (window.meraIsPlaying) {
                try {
                    console.log('🎵 Attempting to play next random track...');
                    await playRandomTrack(); // Play next random track
                    console.log('🎵 Successfully moved to next track');
                } catch (error) {
                    console.error('🎵 Failed to play next track:', error);
                    window.meraIsPlaying = false;
                    updateUI();
                }
            } else {
                console.log('🎵 Not playing next track because isPlaying is false');
            }
        };
        
        // Remove any existing ended listener first to prevent duplicates
        if (window.meraGlobalAudio._endedHandler) {
            window.meraGlobalAudio.removeEventListener('ended', window.meraGlobalAudio._endedHandler);
        }
        window.meraGlobalAudio.addEventListener('ended', endedHandler);
        window.meraGlobalAudio._endedHandler = endedHandler;
        
        window.meraGlobalAudio.addEventListener('pause', () => {
            window.meraIsPlaying = false;
            updateUI();
        });
        
        window.meraGlobalAudio.addEventListener('play', () => {
            window.meraIsPlaying = true;
            updateUI();
        });
        
        // Save state before page unload
        window.addEventListener('beforeunload', saveAudioState);
        
        // Mark that critical listeners are attached
        window.meraGlobalAudio._criticalListenersAttached = true;
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
    
    // Use global playing state that persists across page loads
    if (typeof window.meraIsPlaying === 'undefined') {
        window.meraIsPlaying = false;
    }
    
    // Synchronize playing state with actual audio state on script load
    if (window.meraGlobalAudio) {
        window.meraIsPlaying = !window.meraGlobalAudio.paused && window.meraGlobalAudio.src;
        console.log(`🎵 Script loaded - Audio state: playing=${window.meraIsPlaying}, paused=${window.meraGlobalAudio.paused}, src=${window.meraGlobalAudio.src ? 'yes' : 'no'}, currentTime=${window.meraGlobalAudio.currentTime}`);
    }
    
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
            console.log('🎵 State saved:', state);
        }
    }
    
    // Calculate correct music path for current page
    function getMusicPath(filename) {
        const currentUrl = window.location.href;
        const currentPath = window.location.pathname;
        
        // Handle local file:// protocol
        if (currentUrl.startsWith('file://')) {
            // For local development, files are in docs/build/
            // Current path: /Users/.../docs/build/some_file.html
            // Assets path: /Users/.../docs/build/assets/music/
            const pathSegments = currentPath.split('/');
            const buildIndex = pathSegments.indexOf('build');
            
            if (buildIndex !== -1 && pathSegments.length > buildIndex + 1) {
                // Count subdirectories after build/ (excluding the filename)
                const levelsDeep = pathSegments.length - buildIndex - 2; // -2 for build and filename
                if (levelsDeep > 0) {
                    // We're in a subdirectory, need to go back
                    const backPath = '../'.repeat(levelsDeep);
                    const result = `${backPath}assets/music/${filename}`;
                    console.log(`🎵 Local file path calculation: levels=${levelsDeep}, path=${result}`);
                    return result;
                } else {
                    // We're directly in build/ directory
                    const result = `assets/music/${filename}`;
                    console.log(`🎵 Local file path calculation: direct in build, path=${result}`);
                    return result;
                }
            } else {
                // Fallback
                console.log(`🎵 Local file path fallback used`);
                return `assets/music/${filename}`;
            }
        }
        
        // Handle web URLs (GitHub Pages, etc.)
        if (currentPath === '/' || currentPath.endsWith('/index.html') || currentPath === '/Mera.jl/' || currentPath === '/Mera.jl/dev/' || currentPath.endsWith('/dev/')) {
            // Root level (GitHub Pages dev branch or local)
            return `assets/music/${filename}`;
        } else if (currentPath.includes('/Mera.jl/dev/')) {
            // GitHub Pages dev branch - calculate relative path back to dev root
            const pathAfterDev = currentPath.split('/dev/')[1];
            if (pathAfterDev) {
                const pathSegments = pathAfterDev.split('/').filter(segment => segment);
                // Don't count the filename, only directories
                const levelsDeep = pathSegments.length > 0 && !pathSegments[pathSegments.length - 1].includes('.') ? 
                                 pathSegments.length : pathSegments.length - 1;
                const backPath = '../'.repeat(Math.max(0, levelsDeep));
                const result = `${backPath}assets/music/${filename}`;
                console.log(`🎵 GitHub Pages path calculation: afterDev=${pathAfterDev}, levels=${levelsDeep}, path=${result}`);
                return result;
            } else {
                return `assets/music/${filename}`;
            }
        } else if (currentPath.includes('/Mera.jl/')) {
            // Other GitHub Pages paths
            const pathSegments = currentPath.split('/').filter(segment => segment && segment !== 'Mera.jl');
            const backPath = '../'.repeat(Math.max(0, pathSegments.length - 1));
            return `${backPath}assets/music/${filename}`;
        } else {
            // Default fallback
            console.log(`🎵 Fallback path used for: ${currentPath}`);
            return `/assets/music/${filename}`;
        }
    }
    
    // Restore audio state from localStorage
    async function restoreAudioState() {
        try {
            const savedState = localStorage.getItem('mera-audio-state');
            if (savedState) {
                const state = JSON.parse(savedState);
                
                // Only restore if state is recent (within 10 seconds)
                if (Date.now() - state.timestamp < 10000) {
                    // Extract filename from saved src and recalculate path
                    const filename = state.src.split('/').pop();
                    const correctPath = getMusicPath(filename);
                    
                    console.log(`🎵 Restoring audio from: ${correctPath}`);
                    
                    // Reset audio element
                    window.meraGlobalAudio.pause();
                    window.meraGlobalAudio.currentTime = 0;
                    window.meraGlobalAudio.src = correctPath;
                    window.meraGlobalAudio.volume = state.volume;
                    
                    // Wait for audio to load before setting time and playing
                    return new Promise((resolve) => {
                        const onCanPlay = async () => {
                            window.meraGlobalAudio.removeEventListener('canplaythrough', onCanPlay);
                            window.meraGlobalAudio.removeEventListener('error', onError);
                            
                            // Set the saved time position
                            window.meraGlobalAudio.currentTime = state.currentTime;
                            
                            if (!state.paused) {
                                try {
                                    await window.meraGlobalAudio.play();
                                    window.meraIsPlaying = true;
                                    console.log('🎵 Audio restored and playing');
                                } catch (e) {
                                    console.log('Auto-resume prevented by browser policy:', e);
                                    window.meraIsPlaying = false;
                                }
                            } else {
                                window.meraIsPlaying = false;
                            }
                            
                            // Ensure global playing state matches audio state
                            window.meraIsPlaying = !window.meraGlobalAudio.paused;
                            
                            updateUI();
                            console.log('🎵 Audio state restored:', state);
                            resolve(true);
                        };
                        
                        const onError = (error) => {
                            window.meraGlobalAudio.removeEventListener('canplaythrough', onCanPlay);
                            window.meraGlobalAudio.removeEventListener('error', onError);
                            console.error('Audio restoration error:', error);
                            window.meraIsPlaying = false;
                            updateUI();
                            resolve(false);
                        };
                        
                        window.meraGlobalAudio.addEventListener('canplaythrough', onCanPlay, { once: true });
                        window.meraGlobalAudio.addEventListener('error', onError, { once: true });
                        
                        // Force load
                        window.meraGlobalAudio.load();
                    });
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
            if (window.meraIsPlaying) {
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
        const musicPath = getMusicPath(track.file);
        
        console.log(`🎵 Loading track from: ${musicPath}`);
        
        // Reset audio element first
        window.meraGlobalAudio.pause();
        window.meraGlobalAudio.currentTime = 0;
        
        // Set new source and wait for it to load
        window.meraGlobalAudio.src = musicPath;
        
        // Wait for the audio to be ready to play
        return new Promise((resolve, reject) => {
            const onCanPlay = async () => {
                window.meraGlobalAudio.removeEventListener('canplaythrough', onCanPlay);
                window.meraGlobalAudio.removeEventListener('error', onError);
                
                try {
                    await window.meraGlobalAudio.play();
                    window.meraIsPlaying = true;
                    updateUI();
                    console.log(`🎵 Playing: ${track.name}`);
                    resolve();
                } catch (error) {
                    console.error('Error playing music:', error);
                    const status = document.getElementById('mera-top-status');
                    if (status) status.textContent = 'Error playing music';
                    window.meraIsPlaying = false;
                    updateUI();
                    reject(error);
                }
            };
            
            const onError = (error) => {
                window.meraGlobalAudio.removeEventListener('canplaythrough', onCanPlay);
                window.meraGlobalAudio.removeEventListener('error', onError);
                console.error('Audio loading error:', error);
                const status = document.getElementById('mera-top-status');
                if (status) status.textContent = 'Music file not found';
                window.meraIsPlaying = false;
                updateUI();
                reject(error);
            };
            
            window.meraGlobalAudio.addEventListener('canplaythrough', onCanPlay, { once: true });
            window.meraGlobalAudio.addEventListener('error', onError, { once: true });
            
            // Force load
            window.meraGlobalAudio.load();
        });
    }
    
    // Pause music
    function pauseMusic() {
        window.meraGlobalAudio.pause();
        window.meraIsPlaying = false;
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
            playBtn.addEventListener('click', async () => {
                try {
                    await playRandomTrack();
                    console.log('🎵 Successfully started music');
                } catch (error) {
                    console.error('🎵 Failed to start music:', error);
                }
            });
        }
        
        if (pauseBtn) {
            pauseBtn.addEventListener('click', pauseMusic);
        }
        
        if (volumeSlider) {
            volumeSlider.addEventListener('input', function(e) {
                setVolume(e.target.value / 100);
            });
        }
        
        // UI event listeners are handled here, audio events are global
        // Mark UI listeners as attached
        window.meraGlobalAudio._listenersAttached = true;
    }
    
    // Initialize immediately when script loads
    async function initialize() {
        createTopBar();
        
        // Try to restore previous audio state immediately
        try {
            const restored = await restoreAudioState();
            if (!restored) {
                updateUI();
            }
        } catch (e) {
            console.error('Error during initialization:', e);
            updateUI();
        }
        
        // Monitor for page changes and recreate if needed
        let currentUrl = window.location.href;
        let currentHash = window.location.hash;
        
        // Handle both URL changes and hash changes (for SPA navigation)
        const checkForNavigation = async () => {
            const newUrl = window.location.href;
            const newHash = window.location.hash;
            
            if (newUrl !== currentUrl || newHash !== currentHash) {
                const oldUrl = currentUrl;
                currentUrl = newUrl;
                currentHash = newHash;
                console.log(`🎵 Navigation detected: ${oldUrl} → ${currentUrl}`);
                console.log(`🎵 Audio state before navigation - playing: ${window.meraIsPlaying}, src: ${window.meraGlobalAudio?.src}`);
                
                // Remember if audio was playing before navigation
                const wasPlayingBeforeNav = window.meraIsPlaying && !window.meraGlobalAudio.paused;
                const audioSrcBeforeNav = window.meraGlobalAudio?.src;
                
                // Force save state immediately on navigation
                saveAudioState();
                
                setTimeout(async () => {
                    console.log(`🎵 Audio state after navigation timeout - playing: ${window.meraIsPlaying}, src: ${window.meraGlobalAudio?.src}`);
                    
                    if (!document.getElementById('mera-top-bar')) {
                        console.log('🎵 Recreating music player after navigation...');
                        createTopBar();
                    }
                    
                    // Always try to restore audio state after navigation
                    try {
                        const restored = await restoreAudioState();
                        console.log(`🎵 Restoration result: ${restored}`);
                        if (!restored && wasPlayingBeforeNav && audioSrcBeforeNav) {
                            // Force continuation if audio was playing before navigation
                            console.log('🎵 Restoration failed, forcing audio continuation...');
                            window.meraGlobalAudio.src = audioSrcBeforeNav;
                            window.meraIsPlaying = true;
                            try {
                                await window.meraGlobalAudio.play();
                                console.log('🎵 Successfully forced audio continuation');
                            } catch (e) {
                                console.log('🎵 Could not force play:', e);
                                window.meraIsPlaying = false;
                            }
                        }
                        updateUI();
                    } catch (e) {
                        console.error('Error restoring audio after navigation:', e);
                        // Last resort: if we know audio was playing, try to continue it
                        if (wasPlayingBeforeNav && audioSrcBeforeNav) {
                            console.log('🎵 Exception during restore, attempting fallback continuation...');
                            window.meraGlobalAudio.src = audioSrcBeforeNav;
                            window.meraIsPlaying = true;
                            try {
                                window.meraGlobalAudio.play();
                            } catch (playError) {
                                window.meraIsPlaying = false;
                            }
                        }
                        updateUI();
                    }
                    
                    // Ensure event listeners are still attached after navigation
                    if (window.meraGlobalAudio && !window.meraGlobalAudio._listenersAttached) {
                        console.log('🎵 Reattaching event listeners after navigation...');
                        setupEventListeners();
                        window.meraGlobalAudio._listenersAttached = true;
                    }
                }, 100);
            }
        };
        
        // Monitor URL changes with polling
        setInterval(checkForNavigation, 500);
        
        // Also listen for browser navigation events
        window.addEventListener('popstate', checkForNavigation);
        window.addEventListener('hashchange', checkForNavigation);
        
        // Also monitor for DOM changes that might indicate page content updates
        if ('MutationObserver' in window) {
            const observer = new MutationObserver((mutations) => {
                let shouldRecreate = false;
                
                mutations.forEach(mutation => {
                    // Check if top bar was removed
                    if (!document.getElementById('mera-top-bar')) {
                        shouldRecreate = true;
                    }
                    
                    // Check if significant DOM changes occurred (new content loaded)
                    if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                        mutation.addedNodes.forEach(node => {
                            if (node.nodeType === Node.ELEMENT_NODE && 
                                (node.classList?.contains('docs-main') || 
                                 node.tagName === 'MAIN' ||
                                 node.classList?.contains('content'))) {
                                shouldRecreate = true;
                            }
                        });
                    }
                });
                
                if (shouldRecreate) {
                    console.log('🎵 Top bar missing due to DOM changes, recreating...');
                    setTimeout(() => {
                        if (!document.getElementById('mera-top-bar')) {
                            createTopBar();
                        }
                    }, 50);
                }
            });
            
            // Observe the document body for changes
            observer.observe(document.body, { childList: true, subtree: true });
            console.log('🎵 DOM observer attached to document body');
        }
        
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