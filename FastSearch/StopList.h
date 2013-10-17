//
//  StopList.h
//  TrafficSearch
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 objc.io. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef struct {
    float coord;
    int   index;
} CoordIndex;

@class  StopTimes,CLLocation;

@interface StopList : NSObject
{
    NSArray *stops;
    CoordIndex *latIndex;
    //  CoordIndex *longIndex;
    NSData *stopTimesData;
    StopTimes *stopTimes;
}

-initWithStopData:(NSData*)stopsData timesData:(NSData*)timesData;
-stopsWithinMeters:(float)meters ofLocation:(CLLocation*)loc andMinutes:(int)deltaMinutes ofHour:(int)hour minute:(int)minute;

@end

