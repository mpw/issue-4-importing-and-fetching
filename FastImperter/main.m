#import <Foundation/Foundation.h>
#import <MPWFoundation/MPWFoundation.h>
#import <MPWFoundation/MPWDelimitedTable.h>

// @import MPWFoundation;



typedef struct {
    unsigned int   stopIndex:20;
    unsigned int   hour:5,minute:6;
} StopTime;



int main( int argc, char *argv[] ) {
    NSLog(@"start");
    NSData *stopsData=[NSData dataWithContentsOfFile:@"stops.txt"];
    NSData *timesData=[NSData dataWithContentsOfMappedFile:@"stop_times.txt"];
    MPWDelimitedTable *stopsTable=[[[MPWDelimitedTable alloc] initWithCommaSeparatedData:stopsData] autorelease];
    MPWDelimitedTable *timeTable=[[[MPWDelimitedTable alloc] initWithCommaSeparatedData:timesData] autorelease];
    NSArray *stopNames=[stopsTable parcollect_doesntwork:^id ( NSDictionary *d ){
        return @([[d objectForKey:@"stop_id"] intValue]);
    }];
    StopTime *unsorted=calloc( [timeTable count]+20, sizeof(StopTime));
    StopTime *sorted=calloc( [timeTable count]+20, sizeof(StopTime));
    int bucketSizes[32][60];
    int bucketOffsets[32][60];
    
    bzero( bucketSizes, sizeof bucketSizes );
    bzero( bucketOffsets, sizeof bucketOffsets );
    NSMutableDictionary *stopToNumber=[NSMutableDictionary dictionary];
    for ( int i=0,max=[stopNames count];i<max;i++) {
        [stopToNumber setObject:@(i) forKey:[stopNames objectAtIndex:i]];
    }
    __block int written=0;
    NSLog(@"extract");
    [timeTable do:^( NSDictionary *d, int i ){
        StopTime time;
        int h=0,m=0,s=0;
        char buffer[30];
        NSString *times=[d objectForKey:@"arrival_time"];
        if ( [times length]==8 ) {
            [times getBytes:(void *)buffer maxLength:10 usedLength:NULL encoding:NSASCIIStringEncoding options:0 range:NSMakeRange(0,8) remainingRange:NULL];
            buffer[8]=0;
            int numConverted=sscanf( buffer, "%d:%d:%d",&h,&m,&s);
            if ( numConverted == 3 ) {
                time.hour=h;
                time.minute=m;
                time.stopIndex=[[stopToNumber objectForKey:@([[d objectForKey:@"stop_id"] intValue])] intValue];
                unsorted[written++]=time;
            } else {
                NSLog(@"did not parse %@",times);
            }
        }
    }];
    if ( written > [timeTable count] ) {
        NSLog(@"written > timetable:  %d %d",written,[timeTable count]);
        written=[timeTable count];
    }
    NSLog(@"get bucket sizes");
    for (int i=0;i<written;i++) {
        StopTime current=unsorted[i];
        if ( current.hour >= 31 || current.minute >= 60 ) {
            NSLog(@"invalid: %d %d",current.hour,current.minute);
        } else {
            bucketSizes[current.hour][current.minute]++;
        }
    }
    int currentOffset=0;
    NSLog(@"get bucket offsets");
    for (int h=0;h<30;h++) {
        for (int m=0;m<60;m++) {
            bucketOffsets[h][m]=currentOffset;
            currentOffset+=bucketSizes[h][m];
        }
    }
    fwrite( bucketOffsets, 1, sizeof bucketOffsets, stdout );
    NSLog(@"bucket sort");
    for (int i=0;i<written;i++) {
        StopTime current=unsorted[i];
        sorted[bucketOffsets[current.hour][current.minute]]=current;
        bucketOffsets[current.hour][current.minute]++;
    }
    NSLog(@"check output");
#if 0
    for (int i=0;i<written;i++) {
        StopTime current=sorted[i];
        fprintf(stderr,"%2d:%2d  %d\n",current.hour,current.minute,[[stopNames objectAtIndex:current.stopIndex] intValue]);
    }
#elif 0
    for (int h=0;h<30;h++) {
        for (int m=0;m<60;m++) {
            if ( bucketSizes[h][m] ) {
                fprintf(stderr,"%02d:%02d: %d entries\n",h,m,bucketSizes[h][m]);
            }
        }
    }
    
#endif
    NSLog(@"will fwrite");
    fwrite( sorted, sizeof(StopTime),written, stdout);
    NSLog(@"did fwrite");
    return 0;
}

