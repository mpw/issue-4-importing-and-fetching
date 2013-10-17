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
    //  longIndex=malloc(sizeof  *longIndex * count );
    for (int i=0;i<count; i++ ) {
        BusStop *s=[stops objectAtIndex:i];
        latIndex[i].coord=[s latitude];
        latIndex[i].index=i;
        //    longIndex[i].coord=[s longitude];
        //    longIndex[i].index=i;
    }
#if 1
    qsort_b(latIndex, count , sizeof *latIndex, ^(const void *a, const void *b){
        float diff = ((CoordIndex*)b)->coord - ((CoordIndex*)a)->coord;
        return diff <0 ? 1 : diff > 0 ? -1 :0;
    });
    //  qsort_b(longIndex, count , sizeof *longIndex, ^(const void *a, const void *b){
    //     float diff = ((CoordIndex*)b)->coord - ((CoordIndex*)a)->coord;
    //     return diff <0 ? 1 : diff > 0 ? -1 :0;
    //  });
#endif
}


-initWithStops:(NSArray*)newStops timesData:(NSData*)timesData
{
    self=[super init];
    [self setStops:newStops];
    [self setStopTimes:[[[StopTimes alloc] initWithData:timesData] autorelease]];
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

-(NSMutableIndexSet*)indexesWithin_linear:(float)delta ofBase:(float)base usingIndex:(CoordIndex*)anIndex
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


-(NSMutableIndexSet*)indexesWithin:(float)delta ofBase:(float)base usingIndex:(CoordIndex*)anIndex
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
    MPWDelimitedTable *stopsTable=[[[MPWDelimitedTable alloc] initWithCommaSeparatedData:stopsData] autorelease];
    NSArray *stopObjects=[stopsTable parcollect:^id ( NSDictionary *d ){
        return [[[BusStop alloc] initWithLatitude:[[d objectForKey:@"stop_lat"] floatValue]
                                        longitude:[[d objectForKey:@"stop_lon"] floatValue]
                                             name:[[d objectForKey:@"stop_id"] stringValue]] autorelease];
    }];
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
#if 0
    for ( BusStop* cur in stops ) {
        if ( [cur isWithinDeltaLat:deltaLatitude deltaLong:deltaLongitude ofLocation:loc] ) {
            if ( [cur isWithinDistance:meters ofLocation:loc] ) {
                [matching addObject:cur];
            }
        }
    }
#elif 0
    NSMutableIndexSet *latMatches=[self indexesWithin:deltaLatitude ofBase:loc.coordinate.latitude usingIndex:latIndex];
    //    NSMutableIndexSet *longMatches=[self indexesWithin:deltaLongitude ofBase:loc.coordinate.longitude usingIndex:longIndex];
    NSMutableIndexSet *finalSet = [[[NSMutableIndexSet alloc] init] autorelease];
    //    NSLog(@"latMatches: %@",latMatches);
    //    NSLog(@"long: %@",longMatches);
    
    [latMatches enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        if ([longMatches containsIndex:index]) [finalSet addIndex:index];
    }];
    
    
    [finalSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        BusStop* cur=[stops objectAtIndex:index];
        if ( [cur isWithinDistance:meters ofLocation:loc] ) {
            [matching addObject:cur];
        }
    } ];
#else
    int minIndex=[self bsearchForClosestCoord:loc.coordinate.latitude-deltaLatitude inTable:latIndex];
    int maxIndex=[self bsearchForClosestCoord:loc.coordinate.latitude+deltaLatitude inTable:latIndex];
    for (int i=minIndex;i<maxIndex;i++) {
        BusStop *cur=[stops objectAtIndex:latIndex[i].index];
        if ( [cur isWithinDeltaLat:deltaLatitude deltaLong:deltaLongitude ofLocation:loc] ) {
            if ( notDoingTime || [stopTimes isStopIndex:latIndex[i].index betweenHour:hour minute:minute-deltaMinutes andHour:hour minute:minute+deltaMinutes] ) {
                if ( [cur isWithinDistance:meters ofLocation:loc]  ) {
                    [matching addObject:cur];
                }
            }
        }
        
    }
#endif
    
    return matching;
}

-stopsWithinMeters:(float)meters ofLocation:(CLLocation*)loc
{
    return [self stopsWithinMeters:meters ofLocation:loc andMinutes:-1 ofHour:-1 minute:-1];
}

@end

