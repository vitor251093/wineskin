//
//  NSMutableArray+Extension.m
//  Wineskin
//
//  Created by Vitor Marques de Miranda on 08/10/18.
//

#import "NSMutableArray+Extension.h"

@implementation NSMutableArray (PKMutableArray)

-(void)replaceObjectsWithVariation:(_Nullable id (^_Nonnull)(id _Nonnull object, NSUInteger index))newObjectForObject
{
    for (NSUInteger index = 0; index < self.count; index++)
    {
        id newObject = newObjectForObject([self objectAtIndex:index], index);
        [self replaceObjectAtIndex:index withObject:newObject ? newObject : [NSNull null]];
    }
}

@end
