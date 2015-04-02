#import "BeaconController.h"
#import "ESTBeaconController.h"
#import <libkern/OSAtomic.h>

@interface BeaconController () <ESTBeaconControllerDelegate> {
    NSMutableSet* estBeaconProximitySet;
    ESTBeaconController* estBeaconController;
    
    NSMutableDictionary* detectedBeacons;
    CLBeacon* closestBeacon;
    int dProximity;
    
    #ifdef DEBUG
    #   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
    #else
    #   define DLog(...)
    #endif
}

@property (nonatomic, strong) ESTBeaconManager* beaconManager;

@end


@implementation BeaconController

-(BeaconController*) pluginInitialize {
    estBeaconProximitySet = [[NSMutableSet alloc]init];
    
    estBeaconController = [[ESTBeaconController alloc]initWithProximityList:estBeaconProximitySet];
    estBeaconController.desiredProximity = 0;
    estBeaconController.delegate = self;
    
    return self;
}

- (void)startScanning:(CDVInvokedUrlCommand*)command {
    //[self.commandDelegate runInBackground:^{
        [estBeaconController scanAllBeacons];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"beacon scanning started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    //}];
    }


- (void)getBeaconList:(CDVInvokedUrlCommand *)command {
    // delay for 3 seconds to allow scanning beacons
    [self performSelector:@selector(getBeaconArrayWitCommand:) withObject:command afterDelay:3.0];
}

- (void)readBeacon:(CDVInvokedUrlCommand*)command {
    
}

- (void)updateBeacon:(CDVInvokedUrlCommand*)command {
    
}

- (void)stopScanning:(CDVInvokedUrlCommand*)command {
    
}

-(NSMutableArray*) sortBeaconArrayUsingRssi:(NSMutableArray*) beaconArray {
    [beaconArray sortUsingComparator:^NSComparisonResult(CLBeacon* beacon1, CLBeacon* beacon2) {
        NSInteger rssi1 = beacon1.rssi;
        NSInteger rssi2 = beacon2.rssi;;
        
        if(rssi1 > rssi2){
            return NSOrderedAscending;
        } else if(rssi1 < rssi2){
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    return beaconArray;
}

-(void) getBeaconArrayWitCommand:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = nil;
    detectedBeacons = [NSMutableDictionary dictionaryWithDictionary:estBeaconController.detectedBeacons];
    
    NSMutableArray* beaconArray = [NSMutableArray arrayWithArray:[detectedBeacons allValues]];
    beaconArray = [self sortBeaconArrayUsingRssi:beaconArray];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:beaconArray];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/*
- (void)startBeacon:(CDVInvokedUrlCommand*)command
{
    // start looking for beacons in region
    // when beacon ranged beaconManager:didRangeBeacons:inRegion: invoked
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
    if(_region == nil) {
        _region = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"Scala"];
        // create manager instance
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
        [self.beaconManager startRangingBeaconsInRegion:_region];
    }
} */

/*
- (void)printBeacon:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    if (self._test != nil && [self._test length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:self._test];
    } else {
       pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:self._test];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
- (void)printBeacon:(CDVInvokedUrlCommand*)command
{
    self.beaconInfo = @"";
    
    if(_beacon != nil && !_beacon.isConnected){
        
        
        [self.beaconManager stopRangingBeaconsInRegion:_region];
        
        [self increaseAsyncAction];
        [_beacon connectToBeacon];
    }
    
    [self performSelectorInBackground:@selector(returnResults:) withObject:command];
}

-(void) returnResults:(CDVInvokedUrlCommand*) command {
    CDVPluginResult* pluginResult = nil;
    int count=0;
    while(_asyncAction != 0 && count < 10){
        NSLog(@"wait.....");
        count += 1;
        [NSThread sleepForTimeInterval:1.0];
    }
    
    if(_beacon != nil){
        self.beaconInfo = @"{'beacons':[";
        
        NSString *jsongs = [NSString stringWithFormat:@"%@%@%s%@%s%ld%s%d%@", @"{'identifier':'", _beacon.major, "_", _beacon.minor, "','proximity':'", (long)_beacon.rssi, "','range':'", _beacon.proximity, @"',"];
        
        self.beaconInfo = [NSString stringWithFormat:@"%@%@", self.beaconInfo, jsongs ];
        self.beaconInfo = [NSString stringWithFormat:@"%@%@%d%@", self.beaconInfo, @"'battery':'", _beacon.batteryLevel.intValue, @"',"];
        self.beaconInfo = [NSString stringWithFormat:@"%@%@%d%@", self.beaconInfo, @"'interval':'", _beacon.advInterval.intValue, @"',"];
        self.beaconInfo = [NSString stringWithFormat:@"%@%@%d%@", self.beaconInfo, @"'power':'", _beacon.power.intValue, @"'"];
        self.beaconInfo = [NSString stringWithFormat:@"%@%@", self.beaconInfo, @"}]}" ];
        NSLog(@"beacon info: %@", self.beaconInfo);
    }
    
    if (self.beaconInfo != nil && [self.beaconInfo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:self.beaconInfo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
 */

#pragma ESTBeaconControllerDelegate callback
-(void) estBeaconController:(ESTBeaconController *)bController didReadBeaconInfo:(NSDictionary*) beaconInfo {
    //[delegate beaconController:self didReadBeaconInfo:beaconInfo];
}

-(void) estBeaconController:(ESTBeaconController *)bController didUpdateBeacon:(NSString *)updateStatus {
    //[delegate beaconController:self didUpdateBeacon:updateStatus];
}

-(void) estBeaconController:(ESTBeaconController *)bController didDisconnectBeacon:(NSString *)disconnectStatus {
    //[delegate beaconController:self didDisconnectBeacon:disconnectStatus];
}

@end
