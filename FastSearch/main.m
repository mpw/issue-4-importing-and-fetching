
#import <Foundation/Foundation.h>
#import <MPWFoundation/MPWFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MPWFoundation/MPWDelimitedTable.h>
#import "StopList.h"




int main( int argc, char *argv[] ) {
  NSLog(@"start");
  NSData *stopsData=[NSData dataWithContentsOfFile:@"stops.txt"];
  NSData *timesData=[NSData dataWithContentsOfMappedFile:@"times.bin"];
  NSLog(@"timesData size: %ld",(long)[timesData length]);
  StopList *stops=[[StopList alloc] initWithStopData:stopsData timesData:timesData];
  CLLocation *searchLoc=[[[CLLocation alloc] initWithLatitude:52.521 longitude:13.162] autorelease];
  int closeCount=0;
  NSLog(@"inited, start search");
//    [[stops stopTimes] log];
  for (int i=0;i<1000000;i++) {
    closeCount+=[[stops stopsWithinMeters:1000 ofLocation:searchLoc andMinutes:20 ofHour:16 minute:20] count];
//    closeCount+=[[stops stopsWithinMeters:1000 ofLocation:searchLoc] count];
  } 
  NSLog(@"%d close",closeCount);
}

