#import <Foundation/Foundation.h>

#import "StopTimes.h"

int main( int argc, char *argv[] ) {
  NSLog(@"start");
//  FILE *outfile=stdout;
  FILE *outfile=fopen("times.bin", "w");
    StopTimes *times=[[[StopTimes alloc] initWithLocalFiles] autorelease];
    NSLog(@"done reading");
    [times sort];
    NSLog(@"done sorting");
//    [times log];
    [times exportOn:outfile];
    NSLog(@"done writing");
  return 0;
}
