// Navigate to video recording screen in Flutter web app
console.log('[NAV] Attempting to navigate to video recording screen...');

// Try multiple navigation approaches for Flutter web apps
function navigateToRecording() {
    try {
        // Method 1: Direct hash navigation
        if (window.location.hash !== '#/video-recording') {
            console.log('[NAV] Setting hash to #/video-recording');
            window.location.hash = '#/video-recording';
        }
        
        // Method 2: Try Flutter's navigation (if available)
        setTimeout(() => {
            if (window.flutter_navigate) {
                console.log('[NAV] Using Flutter navigation');
                window.flutter_navigate('/video-recording');
            }
        }, 500);
        
        // Method 3: Trigger navigation via URL change
        setTimeout(() => {
            console.log('[NAV] Triggering URL change');
            history.pushState({}, '', '/#/video-recording');
            window.dispatchEvent(new PopStateEvent('popstate'));
        }, 1000);
        
        console.log('[NAV] Navigation attempts completed');
    } catch (error) {
        console.error('[NAV] Navigation error:', error);
    }
}

navigateToRecording();
