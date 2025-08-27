// Simple MERA Study Music Player
// Note: Music will pause when navigating to main topics (due to page reloads)
// Subtopics within sections preserve music playback

(function() {
    'use strict';
    
    const tracks = [
        'alpha_centauri.mp3', 'andromeda_galaxy.mp3', 'betelgeuse_supergiant.mp3',
        'cassiopeia_constellation.mp3', 'crab_nebula.mp3', 'eagle_nebula.mp3',
        'horsehead_nebula.mp3', 'orion_nebula.mp3', 'proxima_centauri.mp3',
        'sagittarius_a_star.mp3', 'vega.mp3'
    ];
    
    let audio = new Audio();
    let isPlaying = false;
    let currentTrack = '';
    
    audio.volume = 0.15;
    
    function getMusicPath(filename) {
        const path = window.location.pathname;
        if (path.includes('/dev/') && !path.endsWith('/dev/')) {
            const segments = path.split('/dev/')[1].split('/').filter(s => s);
            const levels = segments.length > 0 && !segments[segments.length - 1].includes('.') ? 
                          segments.length : segments.length - 1;
            const backPath = '../'.repeat(Math.max(0, levels));
            return `${backPath}assets/music/${filename}`;
        }
        return `assets/music/${filename}`;
    }
    
    function getTrackDisplayName(filename) {
        return filename.replace(/\.mp3$/, '').replace(/_/g, ' ')
            .split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
    }
    
    function updateUI() {
        const playBtn = document.getElementById('mera-play');
        const pauseBtn = document.getElementById('mera-pause');
        const status = document.getElementById('mera-status');
        
        if (!playBtn || !pauseBtn || !status) return;
        
        if (isPlaying) {
            playBtn.style.display = 'none';
            pauseBtn.style.display = 'inline-block';
            status.textContent = `♪ ${getTrackDisplayName(currentTrack)}`;
        } else {
            playBtn.style.display = 'inline-block';
            pauseBtn.style.display = 'none';
            status.textContent = currentTrack ? `⏸ ${getTrackDisplayName(currentTrack)}` : '🎵 Study Music';
        }
    }
    
    async function playRandomTrack() {
        const randomTrack = tracks[Math.floor(Math.random() * tracks.length)];
        currentTrack = randomTrack;
        audio.src = getMusicPath(randomTrack);
        
        try {
            await audio.play();
            isPlaying = true;
            updateUI();
        } catch (error) {
            console.log('🎵 Autoplay blocked:', error.message);
            isPlaying = false;
            updateUI();
        }
    }
    
    function pauseMusic() {
        audio.pause();
        isPlaying = false;
        updateUI();
    }
    
    function createUI() {
        // Check if UI already exists
        if (document.getElementById('mera-music-bar')) return;
        
        const musicBar = document.createElement('div');
        musicBar.id = 'mera-music-bar';
        musicBar.style.cssText = `
            position: fixed;
            top: 0;
            right: 20px;
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.95) 0%, rgba(118, 75, 162, 0.95) 100%);
            color: white;
            padding: 6px 12px;
            border-radius: 0 0 8px 8px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 12px;
            z-index: 999999;
            display: flex;
            align-items: center;
            gap: 8px;
            backdrop-filter: blur(10px);
        `;
        
        musicBar.innerHTML = `
            <span id="mera-status">🎵 Study Music</span>
            <button id="mera-play" style="
                background: rgba(255,255,255,0.2);
                border: 1px solid rgba(255,255,255,0.3);
                border-radius: 3px;
                color: white;
                padding: 2px 6px;
                font-size: 11px;
                cursor: pointer;
            ">Play</button>
            <button id="mera-pause" style="
                background: rgba(255,255,255,0.2);
                border: 1px solid rgba(255,255,255,0.3);
                border-radius: 3px;
                color: white;
                padding: 2px 6px;
                font-size: 11px;
                cursor: pointer;
                display: none;
            ">Pause</button>
        `;
        
        document.body.appendChild(musicBar);
        
        // Add event listeners
        document.getElementById('mera-play').addEventListener('click', playRandomTrack);
        document.getElementById('mera-pause').addEventListener('click', pauseMusic);
        
        // Add hover effects
        const buttons = musicBar.querySelectorAll('button');
        buttons.forEach(btn => {
            btn.addEventListener('mouseenter', () => {
                btn.style.background = 'rgba(255,255,255,0.3)';
            });
            btn.addEventListener('mouseleave', () => {
                btn.style.background = 'rgba(255,255,255,0.2)';
            });
        });
    }
    
    // Setup audio events
    audio.addEventListener('ended', () => {
        if (isPlaying) {
            playRandomTrack();
        }
    });
    
    audio.addEventListener('play', () => {
        isPlaying = true;
        updateUI();
    });
    
    audio.addEventListener('pause', () => {
        isPlaying = false;
        updateUI();
    });
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createUI);
    } else {
        createUI();
    }
    
    console.log('🎵 Simple MERA study music loaded');
})();