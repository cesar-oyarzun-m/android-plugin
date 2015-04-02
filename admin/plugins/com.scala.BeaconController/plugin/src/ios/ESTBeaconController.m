//
//  ESTBeaconController.m
//  NextAdmin
//
//  Created by Wenyao Hu on 2/11/15.
//  Copyright (c) 2015 scala. All rights reserved.
//

#import "ESTBeaconController.h"
@interface ESTBeaconController()  {
    OSSpinLock _asyncActionLock;
    unsigned int _asyncAction;
    ESTBeaconRegion* theRegion;
    ESTBeacon* theBeacon;
    NSString* connectionError;
    NSString* updateStatus;
    NSString* disconnectStatus;
    NSString* readStatus;
    NSMutableDictionary* rssiHistory;
    
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define DLog(...)
#endif
    
}
@end

@implementation ESTBeaconController
@synthesize delegate;

-(id) initWithProximityList:(NSSet*) proximityUuidList {
    self = [super init];
    rssiHistory = [[NSMutableDictionary alloc]init];
    
    if (self) {
        _asyncActionLock = OS_SPINLOCK_INIT;
    }
    
    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;
    self.monitoredRegions = [[NSMutableDictionary alloc]init];
    
    for(NSString* proximityUuid in proximityUuidList){
        NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:proximityUuid];
        ESTBeaconRegion *beaconRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid identifier:proximityUuid];
        beaconRegion.notifyEntryStateOnDisplay = YES;
        beaconRegion.notifyOnEntry = YES;
        beaconRegion.notifyOnExit = YES;
        self.monitoredRegions[proximityUuid] = beaconRegion;
    }
    
    // add default estimote proximityUUID to the monitored regions
    ESTBeaconRegion *beaconRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:ESTIMOTE_PROXIMITY_UUID identifier:[ESTIMOTE_PROXIMITY_UUID UUIDString]];
    beaconRegion.notifyEntryStateOnDisplay = YES;
    beaconRegion.notifyOnEntry = YES;
    beaconRegion.notifyOnExit = YES;
    [self.monitoredRegions setValue:beaconRegion forKey:[ESTIMOTE_PROXIMITY_UUID UUIDString]];
    
    _detectedBeacons = [[NSMutableDictionary alloc]init];
    
    return self;
}


#pragma mark - Public
-(void) scanAllBeacons {
    NSArray* regions = [self.monitoredRegions allValues];
    for(ESTBeaconRegion* region in regions) {
        [self.beaconManager startRangingBeaconsInRegion:region];
    }
}

-(void) stopBeacon {
    NSArray* regions = [self.monitoredRegions allValues];
    for(ESTBeaconRegion* region in regions) {
        [self.beaconManager stopRangingBeaconsInRegion:region];
    }
}

-(void) readBeacon:(ESTBeacon*)beacon {
    readStatus = @"";
    
    if(beacon != nil) {
        theBeacon = beacon;
        theBeacon.delegate = self;
        [self increaseAsyncAction];
        [theBeacon connectToBeacon];
    }
    
    [self performSelectorInBackground:@selector(postReadBeacon) withObject:nil];
}

-(void) readBeacon:(ESTBeacon*) beacon withCallback:(void (^) (NSDictionary* beaconInfo)) callbackBlock {
    readStatus = @"";
    
    if(beacon != nil) {
        theBeacon = beacon;
        theBeacon.delegate = self;
        [self increaseAsyncAction];
        [theBeacon connectToBeacon];
    }
    
    [self performSelectorInBackground:@selector(postReadBeacon:) withObject:callbackBlock];
}

-(void) updateBeacon:(NSDictionary*) parameters {
    if(theBeacon.isConnected){
        updateStatus = @"success";
        NSString* interval = [parameters objectForKey:@"interval"];
        NSString* power = [parameters objectForKey:@"power"];
        NSString* proximityUuid = [parameters objectForKey:@"proximityUuid"];
        
        if(interval != nil) {
            [self editAdvertIntervalWithString:interval];
        }
        
        if(power != nil) {
            [self editPowerLevelWithValue:[power longLongValue]];
        }
        
        if(proximityUuid != nil) {
            [self writeBeaconProximityUuid:[ESTIMOTE_PROXIMITY_UUID UUIDString]];
        }
        
    } else {
        updateStatus = @"beacon is not connected!";
    }
    
    [self performSelectorInBackground:@selector(postUpdateBeacon) withObject:nil];
}

