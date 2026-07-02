/* MERA.jl Custom Documentation JavaScript */

/* Placeholder for existing custom functionality */
/* This file ensures compatibility with the current build system */

/* The ambient music player is loaded separately via ambient_music_player.js */

console.log('MERA.jl documentation loaded successfully');

// ===========================================================================
// Multi-code tabs (code-switcher)
// Renders converter-emitted <div class="mera-tabs"> groups as tab bars.
// The selected code is synced across every group and page via localStorage
// (sphinx-tabs behaviour); a hash link into a hidden tab opens that tab.
// Without JS the sections simply render stacked (see custom.css).
// ===========================================================================
(function () {
    const KEY = 'mera-simcode';
    function initTabs() {
        const groups = Array.from(document.querySelectorAll('.mera-tabs'));
        if (!groups.length) return;

        function selectGroup(group, code) {
            const tabs = Array.from(group.querySelectorAll(':scope > .mera-tab'));
            const target = tabs.find(t => t.dataset.code === code) || tabs[0];
            if (!target) return;
            tabs.forEach(t => t.classList.toggle('mera-tab-active', t === target));
            group.querySelectorAll(':scope > .mera-tab-bar > .mera-tab-btn').forEach(b =>
                b.classList.toggle('mera-tab-btn-active', b.dataset.code === target.dataset.code));
        }
        function selectAll(code, save) {
            groups.forEach(g => selectGroup(g, code));
            if (save) { try { localStorage.setItem(KEY, code); } catch (e) { /* private mode */ } }
        }

        groups.forEach(group => {
            const tabs = Array.from(group.querySelectorAll(':scope > .mera-tab'));
            if (!tabs.length) return;
            group.classList.add('mera-tabs-js');
            const bar = document.createElement('div');
            bar.className = 'mera-tab-bar';
            tabs.forEach(tab => {
                const btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'mera-tab-btn';
                btn.textContent = tab.dataset.code;
                btn.dataset.code = tab.dataset.code;
                btn.addEventListener('click', () => selectAll(tab.dataset.code, true));
                bar.appendChild(btn);
            });
            group.insertBefore(bar, group.firstChild);
        });

        let saved = null;
        try { saved = localStorage.getItem(KEY); } catch (e) { /* private mode */ }
        selectAll(saved, false);

        function revealHash() {
            if (!location.hash) return;
            let el = null;
            try { el = document.querySelector(decodeURIComponent(location.hash)); } catch (e) { return; }
            if (!el) return;
            const tab = el.closest('.mera-tab');
            if (tab && !tab.classList.contains('mera-tab-active')) {
                selectAll(tab.dataset.code, false);
                el.scrollIntoView();
            }
        }
        window.addEventListener('hashchange', revealHash);
        revealHash();
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initTabs);
    } else {
        initTabs();
    }
})();

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