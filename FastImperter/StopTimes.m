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

typedef struct {
    unsigned int   stopIndex:20;
    unsigned int   hour:5,minute:6;
} StopTime;


typedef struct {
    int bucketOffsets[32][60];
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


-initWithLocalFiles
{
    self=[super init];
    NSData *stopsData=[NSData dataWithContentsOfFile:@"stops.txt"];
    NSData *timesCSVData=[NSData dataWithContentsOfMappedFile:@"stop_times.txt"];
    NSLog(@"stopsData length: %ld timesData length: %ld",(long)[stopsData length], (long)[timesCSVData length]);
    MPWDelimitedTable *stopsTable=[[[MPWDelimitedTable alloc] initWithCommaSeparatedData:stopsData] autorelease];
    MPWDelimitedTable *timeTable=[[[MPWDelimitedTable alloc] initWithCommaSeparatedData:timesCSVData] autorelease];
    NSArray *stopNames=[stopsTable parcollect_doesntwork:^id ( NSDictionary *d ){
        return @([[d objectForKey:@"stop_id"] intValue]);
    }];
    [self setCount:[timeTable count]];
    [self setTimesData:[NSMutableData dataWithLength:sizeof(AllTimes)+count*sizeof(StopTime)]];
//    StopTime *unsorted=calloc( [timeTable count]+20, sizeof(StopTime));
    
    NSMutableDictionary *stopToNumber=[NSMutableDictionary dictionary];
    for ( int i=0,max=(int)[stopNames count];i<max;i++) {
        [stopToNumber setObject:@(i) forKey:[stopNames objectAtIndex:i]];
    }
    __block int written=0;
    NSLog(@"extract");
    [timeTable do:^( NSDictionary *d, int i ){
        StopTime time;
        int h=0,m=0;
        //     char buffer[30];
        NSString *arrival=[d objectForKey:@"arrival_time"];
        if ( [arrival length]==8 ) {
            const char *buffer=[(NSData*)arrival bytes];
            //       [times getBytes:(void *)buffer maxLength:10 usedLength:NULL encoding:NSASCIIStringEncoding options:0 range:NSMakeRange(0,8) remainingRange:NULL];
            //       buffer[8]=0;
            h=(buffer[0]-'0') * 10  + buffer[1]-'0';
            m=(buffer[3]-'0') * 10  + buffer[4]-'0';
            time.hour=h;
            time.minute=m;
            time.stopIndex=[[stopToNumber objectForKey:@([[d objectForKey:@"stop_id"] intValue])] intValue];
            times->times[written++]=time;
        }
    }];
    [self setCount:written];
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
    int bucketSizes[32][60];
    int bucketOffsets[32][60];
    bzero( bucketSizes, sizeof bucketSizes );
    bzero( bucketOffsets, sizeof bucketOffsets );
    for (int i=0;i<count;i++) {
        StopTime current=times->times[i];
        if ( current.hour >= 31 || current.minute >= 60 ) {
            NSLog(@"invalid: %d %d",current.hour,current.minute);
        } else {
            bucketSizes[current.hour][current.minute]++;
        }
    }
    int currentOffset=0;
    for (int h=0;h<30;h++) {
        for (int m=0;m<60;m++) {
            bucketOffsets[h][m]=currentOffset;
            currentOffset+=bucketSizes[h][m];
        }
    }
    memcpy(times->bucketOffsets, bucketOffsets, sizeof times->bucketOffsets );
    for (int i=0;i<count;i++) {
        StopTime current=times->times[i];
        sorted[bucketOffsets[current.hour][current.minute]]=current;
        bucketOffsets[current.hour][current.minute]++;
    }
    //--- sort the individual buckets by stop index
    for (int h=0;h<29;h++) {
        for (int m=0;m<60;m++) {
            int offset=bucketOffsets[h][m];
            int numElements=bucketOffsets[h][m+1]-offset;
            qsort_b(sorted+offset, numElements, sizeof(StopTime), ^int(const void *va , const void *vb ) {
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
            int offset=times->bucketOffsets[h][m];
            int next=times->bucketOffsets[h][m+1];
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
    fwrite( times->bucketOffsets, 1, sizeof times->bucketOffsets, outfile );
    fwrite( times->times, count, sizeof times->times[0], outfile );
}


-stopIndexesAtHour:(int)hour minute:(int)minute
{
    NSMutableIndexSet *stopIndexes=[NSMutableIndexSet indexSet];
    int startTimeIndex=times->bucketOffsets[hour][minute];
    int stopTimeIndex=times->bucketOffsets[hour][minute+1];
#if 0
    for (int h=0;h<24;h++) {
        for (int m=0;m<60;m++) {
            NSLog(@"%02d:%02d = %d",h,m,times->bucketOffsets[h][m]);
        }
    }
#endif
    for (int i=startTimeIndex; i<stopTimeIndex; i++) {
        [stopIndexes addIndex:times->times[i].stopIndex];
    }
    return stopIndexes;
}

-(BOOL)isStopIndex:(int)anIndex betweenHour:(int)hStart minute:(int)mStart andHour:(int)hStop minute:(int)mStop
{
    int startTimeIndex=times->bucketOffsets[hStart][mStart];
    int stopTimeIndex=times->bucketOffsets[hStop][mStop];
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