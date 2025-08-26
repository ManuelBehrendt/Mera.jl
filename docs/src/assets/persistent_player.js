// Cross-Tab Persistent Music Player
// Uses localStorage and heartbeat system to maintain music across full page reloads

(function() {
    'use strict';
    
    const STORAGE_KEYS = {
        PLAYING: 'mera-cross-tab-playing',
        TRACK: 'mera-cross-tab-track',
        TIME: 'mera-cross-tab-time',
        VOLUME: 'mera-cross-tab-volume',
        HEARTBEAT: 'mera-cross-tab-heartbeat',
        MASTER: 'mera-cross-tab-master'
    };
    
    const HEARTBEAT_INTERVAL = 1000; // 1 second
    const MASTER_TIMEOUT = 3000; // 3 seconds
    
    class CrossTabMusicPlayer {
        constructor() {
            this.tabId = 'tab-' + Date.now() + '-' + Math.random();
            this.audio = new Audio();
            this.audio.volume = 0.15;
            this.isMaster = false;
            this.isPlaying = false;
            this.currentTrack = '';
            
            this.tracks = [
                'alpha_centauri.mp3', 'andromeda_galaxy.mp3', 'betelgeuse_supergiant.mp3',
                'cassiopeia_constellation.mp3', 'crab_nebula.mp3', 'eagle_nebula.mp3',
                'horsehead_nebula.mp3', 'orion_nebula.mp3', 'proxima_centauri.mp3',
                'sagittarius_a_star.mp3', 'vega.mp3'
            ];
            
            this.init();
        }
        
        async init() {
            this.setupEventListeners();
            await this.checkMasterStatus();
            this.startHeartbeat();
            this.setupStorageListener();
            
            // Try to become master or sync with existing master
            if (this.shouldBecomeMaster()) {
                this.becomeMaster();
            } else {
                this.syncWithMaster();
            }
            
            this.createUI();
        }
        
        shouldBecomeMaster() {
            const lastHeartbeat = parseInt(localStorage.getItem(STORAGE_KEYS.HEARTBEAT) || '0');
            const currentTime = Date.now();
            return (currentTime - lastHeartbeat) > MASTER_TIMEOUT;
        }
        
        async becomeMaster() {
            console.log(`🎵 ${this.tabId} becoming master`);
            this.isMaster = true;
            localStorage.setItem(STORAGE_KEYS.MASTER, this.tabId);
            
            // Restore state if available
            const wasPlaying = localStorage.getItem(STORAGE_KEYS.PLAYING) === 'true';
            const savedTrack = localStorage.getItem(STORAGE_KEYS.TRACK);
            const savedTime = parseFloat(localStorage.getItem(STORAGE_KEYS.TIME) || '0');
            const savedVolume = parseFloat(localStorage.getItem(STORAGE_KEYS.VOLUME) || '0.15');
            
            this.audio.volume = savedVolume;
            
            if (wasPlaying && savedTrack) {
                console.log(`🎵 Master restoring: ${savedTrack} at ${savedTime}s`);
                await this.playTrack(savedTrack, savedTime);
            }
        }
        
        syncWithMaster() {
            console.log(`🎵 ${this.tabId} syncing with master`);
            this.isMaster = false;
            
            // Just update UI, don't control audio
            const isPlaying = localStorage.getItem(STORAGE_KEYS.PLAYING) === 'true';
            const currentTrack = localStorage.getItem(STORAGE_KEYS.TRACK);
            
            this.isPlaying = isPlaying;
            this.currentTrack = currentTrack || '';
        }
        
        setupEventListeners() {
            this.audio.addEventListener('play', () => {
                if (this.isMaster) {
                    this.isPlaying = true;
                    this.saveState();
                    this.updateUI();
                }
            });
            
            this.audio.addEventListener('pause', () => {
                if (this.isMaster) {
                    this.isPlaying = false;
                    this.saveState();
                    this.updateUI();
                }
            });
            
            this.audio.addEventListener('timeupdate', () => {
                if (this.isMaster && this.isPlaying) {
                    localStorage.setItem(STORAGE_KEYS.TIME, this.audio.currentTime.toString());
                }
            });
            
            this.audio.addEventListener('ended', () => {
                if (this.isMaster && this.isPlaying) {
                    this.playRandomTrack();
                }
            });
            
            // Handle tab becoming master when current master closes
            window.addEventListener('beforeunload', () => {
                if (this.isMaster) {
                    localStorage.removeItem(STORAGE_KEYS.MASTER);
                    localStorage.removeItem(STORAGE_KEYS.HEARTBEAT);
                }
            });
        }
        
        setupStorageListener() {
            window.addEventListener('storage', (e) => {
                if (e.key === STORAGE_KEYS.PLAYING || e.key === STORAGE_KEYS.TRACK) {
                    // Non-master tabs update their UI when state changes
                    if (!this.isMaster) {
                        this.isPlaying = localStorage.getItem(STORAGE_KEYS.PLAYING) === 'true';
                        this.currentTrack = localStorage.getItem(STORAGE_KEYS.TRACK) || '';
                        this.updateUI();
                    }
                } else if (e.key === STORAGE_KEYS.MASTER || e.key === STORAGE_KEYS.HEARTBEAT) {
                    // Check if we should become master
                    setTimeout(() => {
                        if (this.shouldBecomeMaster()) {
                            this.becomeMaster();
                        }
                    }, 100);
                }
            });
        }
        
        startHeartbeat() {
            setInterval(() => {
                if (this.isMaster) {
                    localStorage.setItem(STORAGE_KEYS.HEARTBEAT, Date.now().toString());
                }
                
                // Check if current master is still alive
                if (!this.isMaster && this.shouldBecomeMaster()) {
                    this.becomeMaster();
                }
            }, HEARTBEAT_INTERVAL);
        }
        
        saveState() {
            localStorage.setItem(STORAGE_KEYS.PLAYING, this.isPlaying.toString());
            localStorage.setItem(STORAGE_KEYS.TRACK, this.currentTrack);
            localStorage.setItem(STORAGE_KEYS.TIME, this.audio.currentTime.toString());
            localStorage.setItem(STORAGE_KEYS.VOLUME, this.audio.volume.toString());
        }
        
        getMusicPath(filename) {
            const currentUrl = window.location.href;
            const currentPath = window.location.pathname;
            
            if (currentUrl.startsWith('file://')) {
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
            } else {
                return `assets/music/${filename}`;
            }
        }
        
        async playTrack(filename, startTime = 0) {
            if (!this.isMaster) return;
            
            const path = this.getMusicPath(filename);
            console.log(`🎵 Master playing: ${path}`);
            
            this.currentTrack = filename;
            this.audio.src = path;
            
            const playWhenReady = () => {
                this.audio.currentTime = startTime;
                this.audio.play().then(() => {
                    this.isPlaying = true;
                    this.saveState();
                    this.updateUI();
                }).catch(e => {
                    console.log('🎵 Play blocked:', e);
                    this.isPlaying = false;
                    this.saveState();
                    this.updateUI();
                });
                this.audio.removeEventListener('canplaythrough', playWhenReady);
            };
            
            if (this.audio.readyState >= 2) {
                playWhenReady();
            } else {
                this.audio.addEventListener('canplaythrough', playWhenReady);
                this.audio.load();
            }
        }
        
        async playRandomTrack() {
            const randomTrack = this.tracks[Math.floor(Math.random() * this.tracks.length)];
            await this.playTrack(randomTrack);
        }
        
        pause() {
            if (!this.isMaster) return;
            
            this.audio.pause();
            this.isPlaying = false;
            this.saveState();
            this.updateUI();
        }
        
        getTrackDisplayName(filename = this.currentTrack) {
            if (!filename) return 'Unknown Track';
            return filename.replace(/\.mp3$/, '').replace(/_/g, ' ')
                .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
        }
        
        createUI() {
            if (document.getElementById('mera-cross-tab-bar')) return;
            
            const topBar = document.createElement('div');
            topBar.id = 'mera-cross-tab-bar';
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
            `;
            
            topBar.innerHTML = `
                <div style="display: flex; align-items: center; gap: 15px;">
                    <span style="color: white; font-weight: 600; font-size: 14px;">🎵 MERA Study Music</span>
                    <button id="cross-tab-play" style="
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
                    <button id="cross-tab-pause" style="
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
                    <span id="cross-tab-status" style="color: rgba(255,255,255,0.9); font-size: 12px;">Ready to play</span>
                    <span id="cross-tab-role" style="color: rgba(255,255,255,0.6); font-size: 10px;"></span>
                </div>
            `;
            
            document.body.insertBefore(topBar, document.body.firstChild);
            document.body.style.paddingTop = '45px';
            
            // Setup event listeners
            document.getElementById('cross-tab-play').addEventListener('click', () => {
                this.playRandomTrack();
            });
            
            document.getElementById('cross-tab-pause').addEventListener('click', () => {
                this.pause();
            });
            
            this.updateUI();
        }
        
        updateUI() {
            const playBtn = document.getElementById('cross-tab-play');
            const pauseBtn = document.getElementById('cross-tab-pause');
            const status = document.getElementById('cross-tab-status');
            const role = document.getElementById('cross-tab-role');
            
            if (!playBtn || !pauseBtn || !status || !role) return;
            
            // Show role
            role.textContent = this.isMaster ? '(Master)' : '(Slave)';
            
            if (this.isPlaying) {
                playBtn.style.display = 'none';
                pauseBtn.style.display = 'inline-block';
                status.textContent = `Playing: ${this.getTrackDisplayName()}`;
            } else {
                playBtn.style.display = 'inline-block';
                pauseBtn.style.display = 'none';
                status.textContent = this.currentTrack ? `Ready: ${this.getTrackDisplayName()}` : 'Ready to play';
            }
            
            // Disable controls for non-master tabs
            playBtn.disabled = !this.isMaster;
            pauseBtn.disabled = !this.isMaster;
            playBtn.style.opacity = this.isMaster ? '1' : '0.6';
            pauseBtn.style.opacity = this.isMaster ? '1' : '0.6';
        }
        
        async checkMasterStatus() {
            const currentMaster = localStorage.getItem(STORAGE_KEYS.MASTER);
            const lastHeartbeat = parseInt(localStorage.getItem(STORAGE_KEYS.HEARTBEAT) || '0');
            const now = Date.now();
            
            if (!currentMaster || (now - lastHeartbeat) > MASTER_TIMEOUT) {
                return true; // Should become master
            }
            
            return currentMaster === this.tabId; // Am I already master?
        }
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            new CrossTabMusicPlayer();
        });
    } else {
        new CrossTabMusicPlayer();
    }
    
})();