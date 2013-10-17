//
//  BusStop.h
//  TrafficSearch
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 objc.io. All rights reserved.
//

#import <MPWFoundation/MPWFoundation.h>

@class CLLocation;

@interface BusStop : MPWObject
{
    CLLocation *location;
    NSString   *stationID;
}

-initWithLatitude:(float)lat longitude:(float)longitude name:(NSString*)newName;
-(float)latitude;
-(BOOL)isWithinDeltaLat:(float)deltaLatitude deltaLong:(float)deltaLongitude ofLocation:(CLLocation*)loc;
-(BOOL)isWithinDistance:(float)dist ofLocation:(CLLocation*)loc;

@end

