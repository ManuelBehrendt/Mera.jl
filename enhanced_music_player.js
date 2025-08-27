/**
 * Enhanced MERA.jl Music Player with Popup Support
 * Supports transferring playback between top bar and popup window
 */

class MeraAmbientMusicPlayer {
    constructor() {
        this.musicTracks = [
            { file: 'docs/src/assets/music/alpha_centauri.mp3', name: 'Alpha Centauri' },
            { file: 'docs/src/assets/music/andromeda_galaxy.mp3', name: 'Andromeda Galaxy' },
            { file: 'docs/src/assets/music/betelgeuse_supergiant.mp3', name: 'Betelgeuse Supergiant' },
            { file: 'docs/src/assets/music/cassiopeia_constellation.mp3', name: 'Cassiopeia Constellation' },
            { file: 'docs/src/assets/music/crab_nebula.mp3', name: 'Crab Nebula' },
            { file: 'docs/src/assets/music/eagle_nebula.mp3', name: 'Eagle Nebula' },
            { file: 'docs/src/assets/music/horsehead_nebula.mp3', name: 'Horsehead Nebula' },
            { file: 'docs/src/assets/music/orion_nebula.mp3', name: 'Orion Nebula' },
            { file: 'docs/src/assets/music/proxima_centauri.mp3', name: 'Proxima Centauri' },
            { file: 'docs/src/assets/music/sagittarius_a_star.mp3', name: 'Sagittarius A Star' },
            { file: 'docs/src/assets/music/vega.mp3', name: 'Vega' }
        ];
        
        // Shared state across all player instances
        this.globalState = {
            currentAudio: null,
            currentTrack: null,
            isPlaying: false,
            currentTime: 0,
            volume: 0.15,
            activePlayer: null, // 'topbar' or 'popup'
            popupWindow: null
        };
        
        this.initializePlayer();
        this.setupMessageHandling();
    }
    
    initializePlayer() {
        this.createTopBarPlayer();
        this.loadSavedSettings();
    }
    
    createTopBarPlayer() {
        const targetElement = document.getElementById('music-player-location') || 
                             document.querySelector('.sidebar') || 
                             document.body;
        
        const playerHTML = `
            <div id="mera-music-player" class="mera-music-player">
                <button id="mera-music-toggle" class="mera-music-button" onclick="meraPlayer.toggleCompactMode()">
                    🎵 Study Music
                </button>
                
                <div id="mera-music-expanded" class="mera-music-expanded" style="display: none;">
                    <div class="mera-music-controls">
                        <button class="mera-control-btn" onclick="meraPlayer.playRandomTrack()" title="Play Random Track">
                            🔀
                        </button>
                        <button id="mera-play-pause" class="mera-control-btn" onclick="meraPlayer.togglePlayPause()">
                            ▶️
                        </button>
                        <button class="mera-control-btn" onclick="meraPlayer.openPopup()" title="Open in Popup">
                            🔲
                        </button>
                    </div>
                    
                    <div class="mera-volume-control">
                        <label for="mera-volume">🔊</label>
                        <input type="range" id="mera-volume" min="0" max="100" value="15" 
                               onchange="meraPlayer.updateVolume(this.value)">
                        <span id="mera-volume-display">15%</span>
                    </div>
                    
                    <div id="mera-track-status" class="mera-track-status">
                        Click 🔀 to start music
                    </div>
                </div>
            </div>
            
            <style>
                .mera-music-player {
                    margin: 10px 0;
                    font-family: system-ui, -apple-system, sans-serif;
                }
                
                .mera-music-button {
                    width: 100%;
                    padding: 8px 12px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border: none;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 13px;
                    transition: opacity 0.2s;
                }
                
                .mera-music-button:hover {
                    opacity: 0.9;
                }
                
                .mera-music-expanded {
                    background: #f9f9f9;
                    border-radius: 6px;
                    padding: 12px;
                    margin-top: 8px;
                    border: 1px solid #e0e0e0;
                }
                
                .mera-music-controls {
                    display: flex;
                    gap: 6px;
                    margin-bottom: 10px;
                }
                
                .mera-control-btn {
                    flex: 1;
                    padding: 6px;
                    background: #fff;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 12px;
                    transition: background-color 0.2s;
                }
                
                .mera-control-btn:hover {
                    background: #f0f0f0;
                }
                
                .mera-volume-control {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 10px;
                }
                
                .mera-volume-control input {
                    flex: 1;
                }
                
                .mera-track-status {
                    font-size: 11px;
                    color: #666;
                    text-align: center;
                    padding: 4px;
                    background: #fff;
                    border-radius: 4px;
                    border: 1px solid #eee;
                }
                
                .mera-track-status.playing {
                    color: #4caf50;
                    border-color: #4caf50;
                }
                
                .mera-track-status.paused {
                    color: #ff9800;
                    border-color: #ff9800;
                }
            </style>
        `;
        
        if (targetElement) {
            targetElement.insertAdjacentHTML('afterbegin', playerHTML);
        }
    }
    
