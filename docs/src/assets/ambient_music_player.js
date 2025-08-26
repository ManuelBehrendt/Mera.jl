/**
 * MERA.jl Documentation - Ambient Study Music Player
 * Optional background music for enhanced coding/analysis experience
 */

class MeraAmbientPlayer {
    constructor() {
        this.audio = null;
        this.isPlaying = false;
        this.volume = 0.15; // Default volume (15%) - perfect for studying
        this.musicUrl = null; // Will be set when music file is available
        this.playerVisible = false;
        this.currentTrack = null;
        this.availableTracks = [];
        
        this.init();
    }
    
    init() {
        this.createPlayerUI();
        this.loadUserPreferences();
        this.setupEventListeners();
    }
    
    createPlayerUI() {
        // Create compact music player below MERA logo
        const playerHTML = `
            <div id="mera-ambient-player" class="mera-music-player">
                <div class="mera-player-toggle" id="mera-player-toggle">
                    🎵 Study Music
                </div>
                <div class="mera-volume-control">
                    <label for="mera-volume">🔊 Volume:</label>
                    <input type="range" id="mera-volume" min="0" max="100" value="15">
                    <span id="mera-volume-display">15%</span>
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
            const navElement = document.querySelector('nav.docs-sidebar') || 
                              document.querySelector('.docs-sidebar') ||
                              document.querySelector('aside') ||
                              document.querySelector('#documenter .docs-sidebar');
            
            if (navElement) {
                // Add to navigation sidebar below logo, centered
                const centered = `<div style="display: flex; justify-content: center; padding: 0 10px;">${playerHTML}</div>`;
                navElement.insertAdjacentHTML('afterbegin', centered);
                console.log('🎵 Music player injected into Documenter sidebar');
                return true;
            } else if (attempts < maxAttempts) {
                attempts++;
                console.log(`Attempt ${attempts}: Waiting for Documenter sidebar to load...`);
                setTimeout(tryInjectPlayer, 500);
                return false;
            } else {
                // Fallback: add to top of main content
                const mainContent = document.querySelector('main') || 
                                   document.querySelector('.docs-main') || 
                                   document.body;
                const centered = `<div style="display: flex; justify-content: center; padding: 10px;">${playerHTML}</div>`;
                mainContent.insertAdjacentHTML('afterbegin', centered);
                console.log('🎵 Music player added to main content (fallback)');
                return true;
            }
        };
        
        tryInjectPlayer();
        
        // Add CSS styles
        this.addStyles();
    }
    
    addStyles() {
        const styles = `
            <style id="mera-player-styles">
                .mera-music-player {
                    position: relative;
                    margin: 8px 0;
                    z-index: 100;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 220px;
                }
                
                .mera-player-toggle {
                    padding: 6px 12px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    border-radius: 6px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    cursor: pointer;
                    box-shadow: 0 1px 4px rgba(0,0,0,0.15);
                    transition: transform 0.2s ease, box-shadow 0.2s ease;
                    font-size: 12px;
                    color: white;
                    font-weight: 500;
                    border: none;
                    width: 100%;
                }
                
                .mera-player-toggle:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 6px 20px rgba(0,0,0,0.3);
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
    
    setupEventListeners() {
        // Toggle player visibility
        const toggleButton = document.getElementById('mera-player-toggle');
        if (toggleButton) {
            console.log('✅ Found toggle button, setting up click handler');
            toggleButton.addEventListener('click', () => {
                console.log('🎵 Study Music button clicked!');
                this.togglePlayer();
            });
        } else {
            console.error('❌ Toggle button not found - ID: mera-player-toggle');
        }
        
        // Close player
        document.getElementById('mera-player-close').addEventListener('click', () => {
            this.hidePlayer();
        });
        
        // Play button
        document.getElementById('mera-play-btn').addEventListener('click', () => {
            this.play();
        });
        
        // Pause button  
        document.getElementById('mera-pause-btn').addEventListener('click', () => {
            this.pause();
        });
        
        // Volume control
        document.getElementById('mera-volume').addEventListener('input', (e) => {
            this.setVolume(e.target.value / 100);
        });
        
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
                    this.audio.currentTime = 0;
                    this.audio.play();
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
        
        document.getElementById('mera-volume').value = this.volume * 100;
        document.getElementById('mera-volume-display').textContent = Math.round(this.volume * 100) + '%';
        this.saveUserPreferences();
    }
    
    updatePlayButton() {
        const playBtn = document.getElementById('mera-play-btn');
        const pauseBtn = document.getElementById('mera-pause-btn');
        
        if (this.isPlaying) {
            playBtn.style.display = 'none';
            pauseBtn.style.display = 'inline-block';
        } else {
            playBtn.style.display = 'inline-block';
            pauseBtn.style.display = 'none';
        }
    }
    
    updateStatus(message) {
        document.getElementById('mera-status-text').textContent = message;
    }
    
    updateCurrentTrack(trackName) {
        const trackElement = document.getElementById('mera-current-track');
        if (trackElement) {
            trackElement.textContent = trackName ? `♪ ${trackName}` : '';
        }
    }
    
    saveUserPreferences() {
        const prefs = {
            volume: this.volume,
            wasPlaying: this.isPlaying
        };
        localStorage.setItem('mera-music-prefs', JSON.stringify(prefs));
    }
    
    loadUserPreferences() {
        const prefs = localStorage.getItem('mera-music-prefs');
        if (prefs) {
            const parsed = JSON.parse(prefs);
            this.setVolume(parsed.volume || 0.3);
            
            // Don't auto-play on load, but remember preference
            if (parsed.wasPlaying) {
                this.updateStatus('Previously playing - click play to resume');
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

// Initialize player when DOM is ready with multiple fallbacks
function initializeMeraPlayer() {
    console.log('🎵 Starting MERA music player initialization...');
    
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