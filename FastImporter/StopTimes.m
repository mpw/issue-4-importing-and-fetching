//
//  StopTimes.m
//  TrafficDataCommandLineImporter
//
//  Created by Marcel Weiher on 10/17/13.

/*
 Copyright (c) 2013-2017 by Marcel Weiher.  All rights reserved.
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the distribution.
 
 Neither the name Marcel Weiher nor the names of contributors may
 be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 THE POSSIBILITY OF SUCH DAMAGE.
 
 */



#import "StopTimes.h"
#import <MPWFoundation/MPWFoundation.h>
#import <MPWFoundation/MPWDelimitedTable.h>
#import <MPWFoundation/MPWSmallStringTable.h>

typedef struct {
    unsigned int   stopIndex:20;
    unsigned int   hour:5,minute:6;
} StopTime;

typedef struct {          // index into a StopTimes array by [hour][minute]
    int      bytime[32][60];
} Buckets;

typedef struct {          //  Combine the StopTimes with index
    Buckets  bucketOffsets;
    StopTime times[];
} AllTimes;


@interface StopTimes() {
    NSInteger count;
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
    NSArray *stopNames=[stopsTable collect:^id ( NSDictionary *d ){
        return @([[(MPWSmallStringTable*)d objectForCString:"stop_id"] intValue]);
    }];
    [self setCount:[timeTable count]];
    [self setTimesData:[NSMutableData dataWithLength:sizeof(AllTimes)+count*sizeof(StopTime)]];
    
    NSMutableDictionary *stopToNumber=[NSMutableDictionary dictionary];
    for ( int i=0,max=(int)[stopNames count];i<max;i++) {
        [stopToNumber setObject:@(i) forKey:[stopNames objectAtIndex:i]];
    }
 
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
    
    //---   size each of the buckets
    
    for (int i=0;i<count;i++) {
        StopTime current=times->times[i];
        if ( current.hour >= 31 || current.minute >= 60 ) {
            NSLog(@"invalid: %d %d",current.hour,current.minute);
        } else {
            bucketSizes.bytime[current.hour][current.minute]++;
        }
    }
    
    //---   accumulate sizes into offsets
    
    int currentOffset=0;
    for (int h=0;h<30;h++) {
        for (int m=0;m<60;m++) {
            bucketOffsets.bytime[h][m]=currentOffset;
            currentOffset+=bucketSizes.bytime[h][m];
        }
    }
    
    //---   and copy those offsets into destination
    
    memcpy( &times->bucketOffsets, &bucketOffsets, sizeof times->bucketOffsets );
    
    //---   bucket-sort the stop times
    
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

    //--- copy into final structure
    
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