    toggleCompactMode() {
        const expanded = document.getElementById('mera-music-expanded');
        const button = document.getElementById('mera-music-toggle');
        
        if (expanded.style.display === 'none') {
            expanded.style.display = 'block';
            button.textContent = '🎵 Hide Controls';
        } else {
            expanded.style.display = 'none';
            button.textContent = '🎵 Study Music';
        }
    }
    
    openPopup() {
        // Transfer current playback state to popup
        const currentState = this.getCurrentPlaybackState();
        
        // Create popup window
        const popup = window.open('', 'MeraAmbientPlayer', 
            'width=400,height=600,scrollbars=no,resizable=yes,status=no,toolbar=no,menubar=no');
        
        this.globalState.popupWindow = popup;
        
        // Stop current player and mark popup as active
        this.pauseTopBarPlayer();
        this.globalState.activePlayer = 'popup';
        
        // Create popup content
        this.createPopupContent(popup, currentState);
        
        // Handle popup close
        popup.addEventListener('beforeunload', () => {
            this.handlePopupClose();
        });
    }
    
    createPopupContent(popupWindow, currentState) {
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
                        <input type="range" id="popup-volume" min="0" max="100" value="${Math.round(currentState.volume * 100)}" 
                               onchange="popupPlayer.updateVolume(this.value)">
                        <div class="popup-volume-display" id="popup-volume-display">${Math.round(currentState.volume * 100)}%</div>
                    </div>
                    
                    <div id="popup-status" class="popup-status">
                        ${currentState.track ? 
                          (currentState.isPlaying ? 
                           \`🎵 Playing: \${currentState.track.name}\` : 
                           \`⏸️ Paused: \${currentState.track.name}\`) : 
                          'Click Random to start music'}
                    </div>
                    
                    <div class="popup-track-list">
                        <div style="font-size: 12px; opacity: 0.8; margin-bottom: 10px; text-align: center;">
                            🌌 Ambient Track Library
                        </div>
                        ${this.musicTracks.map((track, index) => 
                            \`<div class="popup-track-item \${currentState.track && currentState.track.name === track.name ? 'active' : ''}" 
                                  onclick="popupPlayer.playTrack(\${index})">
                                \${track.name}
                            </div>\`
                        ).join('')}
                    </div>
                </div>
                
                <script>
                    class PopupMusicPlayer {
                        constructor(initialState) {
                            this.currentState = initialState;
                            this.currentAudio = null;
                            this.parentWindow = window.opener;
                            
                            // Continue playing from where the main player left off
                            if (this.currentState.track) {
                                this.loadTrack(this.currentState.track, this.currentState.currentTime);
                            }
                        }
                        
                        loadTrack(track, startTime = 0) {
                            if (this.currentAudio) {
                                this.currentAudio.pause();
                                this.currentAudio = null;
                            }
                            
                            this.currentAudio = new Audio(track.file);
                            this.currentAudio.volume = this.currentState.volume;
                            this.currentAudio.loop = true;
                            this.currentAudio.currentTime = startTime;
                            
                            this.currentAudio.addEventListener('canplaythrough', () => {
                                if (this.currentState.isPlaying) {
                                    this.currentAudio.play();
                                    this.updateStatus(\`🎵 Playing: \${track.name}\`);
                                    document.getElementById('popup-play-pause').textContent = '⏸️ Pause';
                                }
                            });
                            
                            this.currentState.track = track;
                        }
                        
                        playRandomTrack() {
                            const tracks = ${JSON.stringify(this.musicTracks)};
                            const randomTrack = tracks[Math.floor(Math.random() * tracks.length)];
                            this.playTrack(tracks.indexOf(randomTrack));
                        }
                        
                        playTrack(index) {
                            const tracks = ${JSON.stringify(this.musicTracks)};
                            const track = tracks[index];
                            this.loadTrack(track);
                            
                            this.currentAudio.play().then(() => {
                                this.currentState.isPlaying = true;
                                this.updateStatus(\`🎵 Playing: \${track.name}\`);
                                document.getElementById('popup-play-pause').textContent = '⏸️ Pause';
                                this.updateTrackHighlight(track.name);
                            });
                        }
                        
                        togglePlayPause() {
                            if (!this.currentAudio) {
                                this.playRandomTrack();
                                return;
                            }
                            
                            if (this.currentState.isPlaying) {
                                this.currentAudio.pause();
                                this.currentState.isPlaying = false;
                                this.updateStatus(\`⏸️ Paused: \${this.currentState.track.name}\`);
                                document.getElementById('popup-play-pause').textContent = '▶️ Play';
                            } else {
                                this.currentAudio.play();
                                this.currentState.isPlaying = true;
                                this.updateStatus(\`🎵 Playing: \${this.currentState.track.name}\`);
                                document.getElementById('popup-play-pause').textContent = '⏸️ Pause';
                            }
                        }
                        
                        updateVolume(value) {
                            this.currentState.volume = value / 100;
                            document.getElementById('popup-volume-display').textContent = value + '%';
                            
                            if (this.currentAudio) {
                                this.currentAudio.volume = this.currentState.volume;
                            }
                        }
                        
                        updateStatus(message) {
                            document.getElementById('popup-status').innerHTML = message;
                        }
                        
                        updateTrackHighlight(trackName) {
                            document.querySelectorAll('.popup-track-item').forEach(item => {
                                item.classList.toggle('active', item.textContent.trim() === trackName);
                            });
                        }
                        
                        returnToMain() {
                            // Transfer state back to main player
                            const transferState = {
                                track: this.currentState.track,
                                isPlaying: this.currentState.isPlaying,
                                currentTime: this.currentAudio ? this.currentAudio.currentTime : 0,
                                volume: this.currentState.volume
                            };
                            
                            // Pause popup player
                            if (this.currentAudio) {
                                this.currentAudio.pause();
                            }
                            
                            // Send message to parent
                            this.parentWindow.postMessage({
                                type: 'transferFromPopup',
                                state: transferState
                            }, '*');
                            
                            window.close();
                        }
                        
                        getCurrentTime() {
                            return this.currentAudio ? this.currentAudio.currentTime : 0;
                        }
                    }
                    
                    const popupPlayer = new PopupMusicPlayer(${JSON.stringify(currentState)});
                    
                    // Update parent window with current playback time periodically
                    setInterval(() => {
                        if (popupPlayer.parentWindow && popupPlayer.currentAudio) {
                            popupPlayer.parentWindow.postMessage({
                                type: 'popupTimeUpdate',
                                currentTime: popupPlayer.getCurrentTime(),
                                isPlaying: popupPlayer.currentState.isPlaying
                            }, '*');
                        }
                    }, 1000);
                </script>
            </body>
            </html>
        `;
        
        popupWindow.document.write(popupHTML);
        popupWindow.document.close();
    }
    
    getCurrentPlaybackState() {
        return {
            track: this.globalState.currentTrack,
            isPlaying: this.globalState.isPlaying,
            currentTime: this.globalState.currentAudio ? this.globalState.currentAudio.currentTime : 0,
            volume: this.globalState.volume
        };
    }
    
    pauseTopBarPlayer() {
        if (this.globalState.currentAudio) {
            this.globalState.currentTime = this.globalState.currentAudio.currentTime;
            this.globalState.currentAudio.pause();
            this.globalState.isPlaying = false;
        }
        
        this.updateTopBarUI();
    }
    
    setupMessageHandling() {
        window.addEventListener('message', (event) => {
            if (event.data.type === 'transferFromPopup') {
                this.handleTransferFromPopup(event.data.state);
            } else if (event.data.type === 'popupTimeUpdate') {
                this.globalState.currentTime = event.data.currentTime;
                this.globalState.isPlaying = event.data.isPlaying;
            }
        });
    }
    
    handleTransferFromPopup(state) {
        this.globalState.activePlayer = 'topbar';
        this.globalState.currentTrack = state.track;
        this.globalState.volume = state.volume;
        this.globalState.currentTime = state.currentTime;
        
        if (state.track) {
            this.loadTrackInTopBar(state.track, state.currentTime);
            if (state.isPlaying) {
                this.globalState.currentAudio.play().then(() => {
                    this.globalState.isPlaying = true;
                    this.updateTopBarUI();
                });
            }
        }
        
        this.updateTopBarUI();
    }
    
    handlePopupClose() {
        this.globalState.activePlayer = 'topbar';
        this.globalState.popupWindow = null;
        this.updateTopBarUI();
    }
    
    playRandomTrack() {
        if (this.globalState.activePlayer === 'popup') return; // Let popup handle it
        
        const track = this.getRandomTrack();
        this.loadTrackInTopBar(track);
        
        this.globalState.currentAudio.play().then(() => {
            this.globalState.isPlaying = true;
            this.globalState.currentTrack = track;
            this.updateTopBarUI();
        });
    }
    
    loadTrackInTopBar(track, startTime = 0) {
        if (this.globalState.currentAudio) {
            this.globalState.currentAudio.pause();
            this.globalState.currentAudio = null;
        }
        
        this.globalState.currentAudio = new Audio(track.file);
        this.globalState.currentAudio.volume = this.globalState.volume;
        this.globalState.currentAudio.loop = true;
        this.globalState.currentAudio.currentTime = startTime;
        
        this.globalState.currentTrack = track;
    }
    
    togglePlayPause() {
        if (this.globalState.activePlayer === 'popup') return; // Let popup handle it
        
        if (!this.globalState.currentAudio) {
            this.playRandomTrack();
            return;
        }
        
        if (this.globalState.isPlaying) {
            this.globalState.currentAudio.pause();
            this.globalState.isPlaying = false;
        } else {
            this.globalState.currentAudio.play().then(() => {
                this.globalState.isPlaying = true;
            });
        }
        
        this.updateTopBarUI();
    }
    
    updateVolume(value) {
        this.globalState.volume = value / 100;
        
        if (this.globalState.currentAudio) {
            this.globalState.currentAudio.volume = this.globalState.volume;
        }
        
        document.getElementById('mera-volume-display').textContent = value + '%';
        this.saveSettings();
        this.updateTopBarUI();
    }
    
    updateTopBarUI() {
        const playPauseBtn = document.getElementById('mera-play-pause');
        const statusDiv = document.getElementById('mera-track-status');
        
        if (playPauseBtn) {
            playPauseBtn.textContent = this.globalState.isPlaying ? '⏸️' : '▶️';
        }
        
        if (statusDiv) {
            statusDiv.className = 'mera-track-status';
            
            if (this.globalState.activePlayer === 'popup') {
                statusDiv.textContent = '🔲 Playing in popup window';
                statusDiv.classList.add('playing');
            } else if (this.globalState.currentTrack) {
                if (this.globalState.isPlaying) {
                    statusDiv.innerHTML = `🎵 ${this.globalState.currentTrack.name}<br><small>Volume: ${Math.round(this.globalState.volume * 100)}%</small>`;
                    statusDiv.classList.add('playing');
                } else {
                    statusDiv.innerHTML = `⏸️ ${this.globalState.currentTrack.name}<br><small>Paused</small>`;
                    statusDiv.classList.add('paused');
                }
            } else {
                statusDiv.textContent = 'Click 🔀 to start music';
            }
        }
    }
    
    getRandomTrack() {
        const randomIndex = Math.floor(Math.random() * this.musicTracks.length);
        return this.musicTracks[randomIndex];
    }
    
    saveSettings() {
        const settings = {
            volume: this.globalState.volume,
            lastTrack: this.globalState.currentTrack
        };
        localStorage.setItem('meraAmbientSettings', JSON.stringify(settings));
    }
    
    loadSavedSettings() {
        try {
            const saved = localStorage.getItem('meraAmbientSettings');
            if (saved) {
                const settings = JSON.parse(saved);
                this.globalState.volume = settings.volume || 0.15;
                
                const volumeSlider = document.getElementById('mera-volume');
                const volumeDisplay = document.getElementById('mera-volume-display');
                
                if (volumeSlider) {
                    volumeSlider.value = Math.round(this.globalState.volume * 100);
                }
                if (volumeDisplay) {
                    volumeDisplay.textContent = Math.round(this.globalState.volume * 100) + '%';
                }
            }
        } catch (e) {
            console.log('Could not load saved settings:', e);
        }
    }
}

// Initialize the player
let meraPlayer;
document.addEventListener('DOMContentLoaded', function() {
    meraPlayer = new MeraAmbientMusicPlayer();
    console.log('🎵 Enhanced MERA Ambient Music Player initialized');
});