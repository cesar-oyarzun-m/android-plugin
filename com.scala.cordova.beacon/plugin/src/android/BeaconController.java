package android;

import android.util.Log;

import com.estimote.sdk.Beacon;
import com.estimote.sdk.BeaconManager;
import com.estimote.sdk.Region;
import com.estimote.sdk.Utils;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.List;



public class BeaconController extends CordovaPlugin
{
	private static final String LOGTAG = "EstimoteBeacons";
//	private static final String ESTIMOTE_PROXIMITY_UUID = "B9407F30-F5F8-466E-AFF9-25556B57FE6D";
//	private static final String ESTIMOTE_SAMPLE_REGION_ID = "EstimoteSampleRegion";
    private static final Region ALL_ESTIMOTE_BEACONS_REGION = new Region("rid", null, null, null);

	private BeaconManager mBeaconManager;

	private boolean mIsConnected = false;

	// Maps that keep track of Cordova callbacks.
	private HashMap<String, CallbackContext> mRangingCallbackContexts =
		new HashMap<String, CallbackContext>();

	/**
	 * Plugin initialiser.
	 */
	@Override
	public void initialize(final CordovaInterface cordova, CordovaWebView webView)
	{
		Log.i(LOGTAG, "initialize");

		super.initialize(cordova, webView);

		if (mBeaconManager == null) {
			mBeaconManager = new BeaconManager(webView.getContext());
		}

		mBeaconManager.setErrorListener(new BeaconManager.ErrorListener() {
			@Override
			public void onError(Integer errorId) {
				Log.e(LOGTAG, "BeaconManager error: " + errorId);
			}
		});
	}

	/**
	 * Plugin reset.
	 * Called when the WebView does a top-level navigation or refreshes.
	 */
	@Override
	public void onReset() {
		Log.i(LOGTAG, "onReset");
		disconnectBeaconManager();
		mRangingCallbackContexts = new HashMap<String, CallbackContext>();
	}

	/**
	 * The final call you receive before your activity is destroyed.
	 */
	public void onDestroy() {
		Log.i(LOGTAG, "onDestroy");
		disconnectBeaconManager();
	}

	/**
	 * Disconnect from the beacon manager.
	 */
	private void disconnectBeaconManager() {
		if (mBeaconManager != null && mIsConnected) {
			mBeaconManager.disconnect();
			mIsConnected = false;
		}
	}

	/**
	 * Entry point for JavaScript calls.
	 */
	@Override
	public boolean execute(
		String action,
		CordovaArgs args,
		final CallbackContext callbackContext)
		throws JSONException
	{
		if ("startRanging".equals(action)) {
			startRanging(args, callbackContext);
		}
		else if ("stopRanging".equals(action)) {
            stopRanging(args, callbackContext);
		}
//		else if ("beacons_startMonitoringForRegion".equals(action)) {
//			startMonitoringForRegion(args, callbackContext);
//		}
//		else if ("beacons_stopMonitoringForRegion".equals(action)) {
//			stopMonitoringForRegion(args, callbackContext);
//		}
		else {
			return false;
		}
		return true;
	}

	/**
	 * Start ranging for beacons.
	 */
	private void startRanging(
		CordovaArgs cordovaArgs,
		final CallbackContext callbackContext)
		throws JSONException
	{
		Log.i(LOGTAG, "startRanging");

		JSONObject json = cordovaArgs.getJSONObject(0);

		final Region region = createRegion(json);

		// TODO: How to handle case when region already ranged?
		// Stop ranging then start again?
		// Currently, if ranging callback already exists we
		// do nothing, just return.
		String key = regionHashMapKey(region);
		if (null != mRangingCallbackContexts.get(key)) {
			return;
		}

		// Add callback to hash map.
		mRangingCallbackContexts.put(key, callbackContext);

		// Create ranging listener.
		mBeaconManager.setRangingListener(new PluginRangingListener());

		// If connected start ranging immediately, otherwise first connect.
		if (mIsConnected) {
			startRanging(region, callbackContext);
		}
		else {
			Log.i(LOGTAG, "connect");
			mBeaconManager.connect(new BeaconManager.ServiceReadyCallback() {
				@Override
				public void onServiceReady() {
					Log.i(LOGTAG, "onServiceReady");
					mIsConnected = true;
					startRanging(region, callbackContext);
				}
			});
		}
	}

	/**
	 * Helper method.
	 */
	private void startRanging(Region region, CallbackContext callbackContext)
	{
		try {
			Log.i(LOGTAG, "startRanging");
			mBeaconManager.startRanging(region);
		}
		catch(android.os.RemoteException e) {
			Log.e(LOGTAG, "startRanging error:", e);
			callbackContext.error("Start ranging RemoteException");
		}
	}