-(void) updateBeacon:(NSDictionary*) parameters withCallback:(void (^) (NSString* updateStatus)) callbackBlock {
    if(theBeacon.isConnected){
        updateStatus = @"success";
        NSString* interval = [parameters objectForKey:@"interval"];
        NSString* power = [parameters objectForKey:@"power"];
        NSString* proximityUuid = [parameters objectForKey:@"proximityUuid"];
        
        if(interval != nil) {
            [self editAdvertIntervalWithString:interval];
        }
        
        if(power != nil) {
            [self editPowerLevelWithValue:[power longLongValue]];
        }
        
        if(proximityUuid != nil) {
            if([proximityUuid length] < 10) {
                [self writeBeaconProximityUuid:[ESTIMOTE_PROXIMITY_UUID UUIDString]];
            } else {
                [self writeBeaconProximityUuid:proximityUuid];
            }
        }
        
    } else {
        updateStatus = @"beacon is not connected!";
    }
    
    [self performSelectorInBackground:@selector(postUpdateBeacon:) withObject:callbackBlock];
}

-(void) disconnectBeacon {
    disconnectStatus = @"success";
    [self disconnectBeaconInternal];
    
    [self performSelectorInBackground:@selector(postDisconnectBeacon) withObject:nil];
}

-(void) disconnectBeacon:(void (^)(NSString* status)) callbackBlock {
    disconnectStatus = @"success";
    [self disconnectBeaconInternal];
    
    [self performSelectorInBackground:@selector(postDisconnectBeacon:) withObject:callbackBlock];
}


