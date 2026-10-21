package com.gathin.tvhome;

/**
 * Tracks Back button presses to detect a double-press within a given timeout window.
 */
public class DoubleBackDetector {
    public static final long DEFAULT_TIMEOUT_MS = 500L;

    private final long timeoutMs;
    private long lastPressMs;

    public DoubleBackDetector() {
        this(DEFAULT_TIMEOUT_MS);
    }

    public DoubleBackDetector(long timeoutMs) {
        this.timeoutMs = timeoutMs;
    }

    /**
     * Call on Back key press.
     * @param nowMs current time in milliseconds (e.g. SystemClock.elapsedRealtime())
     * @return true if this press occurred within timeoutMs of the previous press.
     */
    public boolean onBackPress(long nowMs) {
        if (lastPressMs > 0 && nowMs >= lastPressMs && (nowMs - lastPressMs) <= timeoutMs) {
            lastPressMs = 0;
            return true;
        }
        lastPressMs = nowMs;
        return false;
    }

    public void reset() {
        lastPressMs = 0;
    }
}
