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

@implementation NSPortDataLoader

+(NSString*)engineOfPortAtPath:(NSString*)path
{
    NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle/version",path];
    
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
        return driversVariable && [driversVariable isEqualToString:@"mac"];
    }
    
    return FALSE;
}

+(BOOL)useXQuartzIsEnabledAtPort:(NSPortManager*)port
{
    NSString* driversVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Drivers]" fromRegistryFileNamed:USER_REG];
    if (driversVariable)
    {
        driversVariable = [NSPortManager getStringValueForKey:@"Graphics" fromRegistryString:driversVariable];
        return driversVariable && [driversVariable isEqualToString:@"x11"];
    }
    
    return FALSE;
}

+(void)getValuesFromResolutionString:(NSString*)originalResolutionString
                             inBlock:(void (^)(BOOL virtualDesktop, NSString* resolution, int colors, int sleep))resolutionValues
{
    if (originalResolutionString.length < 12)
    {
        resolutionValues(NO, nil, 24, 0);
        return;
    }
    
    NSString* resolutionString = originalResolutionString;
    
    NSRange sleepRange = [resolutionString rangeOfString:@"sleep"];
    if (sleepRange.location == NSNotFound)
    {
        resolutionValues(NO, nil, 24, 0);
        return;
    }
    
    NSUInteger sleepLocation = sleepRange.location + sleepRange.length;
    NSUInteger sleepLength = resolutionString.length - sleepLocation;
    int sleep = [[resolutionString substringWithRange:NSMakeRange(sleepLocation, sleepLength)] intValue];
    
    NSRange xInEndOfResolution = [resolutionString rangeOfString:@"x" options:NSBackwardsSearch];
    if (xInEndOfResolution.location == NSNotFound)
    {
        resolutionValues(NO, nil, 24, sleep);
        return;
    }
    
    NSUInteger colorsLocation = xInEndOfResolution.location + xInEndOfResolution.length;
    NSUInteger colorsLength = sleepRange.location - colorsLocation;
    if (colorsLocation + colorsLength > resolutionString.length)
    {
        resolutionValues(NO, nil, 24, sleep);
        return;
    }
    
    int colors = [[resolutionString substringWithRange:NSMakeRange(colorsLocation, colorsLength)] intValue];
    
    
    BOOL virtualDesktop = false;
    NSString* resolution = nil;
    
    if ([resolutionString hasPrefix:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP] == false)
    {
        virtualDesktop = true;
        
        NSUInteger resolutionLength = xInEndOfResolution.location;
        resolution = [resolutionString substringWithRange:NSMakeRange(0, resolutionLength)];
    }
    
    resolutionValues(virtualDesktop, resolution, colors, sleep);
}

@end
