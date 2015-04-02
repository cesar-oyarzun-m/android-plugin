var exec = cordova.require('cordova/exec');

/*
	Contents of this file:
	* Common Helper Functions
	* Estimote Beacon Functions
	* Estimote Stickers Functions
*/

/*********************************************************/
/**************** Common Helper Functions ****************/
/*********************************************************/

/**
 * Helpers
 */
function isString(value)
{
	return (typeof value == 'string' || value instanceof String);
}

function isInt(value)
{
	return !isNaN(parseInt(value, 10)) && (parseFloat(value, 10) == parseInt(value, 10));
}

function checkExecParamsRegionSuccessError(region, success, error)
{
	var caller = checkExecParamsRegionSuccessError.caller.name

	if (typeof region != "object") {
		console.error("Error: region parameter is not an object in: " + caller);
		return false;
	}

	if (typeof success != "function") {
		console.error("Error: success parameter is not a function in: " + caller);
		return false;
	}

	if (typeof error != "function") {
		console.error("Error: error parameter is not a function in: " + caller);
		return false;
	}

	return true;
}

function checkExecParamsSuccessError(success, error)
{
	var caller = checkExecParamsSuccessError.caller.name

	if (typeof success != "function") {
		console.error("Error: success parameter is not a function in: " + caller);
		return false;
	}

	if (typeof error != "function") {
		console.error("Error: error parameter is not a function in: " + caller);
		return false;
	}

	return true;
}

function checkExecParamsRegion(region)
{
	var caller = checkExecParamsRegion.caller.name

	if (typeof region != "object") {
		console.error("Error: region parameter is not an object in: " + caller);
		return false;
	}

	return true;
}

/*********************************************************/
/******************* Estimote Objects ********************/
/*********************************************************/

/**
 *  Object that is exported. Holds two modules, beacons and nearables.
 */
var estimote = {};
estimote.beacons = {};
estimote.nearables = {};

/**
 * Print an object. Useful for debugging. Example calls:
 *   estimote.printObject(obj);
 *   estimote.printObject(obj, console.log);
 */
estimote.printObject = function(obj, printFun)
{
	if (!printFun) { printFun = console.log; }
	function print(obj, level)
	{
		var indent = new Array(level + 1).join("  ");
		for (var prop in obj) {
			if (obj.hasOwnProperty(prop)) {
				var value = obj[prop];
				if (typeof value == "object") {
					printFun(indent + prop + ":");
					print(value, level + 1);
				}
				else {
					printFun(indent + prop + ": " + value);
				}
			}
		}
	}
	print(obj, 0);
};

/*********************************************************/
/*************** Estimote Beacon Functions ***************/
/*********************************************************/

/**
 * Proximity values.
 */
estimote.beacons.ProximityUnknown = 0;
estimote.beacons.ProximityImmediate = 1;
estimote.beacons.ProximityNear = 2;
estimote.beacons.ProximityFar = 3;

/**
 * Beacon colours.
 */
estimote.beacons.BeaconColorUnknown = 0;
estimote.beacons.BeaconColorMint = 1;
estimote.beacons.BeaconColorIce = 2;
estimote.beacons.BeaconColorBlueberry = 3;
estimote.beacons.BeaconColorWhite = 4;
estimote.beacons.BeaconColorTransparent = 5;

/**
 * Region states.
 */
estimote.beacons.RegionStateUnknown = "unknown";
estimote.beacons.RegionStateOutside = "outside";
estimote.beacons.RegionStateInside = "inside";

/**
 * Ask the user for permission to use location services
 * while the app is in the foreground.
 * You need to call this function or requestAlwaysAuthorization
 * on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param success Function called on success (optional).
 * @param error Function called on error (optional).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example:
 *   estimote.beacons.requestWhenInUseAuthorization()
 *
 * More information:
 *   https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services
 */
estimote.beacons.requestWhenInUseAuthorization = function (success, error)
{
	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_requestWhenInUseAuthorization",
		[]
	);

	return true;
};

/**
 * Ask the user for permission to use location services
 * whenever the app is running.
 * You need to call this function or requestWhenInUseAuthorization
 * on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param success Function called on success (optional).
 * @param error Function called on error (optional).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example:
 *   estimote.beacons.requestAlwaysAuthorization()
 *
 * More information:
 *   https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services
 */
estimote.beacons.requestAlwaysAuthorization = function (success, error)
{
	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_requestAlwaysAuthorization",
		[]
	);

	return true;
};

/**
 * Get the current location authorization status.
 * Implemented on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param success Function called on success (mandatory).
 * @param error Function called on error (mandatory).
 *
 * success callback format:
 *   success(result)
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example:
 *   estimote.beacons.authorizationStatus(
 *     function(result) {
 *       console.log('Location authorization status: ' + result) },
 *     function(errorMessage) {
 *       console.log('Error: ' + errorMessage) }
 *   )
 *
 * More information:
 *   https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services
 */
estimote.beacons.authorizationStatus = function (success, error)
{
	if (!checkExecParamsSuccessError(success, error)) {
		return false;
	}

	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_authorizationStatus",
		[]
	);

	return true;
};

