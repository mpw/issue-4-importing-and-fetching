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

lazyAccessor( CLLocation, location, setLocation, createLocation)
objectAccessor( NSString, stationID, setStationID )

-createLocation
{
    return AUTORELEASE([[CLLocation alloc] initWithLatitude:latitude   longitude:longitude] );
}

-initWithLatitude:(float)lat longitude:(float)longit  name:(NSString*)newName
{
    self=[super init];
    latitude=lat;
    longitude=longit;
    [self setStationID:newName];
    return self;
}

-(BOOL)isWithinDistance:(float)dist ofLocation:(CLLocation*)loc
{
    return [[self createLocation] distanceFromLocation:loc] < dist;
}

-(BOOL)isWithinDeltaLat:(float)deltaLatitude deltaLong:(float)deltaLongitude ofLocation:(CLLocation*)loc
{
    CLLocationCoordinate2D target=[loc coordinate];
    
    return fabs( target.latitude - latitude ) < deltaLatitude &&
    fabs( target.longitude - longitude ) < deltaLongitude;
}

-(float)latitude {  return latitude; }
-(float)longitude {  return longitude; }

-description { return [NSString stringWithFormat:@"<Stop: %@ at %g,%g>",stationID,latitude,longitude]; }


@end
