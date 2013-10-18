//
//  BusStop.m
//  TrafficSearch
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 objc.io. All rights reserved.
//

#import "BusStop.h"
#import <CoreLocation/CoreLocation.h>

@implementation BusStop

objectAccessor( CLLocation, location, setLocation)
objectAccessor( NSString, stationID, setStationID )

-initWithLatitude:(float)lat longitude:(float)longitude name:(NSString*)newName
{
    self=[super init];
    [self setLocation:AUTORELEASE([[CLLocation alloc] initWithLatitude:lat longitude:longitude] )];
    [self setStationID:newName];
    return self;
}

-(BOOL)isWithinDistance:(float)dist ofLocation:(CLLocation*)loc
{
    return [location distanceFromLocation:loc] < dist;
}

-(BOOL)isWithinDeltaLat:(float)deltaLatitude deltaLong:(float)deltaLongitude ofLocation:(CLLocation*)loc
{
    CLLocationCoordinate2D target=[loc coordinate];
    CLLocationCoordinate2D me=[location coordinate];
    
    return fabs( target.latitude - me.latitude ) < deltaLatitude &&
    fabs( target.longitude - me.longitude ) < deltaLongitude;
}

-(float)latitude {  return [location coordinate].latitude; }
-(float)longitude {  return [location coordinate].longitude; }

-description { return [NSString stringWithFormat:@"<Stop: %@ at %@>",stationID,location]; }

@end
