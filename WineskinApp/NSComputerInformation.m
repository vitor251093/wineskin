//
//  NSComputerInformation.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSComputerInformation.h"
#import "NSUtilities.h"
#import "VMMVersion.h"
#import "NSTask+Extension.h"
#import "NSArray+Extension.h"
#import "NSString+Extension.h"

#define STAFF_GROUP_MEMBER_CODE @"20"

@implementation NSComputerInformation

static NSString* _macOsVersion;

+(NSString*)macOsVersion
{
    @synchronized([self class])
    {
        if (_macOsVersion)
        {
            return _macOsVersion;
        }
        
        NSString* plistFile = @"/System/Library/CoreServices/SystemVersion.plist";
        NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:plistFile];
        NSString* version = systemVersionDictionary[@"ProductVersion"];
        
        if (!version)
        {
            _macOsVersion = [NSTask runProgram:@"sw_vers" atRunPath:nil withFlags:@[@"-productVersion"] wait:YES];
        }
        
        if (!version)
        {
            version = @"";
        }
        
        _macOsVersion = version;
        
        return _macOsVersion;
    }
    return nil;
}
+(BOOL)isSystemMacOsEqualOrSuperiorTo:(NSString*)version
{
    return [VMMVersion compareVersionString:version withVersionString:self.macOsVersion] != VMMVersionCompareFirstIsNewest;
}

+(BOOL)isUsingFnKeysFunctions
{
    NSString* appReturn = [NSTask runProgram:@"defaults" atRunPath:nil
                                   withFlags:@[@"read",@"-g",@"com.apple.keyboard.fnState",@"-bool"] wait:YES];
    return [appReturn boolValue];
}

+(BOOL)isComputerMacDriverCompatible
{
    // If the version is 10.7.5 or superior, it will work
    return [NSComputerInformation isSystemMacOsEqualOrSuperiorTo:@"10.7.5"];
}

@end

