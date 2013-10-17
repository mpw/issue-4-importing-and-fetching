//
//  StopTimes.h
//  TrafficDataCommandLineImporter
//
//  Created by Marcel Weiher on 10/17/13.
//  Copyright (c) 2013 Marcel Weiher. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StopTimes : NSObject

-initWithLocalFiles;
-initWithData:(NSData*)newData;
-(void)sort;
-(void)exportOn:(FILE*)outfile;
-stopIndexesAtHour:(int)hour minute:(int)minute;
-(BOOL)isStopIndex:(int)anIndex betweenHour:(int)hStart minute:(int)mStart andHour:(int)hStop minute:(int)mStop;


@end
