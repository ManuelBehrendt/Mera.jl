/* MERA.jl Custom Documentation JavaScript */

/* Placeholder for existing custom functionality */
/* This file ensures compatibility with the current build system */

/* The ambient music player is loaded separately via ambient_music_player.js */

console.log('MERA.jl documentation loaded successfully');

// GoatCounter Analytics (invisible, privacy-focused)
// Only visible to site owner for documentation usage statistics
(function() {
    // Only load analytics on production (not local development)
    if (window.location.hostname === 'manuelbehrendt.github.io') {
        // Use official GoatCounter script format
        const script = document.createElement('script');
        script.setAttribute('data-goatcounter', 'https://mera-julia.goatcounter.com/count');
        script.async = true;
        script.src = '//gc.zgo.at/count.js';
        
        // Add to head
        document.head.appendChild(script);
        
        console.log('📊 GoatCounter analytics loaded for documentation tracking');
    }
})();