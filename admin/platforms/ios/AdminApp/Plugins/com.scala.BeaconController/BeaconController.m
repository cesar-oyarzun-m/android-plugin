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
    NSLog(@"getBeaconList");
    [self performSelector:@selector(getBeaconArrayWitCommand:) withObject:command afterDelay:3.0];
}

- (void)readBeacon:(CDVInvokedUrlCommand*)command {
    NSString* argString = command.arguments[0];
    NSError* error;
    NSDictionary* argDict = [NSJSONSerialization JSONObjectWithData:[argString dataUsingEncoding:NSUTF8StringEncoding]
                                                            options: NSJSONReadingMutableContainers
                                                              error: &error];
    
    NSString* major = [argDict objectForKey:@"major"];
    NSString* minor = [argDict objectForKey:@"minor"];

    NSString* identifier = [NSString stringWithFormat:@"%@%@%@", major, @"_", minor];
    CLBeacon* beacon = [detectedBeacons objectForKey:identifier];
    if(beacon != nil){
        if([beacon isMemberOfClass:[ESTBeacon class]]){
            [estBeaconController stopBeacon];
            [estBeaconController readBeacon:(ESTBeacon *)beacon withCallback:^(NSDictionary *beaconInfo) {
                CDVPluginResult* pluginResult = nil;
                if(beaconInfo != nil) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:beaconInfo];
                } else {
                    NSDictionary* error = [NSDictionary dictionaryWithObject:@"error read beacon" forKey:@"error"];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:error];
                }
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                [estBeaconController scanAllBeacons];
            }];
        }
    }
}

- (void)updateBeacon:(CDVInvokedUrlCommand*)command {
    NSString* argString = command.arguments[0];
    NSError* error;
    NSDictionary* argDict = [NSJSONSerialization JSONObjectWithData:[argString dataUsingEncoding:NSUTF8StringEncoding]
                                                            options: NSJSONReadingMutableContainers
                                                              error: &error];
    [estBeaconController updateBeacon:argDict withCallback:^(NSString *updateStatus) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:updateStatus];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        [estBeaconController disconnectBeacon];
    }];
}

- (void)stopScanning:(CDVInvokedUrlCommand*)command {
    [estBeaconController stopBeacon];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"beacon scanning stopped"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(NSMutableArray*) sortBeaconArrayUsingRssi:(NSMutableArray*) beaconArray {
    [beaconArray sortUsingComparator:^NSComparisonResult(CLBeacon* beacon1, CLBeacon* beacon2) {
        NSInteger rssi1 =  abs(beacon1.rssi);
        NSInteger rssi2 = abs(beacon2.rssi);
        
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
    
    NSMutableArray* jsonArray = [[NSMutableArray alloc]init];
    
    for(ESTBeacon* beacon in beaconArray){
        NSMutableDictionary* jsonBeacon = [[NSMutableDictionary alloc]init];
        [jsonBeacon setValue:[beacon.proximityUUID UUIDString] forKey:@"proximityUuid"];
        [jsonBeacon setValue:[NSString stringWithFormat:@"%ld", (long)beacon.rssi] forKey:@"rssi"];
        [jsonBeacon setValue:[NSString stringWithFormat:@"%@", beacon.major] forKey:@"major"];
        [jsonBeacon setValue:[NSString stringWithFormat:@"%@", beacon.minor] forKey:@"minor"];
        [jsonArray addObject:jsonBeacon];
    }
    
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:jsonArray];
    
    //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"beaconList"];
    
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
    NSLog(@"did read beacon info: %@", beaconInfo);
}

-(void) estBeaconController:(ESTBeaconController *)bController didUpdateBeacon:(NSString *)updateStatus {
    //[delegate beaconController:self didUpdateBeacon:updateStatus];
}

-(void) estBeaconController:(ESTBeaconController *)bController didDisconnectBeacon:(NSString *)disconnectStatus {
    //[delegate beaconController:self didDisconnectBeacon:disconnectStatus];
}

@end
