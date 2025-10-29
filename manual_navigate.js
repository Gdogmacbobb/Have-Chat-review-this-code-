// Manual navigation to test video recording screen
console.log('[TEST] Navigating to test video recording screen...');

// Direct hash change to trigger Flutter routing  
window.location.hash = '#/test-video-recording';

// Also trigger a popstate event
setTimeout(() => {
    window.dispatchEvent(new PopStateEvent('popstate'));
    console.log('[TEST] Navigation triggered');
}, 100);

// Log current location after a delay
setTimeout(() => {
    console.log('[TEST] Current hash:', window.location.hash);
    console.log('[TEST] Current URL:', window.location.href);
}, 500);