#pragma mark - ESTBeaconManagerDelegate
-(void)beaconManager:(ESTBeaconManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region {
    for(ESTBeacon* beacon in beacons){
        int proximity = beacon.proximity;
        if(_desiredProximity != 0 && (proximity > _desiredProximity || proximity == 0)){
            continue;
        }
        
        if(beacon.rssi != 0){
            NSString* identifier = [NSString stringWithFormat:@"%@%@%@", beacon.major, @"_", beacon.minor];
            NSMutableArray* beaconQueue = rssiHistory[identifier];
            if(beaconQueue == nil){
                // the beacon is discovered first time
                beaconQueue = [[NSMutableArray alloc]init];
                
            }
            NSMutableDictionary *beaconHistory = [NSMutableDictionary dictionaryWithObject:identifier forKey:@"identifier"];
            beaconHistory[@"timestamp"] = [NSNumber numberWithFloat:CACurrentMediaTime()];
            [self pushObject:beaconHistory ToQueue:beaconQueue withLength:1];
            rssiHistory[identifier] = beaconQueue;
            
            _detectedBeacons[identifier] = beacon;
            NSLog(@"EST beacon: %@", identifier);
        }
    }
    
    //sort rssi history and remove beacon which hasn't reported in 5 seconds
    NSArray* prevBeacons = [rssiHistory allValues];
    for(NSMutableArray* bQueue in prevBeacons){
        NSMutableDictionary* b = bQueue[0];
        NSNumber *timeStamp = [b objectForKey:@"timestamp"];
        NSNumber *cTime = [NSNumber numberWithFloat:CACurrentMediaTime()];
        if(([cTime doubleValue] - [timeStamp doubleValue]) > 5.0) {
            NSString* identifier = [b objectForKey:@"identifier"];
            [rssiHistory removeObjectForKey:identifier];
            [_detectedBeacons removeObjectForKey:identifier];
        }
    }
}

#pragma mark - ESTBeaconDelegate
- (void)beaconConnectionDidFail:(ESTBeacon*)beacon withError:(NSError*)error {
    DLog(@"beacon connection did fail:\n%@", [error description]);
    
    connectionError = [error localizedDescription];
    [self decreaseAsyncAction];
}


- (void)beaconConnectionDidSucceeded:(ESTBeacon*)beacon {
    connectionError = @"";
    DLog(@"beacon connection succeeds!");
    DLog(@"battery level: %d", beacon.batteryLevel.intValue);
    DLog(@"interval: %d", beacon.advInterval.intValue);
    
    [self increaseAsyncAction];
    [beacon readBeaconPowerWithCompletion:^(ESTBeaconPower value, NSError *error) {
        if(error != nil){
            readStatus = [error localizedDescription];
        } else {
            DLog(@"power: %@", [NSNumber numberWithChar:value]);
        }
        [self decreaseAsyncAction];
    }];
    
    [self decreaseAsyncAction];
}

-(void) beaconDidDisconnect:(ESTBeacon *)beacon withError:(NSError *)error {
    if(error != nil) {
        DLog(@"beacon can't be disconnected!");
    }
    [self decreaseAsyncAction];
}


#pragma mark - Internal
- (void)editPowerLevelWithValue:(ESTBeaconPower)powerLevel {
    [self increaseAsyncAction];
    [theBeacon writeBeaconPower:powerLevel withCompletion:^(ESTBeaconPower value, NSError *error) {
        if (error) {
            updateStatus = [error localizedDescription];
        }
        
        [self decreaseAsyncAction];
    }];
}

- (void)editAdvertIntervalWithString:(NSString*)frequencyString {
    NSNumberFormatter* formatter = [NSNumberFormatter new];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    NSNumber* number = [formatter numberFromString:frequencyString];
    
    [self increaseAsyncAction];
    [theBeacon writeBeaconAdvInterval:[number unsignedShortValue] withCompletion:^(unsigned short value, NSError *error) {
        if (error) {
            updateStatus = [error localizedDescription];
        }
        
        [self decreaseAsyncAction];
    }];
}

- (void) writeBeaconProximityUuid:(NSString*) prxomityUuid {
    [self increaseAsyncAction];
    [theBeacon writeBeaconProximityUUID:prxomityUuid withCompletion:^(NSString *value, NSError *error) {
        if (error) {
            updateStatus = [error localizedDescription];
        }
        
        [self decreaseAsyncAction];
    }];
}


-(void) postReadBeacon {
    NSMutableDictionary *beaconInfo = [[NSMutableDictionary alloc]init];
    if(theBeacon != nil) {
        int count = 0;
        while(_asyncAction != 0 && count < 15){
            DLog(@"wait .....");
            
            count +=1;
            [NSThread sleepForTimeInterval:1.0];
        }
        
        if ([connectionError length] > 0) {
            [beaconInfo setObject:connectionError  forKey:@"error"];
        } else if([readStatus length] > 0) {
            [beaconInfo setObject:readStatus forKey:@"error"];
            [self disconnectBeaconInternal];
        } else if(_asyncAction != 0){
            _asyncAction = 0;
            [beaconInfo setObject:@"read beacon info error" forKey:@"error"];
            [self disconnectBeaconInternal];
        } else {
            [beaconInfo setObject:[NSString stringWithFormat:@"%@%@%@", theBeacon.major, @"_", theBeacon.minor] forKey:@"identifier"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%ld",(long)theBeacon.rssi] forKey:@"proximity"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%ld",(long)theBeacon.proximity] forKey:@"range"];
            [beaconInfo setObject:theBeacon.proximityUUID.UUIDString forKey:@"proximityUuid"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.batteryLevel.intValue] forKey:@"battery"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.advInterval.intValue] forKey:@"interval"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.power.intValue] forKey:@"power"];
        }

    }
    [delegate estBeaconController:self didReadBeaconInfo:beaconInfo];
}


