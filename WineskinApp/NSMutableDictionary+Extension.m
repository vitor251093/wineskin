//
//  NSExtensions.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/07/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import "NSMutableDictionary+Extension.h"

@implementation NSMutableDictionary (PKMutableDictionary)

+(instancetype)mutableDictionaryWithContentsOfFile:(NSString*)filePath
{
    NSMutableDictionary *dictionary;
    
    @try
    {
        dictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    }
    @catch (NSException *exception)
    {
        return nil;
    }
    
    return dictionary;
}

@end

