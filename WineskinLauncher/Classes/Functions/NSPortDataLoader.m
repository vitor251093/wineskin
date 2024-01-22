//
//  NSPortDataLoader.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 07/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPortDataLoader.h"
#import <ObjectiveC_Extension/ObjectiveC_Extension.h>
#import "NSPathUtilities.h"
#import "WineskinLauncher_Prefix.pch"

@implementation NSPortDataLoader

+(NSString*)engineOfPortAtPath:(NSString*)path
{
    NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/SharedSupport/wine/version",path];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:wswineVersion])
    {
        return [[NSString stringWithContentsOfFile:wswineVersion encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\n"][0];
    }
    
    return nil;
}

+(BOOL)macDriverIsEnabledAtPort:(NSPortManager*)port
{
    NSString* driversVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Drivers]" fromRegistryFileNamed:USER_REG];
    if (driversVariable)
    {
        driversVariable = [NSPortManager getStringValueForKey:@"Graphics" fromRegistryString:driversVariable];
        return driversVariable && [driversVariable isEqualToString:@"mac,x11"];
    }
    else if (driversVariable)
    {
        driversVariable = [NSPortManager getStringValueForKey:@"Graphics" fromRegistryString:driversVariable];
        return driversVariable && [driversVariable isEqualToString:@"mac"];
    }
    
    return FALSE;
}

@end
