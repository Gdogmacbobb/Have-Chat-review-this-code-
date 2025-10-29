// Inject debugging for platform detection
console.log('🔧 DEBUG: Injecting platform detection debugging...');

// Override console.log to capture debug messages
const originalLog = console.log;
window.platformDebugLogs = [];

console.log = function(...args) {
  // Capture debug messages from platform detection
  const message = args.join(' ');
  if (message.includes('[DEBUG]') || message.includes('Platform') || 
      message.includes('Browser') || message.includes('Camera') ||
      message.includes('MediaDevices') || message.includes('getUserMedia')) {
    window.platformDebugLogs.push(message);
    console.log('🚨 CAPTURED: ' + message);
  }
  originalLog.apply(console, args);
};

// Try to trigger platform detection directly if possible
if (window.PlatformCameraService) {
  console.log('🔧 DEBUG: Found PlatformCameraService, triggering check...');
  window.PlatformCameraService.checkCameraCapabilities().then(result => {
    console.log('🔧 DEBUG: Platform capability result:', result);
  }).catch(err => {
    console.log('🔧 DEBUG: Platform capability error:', err);
  });
}

console.log('🔧 DEBUG: Platform detection debugging injected');
