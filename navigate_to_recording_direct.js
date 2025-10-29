// Navigate directly to test video recording to trigger debug logs
console.log('[DIRECT NAV] Navigating to test video recording...');

// Direct navigation approach for Flutter web
window.location.href = window.location.origin + '/#/test-video-recording';

// Log what we're doing
console.log('[DIRECT NAV] Set URL to test video recording route');
console.log('[DIRECT NAV] Current URL:', window.location.href);
