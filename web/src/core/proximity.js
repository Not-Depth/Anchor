// This consumes synthetic readings in the web app. It does not estimate depth
// from a webcam; a fake estimate would misrepresent the native LiDAR feature.
export class ProximityPolicy {
  constructor(threshold) {
    this.threshold = threshold;
    this.near = false;
    this.lastAlert = -Infinity;
    this.unreliableSince = null;
    this.hadReading = false;
    this.reportedLoss = false;
  }

  update(distance, now) {
    if (!Number.isFinite(distance) || distance < 0) {
      if (!this.hadReading || this.reportedLoss) return null;
      this.unreliableSince ??= now;
      if (now - this.unreliableSince >= 1000) {
        this.reportedLoss = true;
        this.near = false;
        return 'unreliable';
      }
      return null;
    }
    this.hadReading = true;
    this.unreliableSince = null;
    if (this.reportedLoss) {
      this.reportedLoss = false;
      this.near = false;
      return 'restored';
    }
    if (this.near && distance > this.threshold + 0.25) this.near = false;
    else if (this.near || distance <= this.threshold) {
      if (!this.near || now - this.lastAlert >= 3000) {
        this.near = true;
        this.lastAlert = now;
        return 'near';
      }
    }
    return null;
  }
}