	/**
	 * Stop ranging for beacons.
	 */
	private void stopRanging(
		CordovaArgs cordovaArgs,
		final CallbackContext callbackContext)
		throws JSONException
	{
		Log.i(LOGTAG, "stopRanging");

		JSONObject json = cordovaArgs.getJSONObject(0);

		Region region = createRegion(json);

		// If ranging callback does not exist call error callback
		String key = regionHashMapKey(region);
		CallbackContext rangingCallback = mRangingCallbackContexts.get(key);
		if (null == rangingCallback) {
			callbackContext.error("Region not ranged");
			return;
		}

		// Remove ranging callback from hash map.
		mRangingCallbackContexts.remove(key);

		// Clear ranging callback on JavaScript side.
		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
		result.setKeepCallback(false);
		rangingCallback.sendPluginResult(result);

		// Stop ranging if connected.
		if (mIsConnected) {
			try {
				Log.i(LOGTAG, "stopRanging");

				// Stop ranging.
				mBeaconManager.stopRanging(region);

				// Send back success.
				callbackContext.success();
			}
			catch(android.os.RemoteException e) {
				Log.e(LOGTAG, "stopRanging", e);
				callbackContext.error("stopRanging RemoteException");
			}
		}
		else {
			callbackContext.error("Not connected");
		}
	}

	/**
	 * Create JSON object representing beacon info.
	 *
	 * beaconInfo format:
	 * {
	 *     region: region,
	 *     beacons: array of beacon
	 * }
	 */
	private JSONObject makeJSONBeaconInfo(Region region, List<Beacon> beacons)
		throws JSONException
	{
		// Create JSON object.
		JSONObject json = new JSONObject();
		json.put("beacons", makeJSONBeaconArray(beacons));
		return json;
	}

	/**
	 * Create JSON object representing a region in the given state.
	 */
	private static JSONObject makeJSONRegion(Region region, String state)
		throws JSONException
	{
		JSONObject json = new JSONObject();
		json.put("identifier", region.getIdentifier());
		json.put("uuid", region.getProximityUUID());
		json.put("major", region.getMajor());
		json.put("minor", region.getMinor());
		if (state != null) {
			json.put("state", state);
		}
		return json;
	}

	/**
	 * Create JSON object representing a beacon list.
	 */
	private JSONArray makeJSONBeaconArray(List<Beacon> beacons)
		throws JSONException
	{
		JSONArray jsonArray = new JSONArray();
		for (Beacon b : beacons) {
			// Compute proximity value.
			Utils.Proximity proximityValue = Utils.computeProximity(b);
			int proximity = 0; // Unknown.
			if (Utils.Proximity.IMMEDIATE == proximityValue) { proximity = 1; }
			else if (Utils.Proximity.NEAR == proximityValue) { proximity = 2; }
			else if (Utils.Proximity.FAR == proximityValue) { proximity = 3; }

			// Compute distance value.
			double distance = Utils.computeAccuracy(b);

			// Normalize UUID.
			String uuid = Utils.normalizeProximityUUID(b.getProximityUUID());

			// Construct JSON object for beacon.
			JSONObject json = new JSONObject();
			json.put("major", b.getMajor());
			json.put("minor", b.getMinor());
			json.put("rssi", b.getRssi());
			json.put("measuredPower", b.getMeasuredPower());
			json.put("proximityUUID", uuid);
			json.put("proximity", proximity);
			json.put("distance", distance);
			json.put("name", b.getName());
			json.put("macAddress", b.getMacAddress());
			jsonArray.put(json);
		}
		return jsonArray;
	}

	private String regionHashMapKey(Region region)
	{
		String uuid = region.getProximityUUID();
		int major = null != region.getMajor() ? region.getMajor().intValue() : 0;
		int minor = null != region.getMinor() ? region.getMinor().intValue() : 0;
		return uuid + "-" + major + "-" + minor;
	}

	/**
	 * Create a Region object from Cordova arguments.
	 */
	private Region createRegion(JSONObject json) {
//		return new Region(
//			json.optString("identifier", ESTIMOTE_SAMPLE_REGION_ID),
//			json.optString("uuid", ESTIMOTE_PROXIMITY_UUID),
//			optUInt16Null(json, "major"),
//			optUInt16Null(json, "minor"));
        return ALL_ESTIMOTE_BEACONS_REGION;
	}



	/**
	 * Listener for ranging events.
	 */
	class PluginRangingListener implements BeaconManager.RangingListener {
		@Override
		public void onBeaconsDiscovered(Region region, List<Beacon> beacons) {
			// Note that results are not delivered on UI thread.

			Log.i(LOGTAG, "onBeaconsDiscovered");

			try {
				// Find region callback.
				String key = regionHashMapKey(region);
				CallbackContext rangingCallback = mRangingCallbackContexts.get(key);
				if (null == rangingCallback) {
					// No callback found.
					Log.e(LOGTAG,
						"onBeaconsDiscovered no callback found for key: " + key);
					return;
				}

				// Create JSON beacon info object.
				JSONObject json = makeJSONBeaconInfo(region, beacons);

				// Send result to JavaScript.
				PluginResult r = new PluginResult(PluginResult.Status.OK, json);
				r.setKeepCallback(true);
				rangingCallback.sendPluginResult(r);
			}
			catch(JSONException e) {
				Log.e(LOGTAG, "onBeaconsDiscovered error:", e);
			}
		}
	}
}