/**
 * Start advertising as a beacon.
 *
 * @param uuid UUID string the beacon should advertise (string, mandatory).
 * @param major Major value to advertise (integer, mandatory).
 * @param minor Minor value to advertise (integer, mandatory).
 * @param regionId Identifier of the region used to advertise (string, mandatory).
 * @param success Function called on success (non-mandatory).
 * @param error Function called on error (non-mandatory).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that starts advertising:
 *   estimote.beacons.startAdvertisingAsBeacon(
 *     'B9407F30-F5F8-466E-AFF9-25556B57FE6D',
 *     1,
 *     1,
 *     'MyRegion',
 *     function(result) {
 *       console.log('Beacon started') },
 *     function(errorMessage) {
 *       console.log('Error starting beacon: ' + errorMessage) }
 *   )
 */
estimote.beacons.startAdvertisingAsBeacon = function (
	uuid, major, minor, regionId, success, error)
{
	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_startAdvertisingAsBeacon",
		[uuid, major, minor, regionId]
	);

	return true;
};

/**
 * Stop advertising as a beacon.
 *
 * @param success Function called on success (mandatory).
 * @param error Function called on error (mandatory).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that stops advertising:
 *   estimote.beacons.stopAdvertisingAsBeacon(
 *     function(result) {
 *       console.log('Beacon stopped') },
 *     function(errorMessage) {
 *       console.log('Error stopping beacon: ' + errorMessage) }
 *   )
 */
estimote.beacons.stopAdvertisingAsBeacon = function (success, error)
{
	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_stopAdvertisingAsBeacon",
		[]
	);

	return true;
};

/**
 * Start scanning for beacons using CoreBluetooth.
 *
 * @param region Dictionary with region properties (mandatory).
 * @param success Function called when beacons are detected (mandatory).
 * @param error Function called on error (mandatory).
 *
 * region format:
 *   {
 *     uuid: string,
 *     identifier: string,
 *     major: number,
 *     minor: number,
 *     secure: boolean
 *   }
 *
 * The region field "secure" is supported on iOS for enabling
 * secure beacon regions. Leaving it out defaults to false.
 * See this article for further info:
 * https://community.estimote.com/hc/en-us/articles/204233603-How-security-feature-works
 *
 * success callback format:
 *   success(beaconInfo)
 *
 * beaconInfo format:
 *   {
 *     region: region,
 *     beacons: array of beacon
 *   }
 *
 * beacon format:
 *   {
 *     // See documented properties at:
 *     // http://estimote.github.io/iOS-SDK/Classes/ESTBeacon.html
 *   }
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that prints all discovered beacons and properties:
 *   estimote.beacons.startEstimoteBeaconsDiscoveryForRegion(
 *     {}, // Empty region matches all beacons.
 *     function(result) {
 *       console.log('*** Beacons discovered ***')
 *       estimote.printObject(result) },
 *     function(errorMessage) {
 *       console.log('Discovery error: ' + errorMessage) }
 *   )
 */
estimote.beacons.startEstimoteBeaconsDiscoveryForRegion = function (region, success, error)
{
	if (!checkExecParamsRegionSuccessError(region, success, error)) {
		return false;
	}

	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_startEstimoteBeaconsDiscoveryForRegion",
		[region]
	);

	return true;
};

/**
 * Stop CoreBluetooth scan.
 *
 * @param success Function called when beacons are detected (non-mandatory).
 * @param error Function called on error (non-mandatory).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that stops discovery:
 *   estimote.beacons.stopEstimoteBeaconDiscovery()
 */
estimote.beacons.stopEstimoteBeaconDiscovery = function (success, error)
{
	exec(success,
		error,
		"EstimoteBeacons",
		"beacons_stopEstimoteBeaconDiscovery",
		[]
	);

	return true;
};

/**
 * Start ranging beacons using CoreLocation.
 *
 * @param region Dictionary with region properties (mandatory).
 * @param success Function called when beacons are ranged (mandatory).
 * @param error Function called on error (mandatory).
 *
 * See function startEstimoteBeaconsDiscoveryForRegion for region format.
 *
 * success callback format:
 *   success(beaconInfo)
 *
 * See function startEstimoteBeaconsDiscoveryForRegion for beaconInfo format.
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that prints all beacons and properties:
 *   estimote.beacons.startRangingBeaconsInRegion(
 *     {}, // Empty region matches all beacons.
 *     function(result) {
 *       console.log('*** Beacons ranged ***')
 *       estimote.printObject(result) },
 *     function(errorMessage) {
 *       console.log('Ranging error: ' + errorMessage) }
 *   )
 */
estimote.beacons.startRanging = function (region, success, error)
{
	if (!checkExecParamsRegionSuccessError(region, success, error)) {
		return false;
	}

	exec(success,
		error,
		"EstimoteBeacons",
		"startRanging",
		[region]
	);

	return true;
};

/**
 * Stop ranging beacons using CoreLocation.
 *
 * @param region Dictionary with region properties (mandatory).
 * @param success Function called when ranging is stopped (non-mandatory).
 * @param error Function called on error (non-mandatory).
 *
 * success callback format:
 *   success()
 *
 * error callback format:
 *   error(errorMessage)
 *
 * Example that stops ranging:
 *   estimote.beacons.stopRangingBeaconsInRegion({})
 */
estimote.beacons.stopRanging = function (region, success, error)
{
	if (!checkExecParamsRegion(region)) {
		return false;
	}

	exec(success,
		error,
		"EstimoteBeacons",
		"stopRanging",
		[region]
	);

	return true;
};





// For backwards compatibility.
estimote.beacons.printObject = estimote.printObject
window.EstimoteBeacons = estimote.beacons;

module.exports = estimote;
