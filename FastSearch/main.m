
#import <Foundation/Foundation.h>
#import <MPWFoundation/MPWFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MPWFoundation/MPWDelimitedTable.h>

@interface BusStop : MPWObject
{
  CLLocation *location;
  NSString   *stationID;
}

@end

@implementation BusStop

objectAccessor( CLLocation, location, setLocation)
objectAccessor( NSString, stationID, setStationID )

-initWithLatitude:(float)lat longitude:(float)longitude name:(NSString*)newName
{
  self=[super init];
  [self setLocation:[[[CLLocation alloc] initWithLatitude:lat longitude:longitude] autorelease]];
  [self setStationID:newName];
  return self;
}

-(BOOL)isWithinDistance:(float)dist ofLocation:(CLLocation*)loc
{
  return [location distanceFromLocation:loc] < dist;
}

-(BOOL)isWithinDeltaLat:(float)deltaLatitude deltaLong:(float)deltaLongitude ofLocation:(CLLocation*)loc
{
  CLLocationCoordinate2D target=[loc coordinate];
  CLLocationCoordinate2D me=[location coordinate];

  return fabs( target.latitude - me.latitude ) < deltaLatitude &&
         fabs( target.longitude - me.longitude ) < deltaLongitude;
}

-(float)latitude {  return [location coordinate].latitude; }
-(float)longitude {  return [location coordinate].longitude; }

-description { return [NSString stringWithFormat:@"<Stop: %@ at %@>",stationID,location]; } 

@end

typedef struct {
  float coord;
  int   index;
} CoordIndex;

typedef struct {
    unsigned int   stopIndex:20;
    unsigned int   hour:5,minute:6;
} StopTime;



typedef struct {
  int bucketOffsets[32][60];
  StopTime times[];
} AllTimes;


@interface StopList : NSObject 
{
  NSArray *stops;
  CoordIndex *latIndex;
//  CoordIndex *longIndex;
  NSData *stopTimesData;
  AllTimes *stopTimes;
}

@end



@implementation StopList

objectAccessor( NSArray, stops, setStops )
objectAccessor( NSData, stopTimesData, _setStopTimesData )

-(void)createIndexes
{
  int count=[stops count];
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

-(void)setStopTimesData:(NSData*)newData
{
  [self _setStopTimesData:newData];
  stopTimes = (AllTimes*)[newData bytes];
#if 0
  for (int h=0;h<24;h++) {
    for (int m=0;m<60;m++) {
      NSLog(@"%02d:%02d = %d",h,m,stopTimes->bucketOffsets[h][m]);
    }
  }
#endif
}

-initWithStops:(NSArray*)newStops timesData:(NSData*)timesData
{
  self=[super init];
  [self setStops:newStops];
  [self setStopTimesData:timesData];
  [self createIndexes];
  return self;
}

-(int)bsearchForClosestCoord:(float)target inTable:(CoordIndex*)anIndex 
{
    int min=0;
    int max=[stops count];
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
  for (int i=0,max=[stops count];i<max;i++) {
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
  NSArray *stopObjects=[stopsTable parcollect_doesntwork:^id ( NSDictionary *d ){
               return [[[BusStop alloc] initWithLatitude:[[d objectForKey:@"stop_lat"] floatValue]
                                                longitude:[[d objectForKey:@"stop_lon"] floatValue]
                                                name:[[d objectForKey:@"stop_id"] stringValue]] autorelease];
  }];
  return [self initWithStops:stopObjects timesData:timesData];
}

-stopsAtHour:(int)hour minute:(int)minute
{
  NSMutableIndexSet *stopIndexes=[NSMutableIndexSet indexSet];
  int startTimeIndex=stopTimes->bucketOffsets[hour][minute];
  int stopTimeIndex=stopTimes->bucketOffsets[hour][minute+1];
#if 0
  for (int h=0;h<24;h++) {
    for (int m=0;m<60;m++) {
      NSLog(@"%02d:%02d = %d",h,m,stopTimes->bucketOffsets[h][m]);
    }
  }
#endif
  for (int i=startTimeIndex; i<stopTimeIndex; i++) {
    [stopIndexes addIndex:stopTimes->times[i].stopIndex];
  }
  NSMutableArray *foundStops=[NSMutableArray array];
  [stopIndexes enumerateIndexesWithOptions:0 usingBlock:^(NSUInteger idx, BOOL *stop){ 
                     [foundStops addObject:[stops objectAtIndex:idx]];
  }];
  return foundStops;
}

-(BOOL)isStopIndex:(int)anIndex betweenHour:(int)hStart minute:(int)mStart andHour:(int)hStop minute:(int)mStop
{
  int startTimeIndex=stopTimes->bucketOffsets[hStart][mStart];
  int stopTimeIndex=stopTimes->bucketOffsets[hStop][mStop];
  for (int i=startTimeIndex; i<stopTimeIndex; i++) {
    if ( stopTimes->times[i].stopIndex == anIndex ) {
      return YES;
    }
  }
  return NO; 
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
        if ( [cur isWithinDistance:meters ofLocation:loc]  ) {
            if ( notDoingTime || [self isStopIndex:latIndex[i].index betweenHour:hour minute:minute-deltaMinutes andHour:hour minute:minute+deltaMinutes] ) {
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



int main( int argc, char *argv[] ) {
  NSLog(@"start");
  NSData *stopsData=[NSData dataWithContentsOfFile:@"stops.txt"];
  NSData *timesData=[NSData dataWithContentsOfMappedFile:@"times.bin"];
  NSLog(@"timesData size: %ld",(long)[timesData length]);
  StopList *stops=[[StopList alloc] initWithStopData:stopsData timesData:timesData];
  CLLocation *searchLoc=[[[CLLocation alloc] initWithLatitude:52.521 longitude:13.162] autorelease];
  int closeCount=0;
  NSLog(@"inited, start search");
  for (int i=0;i<100000;i++) {
    closeCount+=[[stops stopsWithinMeters:1000 ofLocation:searchLoc andMinutes:20 ofHour:16 minute:20] count];
//    closeCount+=[[stops stopsWithinMeters:1000 ofLocation:searchLoc] count];
  } 
  NSLog(@"%d close",closeCount);
}

