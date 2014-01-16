//
//  StopTimes.m
//  TrafficDataCommandLineImporter
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 Marcel Weiher. All rights reserved.
//

#import "StopTimes.h"
#import <MPWFoundation/MPWFoundation.h>
#import <MPWFoundation/MPWDelimitedTable.h>
#import <MPWFoundation/MPWSmallStringTable.h>

typedef struct {
    unsigned int   stopIndex:20;
    unsigned int   hour:5,minute:6;
} StopTime;

typedef struct {
    int bytime[32][60];
} Buckets;

typedef struct {
    Buckets bucketOffsets;
    StopTime times[];
} AllTimes;


@interface StopTimes() {
    NSInteger      count;
    AllTimes *times;
    NSData   *timesData;
}



@end

@implementation StopTimes

objectAccessor(NSData, timesData, _setTimesData)
scalarAccessor(NSInteger, count, setCount)

-(void)setTimesData:(NSData*)newData
{
    [self _setTimesData:newData];
    times=(AllTimes*)[newData bytes];
}

static inline int twoDigitsAt( const char *buffer ) {
    return (buffer[0]-'0') * 10  + buffer[1]-'0';
}

-initWithLocalFiles
{
    self=[super init];
    NSData *stopsData=[NSData dataWithContentsOfMappedFile:@"stops.txt"];
    NSData *timesCSVData=[NSData dataWithContentsOfMappedFile:@"stop_times.txt"];
    MPWDelimitedTable *stopsTable=AUTORELEASE([[MPWDelimitedTable alloc] initWithCommaSeparatedData:stopsData]);
    MPWDelimitedTable *timeTable=AUTORELEASE([[MPWDelimitedTable alloc] initWithCommaSeparatedData:timesCSVData]);
    [stopsTable setKeysOfInterest:@[@"stop_id"]];
    NSArray *stopNames=[stopsTable parcollect:^id ( NSDictionary *d ){
        return @([[(MPWSmallStringTable*)d objectForCString:"stop_id"] intValue]);
    }];
    [self setCount:[timeTable count]];
    [self setTimesData:[NSMutableData dataWithLength:sizeof(AllTimes)+count*sizeof(StopTime)]];
    
    NSMutableDictionary *stopToNumber=[NSMutableDictionary dictionary];
    for ( int i=0,max=(int)[stopNames count];i<max;i++) {
        [stopToNumber setObject:@(i) forKey:[stopNames objectAtIndex:i]];
    }
//    NSLog(@"stopToNumber: %@",stopToNumber);
    StopTime *localTimes=times->times;
    NSLog(@"extract");
    [timeTable setKeysOfInterest:@[ @"arrival_time", @"stop_id"]];
    [timeTable do:^( NSDictionary *d1, int i ){
        MPWSmallStringTable *d=(MPWSmallStringTable*)d1;
        StopTime time;
        NSString *arrival=[d objectForCString:"arrival_time"];
        if ( [arrival length]==8 ) {
            const char *buffer=[(NSData*)arrival bytes];
            time.hour=twoDigitsAt(buffer);
            time.minute=twoDigitsAt(buffer+3);
            time.stopIndex=[[stopToNumber objectForKey:@([[d objectForCString:"stop_id"] intValue])] intValue];

            localTimes[i]=time;
        }
    }];
    return self;
}

-initWithData:(NSData*)newData
{
    self=[super init];
    [self setTimesData:newData];
    [self setCount:([newData length]-sizeof(times->bucketOffsets))/sizeof(StopTime)];
    return self;
}


