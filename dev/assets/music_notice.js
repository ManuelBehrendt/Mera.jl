// MERA Study Music - Reality Check Notice
(function() {
    'use strict';
    
    // Check if music was playing when page loaded
    const wasPlaying = localStorage.getItem('mera-music-playing') === 'true';
    const lastTrack = localStorage.getItem('mera-music-track');
    
    if (wasPlaying && lastTrack) {
        // Show a discrete notice that music stopped
        const notice = document.createElement('div');
        notice.style.cssText = `
            position: fixed;
            top: 10px;
            right: 10px;
            background: rgba(102, 126, 234, 0.9);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            z-index: 9999;
            opacity: 0.8;
        `;
        notice.textContent = '🎵 Music paused (page reload)';
        document.body.appendChild(notice);
        
        // Auto-hide notice after 3 seconds
        setTimeout(() => {
            notice.style.opacity = '0';
            setTimeout(() => notice.remove(), 1000);
        }, 3000);
        
        console.log('🎵 Music was interrupted by page navigation');
    }
})();