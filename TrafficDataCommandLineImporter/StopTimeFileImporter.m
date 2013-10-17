//
// Created by Florian on 17.08.13.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "StopTimeFileImporter.h"
#import "StopTime.h"
#import "NSDate+Import.h"
#import "Stop.h"


@interface StopTimeFileImporter ()
@end



@implementation StopTimeFileImporter

- (NSString *)entityName
{
    return @"StopTime";
}

-(void)fromLine:(NSString*)line getArrival:(NSDate**)arrival departure:(NSDate**)departure stopId:(NSInteger*)stopId
{
    NSArray *fields = [line componentsSeparatedByString:@","];
    *arrival = [NSDate dateWithTimeString:fields[1]];
    *departure = [NSDate dateWithTimeString:fields[2]];
    *stopId =[fields[3] integerValue];
}

- (void)configureObject:(NSManagedObject *)object forLine:(NSString *)line
{
    StopTime *stopTime = (StopTime *) object;
    NSDate *arrival=nil;
    NSDate *departure=nil;
    NSInteger stopId=0;
    [self fromLine:line getArrival:&arrival departure:&departure stopId:&stopId];
    

    stopTime.arrivalTime = arrival;
    stopTime.departureTime = departure;
    
    NSInteger stopIdentifier = stopId;
    NSManagedObjectID *moid = self.stopIdentifierToObjectID[@(stopIdentifier)];
    if (moid != nil) {
        Stop *stop = (id) [self.managedObjectContext objectWithID:moid];
        stopTime.stop = stop;
    }
}

@end
