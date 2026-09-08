import android.content.Context;
import android.media.AudioManager;
import android.os.Looper;

/**
 * Persistent audio mode watcher for Samsung Exynos devices.
 * 
 * Forces MODE_IN_COMMUNICATION when the Samsung HAL tries to set MODE_IN_CALL,
 * which prevents the mic from being routed through the modem path.
 * Also forces speaker output — required to activate the audio path on Samsung HAL.
 * 
 * Designed to run via app_process as a persistent process (no JVM restart per detection).
 */
public class AudioModeHelper {

    private static final int MODE_IN_CALL = 2;
    private static final int MODE_IN_COMMUNICATION = 3;
    private static final long POLL_INTERVAL_MS = 50;

    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();

        Class<?> atClass = Class.forName("android.app.ActivityThread");
        Object at = atClass.getMethod("systemMain").invoke(null);
        Context ctx = (Context) atClass.getMethod("getSystemContext").invoke(at);
        AudioManager am = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);

        System.out.println("AudioModeHelper: watcher started, polling every " + POLL_INTERVAL_MS + "ms");

        while (true) {
            int mode = am.getMode();
            if (mode == MODE_IN_CALL) {
                am.setMode(MODE_IN_COMMUNICATION);
                am.setSpeakerphoneOn(true);
                System.out.println("FIXED:IN_CALL->IN_COMMUNICATION+speaker");
            }
            Thread.sleep(POLL_INTERVAL_MS);
        }
    }
}