-(void) postReadBeacon:(void (^)(NSDictionary* dataNode))callbackBlock {
    NSMutableDictionary *beaconInfo = [[NSMutableDictionary alloc]init];
    if(theBeacon != nil) {
        int count = 0;
        while(_asyncAction != 0 && count < 15){
            DLog(@"wait .....");
            
            count +=1;
            [NSThread sleepForTimeInterval:1.0];
        }
        
        if ([connectionError length] > 0) {
            [beaconInfo setObject:connectionError  forKey:@"error"];
        } else if([readStatus length] > 0) {
            [beaconInfo setObject:readStatus forKey:@"error"];
            [self disconnectBeaconInternal];
        } else if(_asyncAction != 0){
            _asyncAction = 0;
            [beaconInfo setObject:@"read beacon info error" forKey:@"error"];
            [self disconnectBeaconInternal];
        } else {
            [beaconInfo setObject:[NSString stringWithFormat:@"%@%@%@", theBeacon.major, @"_", theBeacon.minor] forKey:@"identifier"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%ld",(long)theBeacon.rssi] forKey:@"proximity"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%ld",(long)theBeacon.proximity] forKey:@"range"];
            [beaconInfo setObject:theBeacon.proximityUUID.UUIDString forKey:@"proximityUuid"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.batteryLevel.intValue] forKey:@"battery"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.advInterval.intValue] forKey:@"interval"];
            [beaconInfo setObject:[NSString stringWithFormat:@"%d", theBeacon.power.intValue] forKey:@"power"];
        }
        
    }
    callbackBlock(beaconInfo);
}

-(void) postUpdateBeacon {
    int count = 0;
    while(_asyncAction != 0 && count < 15){
        DLog(@"wait for update to finish .....");
        
        count +=1;
        [NSThread sleepForTimeInterval:1.0];
    }
    
    if(_asyncAction != 0){
        updateStatus = @"update beacon failed!";
        _asyncAction = 0;
    }
    [self disconnectBeaconInternal];
    [delegate estBeaconController:self didUpdateBeacon:updateStatus];
}

-(void) postUpdateBeacon:(void (^)(NSString* updateStaus))callbackBlock {
    int count = 0;
    while(_asyncAction != 0 && count < 15){
        DLog(@"wait for update to finish .....");
        
        count +=1;
        [NSThread sleepForTimeInterval:1.0];
    }
    
    if(_asyncAction != 0){
        updateStatus = @"update beacon failed!";
        _asyncAction = 0;
    }
    [self disconnectBeaconInternal];
    callbackBlock(updateStatus);
}

-(void) postDisconnectBeacon {
    int count = 0;
    while(_asyncAction != 0 && count < 15){
        DLog(@"wait for beacon to be disconnected .....");
        
        count +=1;
        [NSThread sleepForTimeInterval:1.0];
    }
    
    if(_asyncAction != 0){
        disconnectStatus = @"disconnect beacon failed!";
        _asyncAction = 0;
    }
    theBeacon = nil;
    [delegate estBeaconController:self didDisconnectBeacon:disconnectStatus];
}

-(void) postDisconnectBeacon:(void (^) (NSString* status)) callbackBlock {
    int count = 0;
    while(_asyncAction != 0 && count < 15){
        DLog(@"wait for beacon to be disconnected .....");
        
        count +=1;
        [NSThread sleepForTimeInterval:1.0];
    }
    
    if(_asyncAction != 0){
        disconnectStatus = @"disconnect beacon failed!";
        _asyncAction = 0;
    }
    theBeacon = nil;
    callbackBlock(disconnectStatus);
}

-(void) disconnectBeaconInternal {
    if(theBeacon.isConnected){
        [self increaseAsyncAction];
        [theBeacon disconnectBeacon];
    }
}

- (void)increaseAsyncAction {
    OSSpinLockLock(&_asyncActionLock);
    _asyncAction++;
    OSSpinLockUnlock(&_asyncActionLock);
}

- (void)decreaseAsyncAction {
    OSSpinLockLock(&_asyncActionLock);
    _asyncAction--;
    OSSpinLockUnlock(&_asyncActionLock);
}

-(void) dealloc {
    if(theBeacon.isConnected){
        [theBeacon disconnectBeacon];
    }
}


- (void) pushObject:(NSObject *) obj ToQueue:(NSMutableArray *) queue withLength:(int) length {
    [queue addObject:obj];
    if([queue count] > length){
        [queue removeObjectAtIndex:0];
    }
}


@end
