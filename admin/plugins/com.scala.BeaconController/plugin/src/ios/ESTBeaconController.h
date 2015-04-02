//
//  ESTBeaconController.h
//  NextAdmin
//
//  Created by Wenyao Hu on 2/11/15.
//  Copyright (c) 2015 scala. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ESTBeaconManager.h"
#import "ESTBeacon.h"
#import <libkern/OSAtomic.h>
#import <QuartzCore/QuartzCore.h>

@class ESTBeaconController;
@protocol ESTBeaconControllerDelegate

-(void) estBeaconController:(ESTBeaconController*) bController didUpdateBeacon:(NSString*) updateStatus;
-(void) estBeaconController:(ESTBeaconController*) bController didDisconnectBeacon:(NSString*) disconnectStatus;
-(void) estBeaconController:(ESTBeaconController*) bController didReadBeaconInfo:(NSDictionary*) beaconInfo;
@end

@interface ESTBeaconController : NSObject <ESTBeaconManagerDelegate, ESTBeaconDelegate>

-(id) initWithProximityList:(NSSet*) proximityUuidList;

@property (nonatomic, assign) id <ESTBeaconControllerDelegate> delegate;
@property(strong,nonatomic) NSMutableDictionary* detectedBeacons;
@property(nonatomic, strong) ESTBeaconManager* beaconManager;
@property(strong, nonatomic) NSMutableDictionary* monitoredRegions;
@property (nonatomic, retain) NSString * beaconInfo;
@property int desiredProximity;

-(void) scanAllBeacons;
-(void) stopBeacon;
-(void) readBeacon:(ESTBeacon*) beacon;
-(void) updateBeacon:(NSDictionary*) parameters;
-(void) disconnectBeacon;

-(void) readBeacon:(ESTBeacon*) beacon withCallback:(void (^) (NSDictionary* beaconInfo)) callbackBlock;
-(void) updateBeacon:(NSDictionary*) parameters withCallback:(void (^) (NSString* updateStatus)) callbackBlock;
-(void) disconnectBeacon:(void (^)(NSString* status)) callbackBlock;

@end
