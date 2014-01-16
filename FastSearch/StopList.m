//
//  StopList.m
//  TrafficSearch
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 objc.io. All rights reserved.
//

#import "StopList.h"
#import "BusStop.h"
#import <MPWFoundation/MPWFoundation.h>
#import <MPWFoundation/MPWDelimitedTable.h>
#import <CoreLocation/CoreLocation.h>
#import "StopTimes.h"

@implementation StopList

objectAccessor( NSArray, stops, setStops )
objectAccessor( NSData, stopTimesData, _setStopTimesData )
objectAccessor( StopTimes, stopTimes, setStopTimes)

-(void)createIndexes
{
    NSInteger count=[stops count];
    latIndex=malloc( sizeof *latIndex * count );
    for (int i=0;i<count; i++ ) {
        BusStop *s=[stops objectAtIndex:i];
        latIndex[i].coord=[s latitude];
        latIndex[i].index=i;
    }
#if 1
    qsort_b(latIndex, count , sizeof *latIndex, ^(const void *a, const void *b){
        float diff = ((CoordIndex*)b)->coord - ((CoordIndex*)a)->coord;
        return diff <0 ? 1 : diff > 0 ? -1 :0;
    });
#endif
}


-initWithStops:(NSArray*)newStops timesData:(NSData*)timesData
{
    self=[super init];
    [self setStops:newStops];
    [self setStopTimes:AUTORELEASE([[StopTimes alloc] initWithData:timesData])];
    [self createIndexes];
    return self;
}

-(int)bsearchForClosestCoord:(float)target inTable:(CoordIndex*)anIndex
{
    int min=0;
    int max=(int)[stops count];
    while ( max-min > 1 ) {
        int probe=(max+min)/2;
        float probeValue=anIndex[probe].coord ;
        //      NSLog(@"min=%d max=%d probe=%d (%g) target=%g",min,max,probe,probeValue,target);
        if ( target > probeValue ) {
            min=probe;
        } else {
            max=probe;
        }
    }
    return max;
}

-(NSMutableIndexSet*)indexesWithin:(float)delta ofBase:(float)base usingIndex:(CoordIndex*)anIndex
{
    NSMutableIndexSet *s=[NSMutableIndexSet indexSet];
    for (int i=0,max=(int)[stops count];i<max;i++) {
        float coord=anIndex[i].coord;
        if ( (coord > base-delta) && coord < base+delta ) {
            [s addIndex:anIndex[i].index];
        }
    }
    return s;
}


-(NSMutableIndexSet*)indexesWithin_binary:(float)delta ofBase:(float)base usingIndex:(CoordIndex*)anIndex
{
    int minIndex=[self bsearchForClosestCoord:base-delta inTable:anIndex];
    int maxIndex=[self bsearchForClosestCoord:base+delta inTable:anIndex];
    NSMutableIndexSet *s=[NSMutableIndexSet indexSet];
    for (int i=minIndex;i<maxIndex;i++) {
        [s addIndex:anIndex[i].index];
    }
    return s;
}


-initWithStopData:(NSData*)stopsData timesData:(NSData*)timesData
{
    NSLog(@"initWithStopData");
    MPWDelimitedTable *stopsTable=AUTORELEASE([[MPWDelimitedTable alloc] initWithCommaSeparatedData:stopsData]);
    [stopsTable setKeysOfInterest:@[@"stop_lat",@"stop_lon" ,@"stop_id" ]];
    NSArray *stopObjects=[stopsTable parcollect:^id ( NSDictionary *d ){
        return AUTORELEASE([[BusStop alloc] initWithLatitude:[[d objectForKey:@"stop_lat"] floatValue]
                                        longitude:[[d objectForKey:@"stop_lon"] floatValue]
                                                        name:[d objectForKey:@"stop_id"]]);
    }];
    NSLog(@"done initWithStopData");
    return [self initWithStops:stopObjects timesData:timesData];
}

-stopsAtHour:(int)hour minute:(int)minute
{
    NSIndexSet *stopIndexes=[stopTimes stopIndexesAtHour:hour minute:minute];
    NSMutableArray *foundStops=[NSMutableArray array];
    [stopIndexes enumerateIndexesWithOptions:0 usingBlock:^(NSUInteger idx, BOOL *stop){
        [foundStops addObject:[stops objectAtIndex:idx]];
    }];
    return foundStops;
}

-stopsWithinMeters:(float)meters ofLocation:(CLLocation*)loc andMinutes:(int)deltaMinutes ofHour:(int)hour minute:(int)minute
{
    double const D = meters * 1.1;
    double const R = 6371009.; // Earth readius in meters
    double meanLatitidue = loc.coordinate.latitude * M_PI / 180.;
    double deltaLatitude = fabs( D / R * 180. / M_PI);
    double deltaLongitude = fabs(D / (R * cos(meanLatitidue)) * 180. / M_PI);
    BOOL notDoingTime=hour < 0;
    
    NSMutableArray *matching=[NSMutableArray array];
    int minIndex=[self bsearchForClosestCoord:loc.coordinate.latitude-deltaLatitude inTable:latIndex];
    int maxIndex=[self bsearchForClosestCoord:loc.coordinate.latitude+deltaLatitude inTable:latIndex];
//    int minIndex=0;
//    int maxIndex=[stops count];
    
    for (int i=minIndex;i<maxIndex;i++) {
        BusStop *cur=[stops objectAtIndex:latIndex[i].index];
        if (  [cur isWithinDeltaLat:deltaLatitude deltaLong:deltaLongitude ofLocation:loc] ) {
            if ( [cur isWithinDistance:meters ofLocation:loc]  ) {
                if (minute-deltaMinutes < 0 && hour==0) {
                    minute=deltaMinutes;
                }
                if ( notDoingTime || [stopTimes isStopIndex:latIndex[i].index betweenHour:hour minute:minute-deltaMinutes andHour:hour minute:minute+deltaMinutes] ) {
                    [matching addObject:cur];
                }
            }
        }
        
    }
    
    return matching;
}

-stopsWithinMeters:(float)meters ofLocation:(CLLocation*)loc
{
    return [self stopsWithinMeters:meters ofLocation:loc andMinutes:-1 ofHour:-1 minute:-1];
}

@end

