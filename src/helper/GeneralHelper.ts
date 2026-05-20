export function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
export function getRandomInt(max: number) {
  return Math.floor(Math.random() * max)
}
export function isLocalhost() {
  return location.hostname === 'localhost' || location.hostname === '127.0.0.1'
}
export function formatSeconds(totalSeconds: number) {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return [
    hours > 0 ? String(hours).padStart(2, '0') : null,
    String(minutes).padStart(2, '0'),
    String(seconds).padStart(2, '0')
  ]
    .filter(Boolean)
    .join(':');
}
