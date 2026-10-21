package com.gathin.tvhome;

import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class DoubleBackDetectorTest {

    @Test
    public void singlePressDoesNotTrigger() {
        DoubleBackDetector detector = new DoubleBackDetector(500);
        assertFalse(detector.onBackPress(1000));
    }

    @Test
    public void doublePressWithinTimeoutTriggers() {
        DoubleBackDetector detector = new DoubleBackDetector(500);
        assertFalse(detector.onBackPress(1000));
        assertTrue(detector.onBackPress(1300));
    }

    @Test
    public void doublePressAfterTimeoutDoesNotTrigger() {
        DoubleBackDetector detector = new DoubleBackDetector(500);
        assertFalse(detector.onBackPress(1000));
        assertFalse(detector.onBackPress(1600));
    }

    @Test
    public void thirdPressAfterTriggerDoesNotTriggerImmediately() {
        DoubleBackDetector detector = new DoubleBackDetector(500);
        assertFalse(detector.onBackPress(1000));
        assertTrue(detector.onBackPress(1300)); // Triggered, resets
        assertFalse(detector.onBackPress(1400)); // New first press
    }

    @Test
    public void resetClearsPendingPress() {
        DoubleBackDetector detector = new DoubleBackDetector(500);
        assertFalse(detector.onBackPress(1000));
        detector.reset();
        assertFalse(detector.onBackPress(1200));
    }
}