-(void)sort
{
    StopTime *sorted=calloc( count+20, sizeof(StopTime));
    Buckets bucketSizes;
    Buckets bucketOffsets;
    bzero( &bucketSizes, sizeof bucketSizes );
    bzero( &bucketOffsets, sizeof bucketOffsets );
    for (int i=0;i<count;i++) {
        StopTime current=times->times[i];
        if ( current.hour >= 31 || current.minute >= 60 ) {
            NSLog(@"invalid: %d %d",current.hour,current.minute);
        } else {
            bucketSizes.bytime[current.hour][current.minute]++;
        }
    }
    int currentOffset=0;
    for (int h=0;h<30;h++) {
        for (int m=0;m<60;m++) {
            bucketOffsets.bytime[h][m]=currentOffset;
            currentOffset+=bucketSizes.bytime[h][m];
        }
    }
    memcpy( &times->bucketOffsets, &bucketOffsets, sizeof times->bucketOffsets );
    for (int i=0;i<count;i++) {
        StopTime current=times->times[i];
        sorted[bucketOffsets.bytime[current.hour][current.minute]]=current;
        bucketOffsets.bytime[current.hour][current.minute]++;
    }
    //--- sort the individual buckets by stop index
    for (int h=0;h<29;h++) {
        for (int m=0;m<60;m++) {
            int offset=bucketOffsets.bytime[h][m];
            int numElements=bucketOffsets.bytime[h][m+1]-offset;
            mergesort_b(sorted+offset, numElements, sizeof(StopTime), ^int(const void *va , const void *vb ) {
                StopTime *a=(StopTime*)va;
                StopTime *b=(StopTime*)vb;
                return a->stopIndex - b->stopIndex;
            });
        }
    }
    
    memcpy(times->times, sorted, count * sizeof(StopTime) );
}

-(void)log
{
    for (int h=0;h<29;h++) {
        for (int m=0;m<60;m++) {
            int offset=times->bucketOffsets.bytime[h][m];
            int next=times->bucketOffsets.bytime[h][m+1];
            for (int i=offset;i<next;i++) {
                StopTime s=times->times[i];
                fprintf(stderr, "stop[%02d][%02d][%04d]= %d, %02d:%02d\n",h,m,i,s.stopIndex,s.hour,s.minute);
            }
        }
    }
}

-(void)exportOn:(FILE*)outfile
{
//    NSLog(@"bucket offsets size: %lu",sizeof times->bucketOffsets);
    fwrite( &times->bucketOffsets, 1, sizeof times->bucketOffsets, outfile );
    fwrite( times->times, count, sizeof times->times[0], outfile );
}


-stopIndexesAtHour:(int)hour minute:(int)minute
{
    NSMutableIndexSet *stopIndexes=[NSMutableIndexSet indexSet];
    int startTimeIndex=times->bucketOffsets.bytime[hour][minute];
    int stopTimeIndex=times->bucketOffsets.bytime[hour][minute+1];
    for (int i=startTimeIndex; i<stopTimeIndex; i++) {
        [stopIndexes addIndex:times->times[i].stopIndex];
    }
    return stopIndexes;
}

-(BOOL)isStopIndex:(int)anIndex betweenHour:(int)hStart minute:(int)mStart andHour:(int)hStop minute:(int)mStop
{
    while ( mStart < 0) {
        mStart+=60;
        hStart--;
    }
    if ( hStart < 0) {
        hStart+=24;
    }
    int startTimeIndex=times->bucketOffsets.bytime[hStart][mStart];
    int stopTimeIndex=times->bucketOffsets.bytime[hStop][mStop];
#if 1
    StopTime targetStop;
    targetStop.stopIndex=anIndex;
    StopTime *found=bsearch_b( &targetStop, times->times+startTimeIndex, stopTimeIndex-startTimeIndex, sizeof targetStop, ^int(const void *vkey, const void *velem) {
        StopTime *key=(StopTime*)vkey;
        StopTime *elem=(StopTime*)velem;
        return key->stopIndex - elem->stopIndex;
    });
    return found != NULL;
#else
    for (int i=startTimeIndex; i<stopTimeIndex; i++) {
        if ( times->times[i].stopIndex == anIndex ) {
            return YES;
        }
    }
    return NO;
#endif
}





@end
