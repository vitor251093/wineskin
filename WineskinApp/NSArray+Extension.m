//
//  NSArray+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 15/05/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSArray+Extension.h"

@implementation NSArray (PKArray)

-(NSArray*)sortedDictionariesArrayWithKey:(NSString *)key orderingByValuesOrder:(NSArray*)value
{
    return [self sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* obj1, NSDictionary* obj2)
    {
        NSUInteger obj1ValueIndex = [value indexOfObject:obj1[key]];
        NSUInteger obj2ValueIndex = [value indexOfObject:obj2[key]];
        
        if (obj1ValueIndex > obj2ValueIndex) return NSOrderedDescending;
        if (obj1ValueIndex < obj2ValueIndex) return NSOrderedAscending;
        return NSOrderedSame;
    }];
}

@end
