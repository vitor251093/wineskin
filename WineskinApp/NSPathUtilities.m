//
//  NSPathUtilities.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPathUtilities.h"

#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

@implementation NSPathUtilities

+(NSString*)wineskinAppBinaryForPortAtPath:(NSString*)path
{
    // Used to run the Wineskin App which resides inside Wineskin wrappers
    return [path stringByAppendingString:@"/Wineskin.app/Contents/MacOS/Wineskin"];
}
+(NSString*)wineskinLauncherBinForPortAtPath:(NSString*)path
{
    // Used to execute Wineskin instructions, like WSS-wineboot
    return [path stringByAppendingString:@"/Contents/MacOS/WineskinLauncher"];
}

+(NSString*)getMacPathForWindowsDrive:(char)driveLetter ofWrapper:(NSString*)file
{
    NSString* resourcesFolder = [NSString stringWithFormat:@"%@/Contents/Resources/",file];
    NSString* cxResourcesFolder = [NSString stringWithFormat:@"%@/Contents/SharedSupport/CrossOverGames/support/default/",file];
    if ([[NSFileManager defaultManager] directoryExistsAtPath:cxResourcesFolder]) resourcesFolder = cxResourcesFolder;
    
    NSString* drivePath = [NSString stringWithFormat:@"%@dosdevices/%c:",resourcesFolder,tolower(driveLetter)];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:drivePath]) return nil;
    
    NSString* path = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:drivePath];
    if ([path hasPrefix:@"../"]) path = [NSString stringWithFormat:@"%@%@",resourcesFolder,[path substringFromIndex:3]];
    if ([path hasSuffix:@"/"] == false) path = [path stringByAppendingString:@"/"];
    
    return path;
}
+(NSString*)getMacPathForWindowsPath:(NSString*)exePath ofWrapper:(NSString*)file
{
    if (exePath.length < 2) return nil;
    
    exePath = [exePath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    
    // Let's save time... if it starts with Z:, then it's your Mac root directory
    if ([exePath hasPrefix:@"Z:"]) return [exePath substringFromIndex:2];
    
    NSString* path = [self getMacPathForWindowsDrive:[exePath characterAtIndex:0] ofWrapper:file];
    
    return [[NSString stringWithFormat:@"%@%@",path,[exePath substringFromIndex:2]]
            stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
}
+(NSString*)getWindowsPathForMacPath:(NSString*)exePath ofWrapper:(NSString*)file
{
    for (char x = 'C'; x <= 'Z'; x++)
    {
        NSString* driveRoot = [NSString stringWithFormat:@"%c:/",x];
        
        if (file)
        {
            NSString* path = [self getMacPathForWindowsDrive:x ofWrapper:file];
            if (path && [exePath hasPrefix:path])
            {
                return [driveRoot stringByAppendingString:[exePath substringFromIndex:path.length]];
            }
        }
        else
        {
            NSString* driveRootMac = [NSString stringWithFormat:@"drive_%c/",tolower(x)];
            NSString* path = [exePath getFragmentAfter:driveRootMac andBefore:nil];
            
            if (path) return [driveRoot stringByAppendingString:path];
        }
    }
    
    return [NSString stringWithFormat:@"Z:%@",exePath];
}

+(NSString*)getFileNameOfWindowsPath:(NSString*)exePath
{
    exePath = [exePath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    
    // Just to avoid problems with empty string before the first '"'
    while ([exePath hasPrefix:@" "]) exePath = [exePath substringFromIndex:1];
    
    // If it doesn't start with '"', then it isn't a regular path
    if (![exePath hasPrefix:@"\""])
    {
        // If it doesn't have a size bigger than 2, then it isn't even a valid path
        if (exePath.length > 2)
        {
            // Well, if it has a ':' then the path might be correct; we should give it a chance; otherwise, last check
            if (![exePath contains:@":"])
            {
                // If it starts with '/', then the user might have used a Mac path; that should solve the problem
                if ([exePath hasPrefix:@"/"]) return [NSString stringWithFormat:@"Z:%@",exePath];
                
                // Otherwise, that path might be batch commands; give it back like it is
                return exePath;
            }
        }
        else return @"";
    }
    
    // Considering that it start with ", that should work; first, split it with "
    NSArray* array = [exePath componentsSeparatedByString:@"\""];
    
    // If it has 3 " or more, everything is according to the expected
    // If the block before the first " is empty, it returns the second block; otherwise, the first
    // That will avoid problems if the user removes the first " by mistake
    if (array.count>=3) return ([array[0] isEqualToString:@""]) ? array[1] : array[0];
    
    // If it has only 2, then something is obviously wrong
    // If the first part is bigger than 0, probably the first " was skipped
    // Otherwise, the best option is obviously the second
    if (array.count==2) return ([array[0] length] > 0) ? array[0] : array[1];
    
    // If it has only one... well, then it doesn't have " at all
    // Just return the only item of the array
    if (array.count==1) return array[0];
    
    // Oh, that? That's just in case something unexpected happen like an empty array
    // The fact is: that function ALWAYS have to return something, even an empty string
    return @"";
}
+(NSString*)getFlagsOfWindowsPath:(NSString*)exePath
{
    // Just to avoid problems with empty string before the first '"'
    while ([exePath hasPrefix:@" "]) exePath = [exePath substringFromIndex:1];
    
    // If it doesn't start with '"', then it isn't a regular path
    if (![exePath hasPrefix:@"\""])
    {
        // If it doesn't have a size bigger than 2, then it isn't even a valid string
        if (exePath.length>2)
        {
            // Well, if it has a ':' then the path might be correct; we should give it a chance; otherwise, last check
            if (![exePath contains:@":"])
            {
                // If it starts with '/', then the user have used a Wineskin path; so no flags
                // Otherwise, that path might be batch commands; since we returned everything has the path, here we return nothing
                return @"";
            }
        }
        else return @"";
    }
    
    // Considering that it start with ", that should work; first, split it with "
    NSString* result = @"";
    NSMutableArray* array = [[exePath componentsSeparatedByString:@"\""] mutableCopy];
    
    // If it has 3 " or more, everything is according to the expected
    if (array.count >= 3)
    {
        // If the block before the first " is empty, it removes the first block
        if ([array[0] isEqualToString:@""])
        {
            [array removeObjectAtIndex:0];
        }
        
        // Otherwise, the user might have removed the first " by mistake; in that case, we should skip that step
        [array removeObjectAtIndex:0];
        
        // Flags have " too (paths don't), then we have to join everything else with them to recover the original flags
        result = [array componentsJoinedByString:@"\""];
    }
    
    // If it has only 2, then something is obviously wrong
    // If the first part is bigger than 0, probably the first " was skipped and the flags are the second part
    // Otherwise, we will consider that there are no flags
    else if (array.count==2) return ([array[0] length] > 0) ? array[1] : @"";
    
    // Just to improve the flag quality, removing spaces from the beggining
    while ([result hasPrefix:@" "]) result = [result substringFromIndex:1];
    
    // Now, just return the flags
    return result;
}

+(BOOL)isPath:(NSString*)path compatibleWithStruct:(NSString*)structure
{
    if (![structure isEqualToString:@""])
    {
        if ([structure contains:WINDOWS_PATH_PROGRAM_FILES_PLACEHOLDER])
        {
            structure = [structure stringByReplacingOccurrencesOfString:WINDOWS_PATH_PROGRAM_FILES_PLACEHOLDER withString:@"C:/*"];
        }
        
        NSArray* parts = [structure.lowercaseString componentsSeparatedByString:@"*"];
        path = path.lowercaseString;
        
        if (parts.count <  1) return TRUE;
        if (parts.count == 1) return [path isEqualToString:parts[0]];
        if (parts.count == 2)
        {
            BOOL hasPrefix = [path hasPrefix:parts[0]] || [parts[0] isEqualToString:@""];
            BOOL hasSuffix = [path hasSuffix:parts[1]] || [parts[1] isEqualToString:@""];
            return hasPrefix && hasSuffix;
        }
        
        for (int index = 0; index < parts.count; index++)
        {
            NSString* part = parts[index];
            
            if (![part isEqualToString:@""])
            {
                while (index!=0 && path.length>0 && ![path hasPrefix:part])
                    path = [path substringFromIndex:1];
                
                if ([path hasPrefix:part]) path = [path substringFromIndex:part.length];
                else return FALSE;
            }
            else if (index == parts.count-1) return TRUE;
        }
        
        return path.length == 0;
    }
    
    return TRUE;
}
+(NSArray*)filesCompatibleWithStructure:(NSString*)appPath insideFolder:(NSString*)folder
{
    if (!folder) return @[];
    
    NSString* fullFolder = [folder hasSuffix:@"/"] ? folder : [folder stringByAppendingString:@"/"];
    NSMutableArray* pastas = [@[fullFolder] mutableCopy];
    if (![[NSFileManager defaultManager] directoryExistsAtPath:fullFolder]) return @[];
    
    if ([appPath contains:@"/"])
    {
        NSMutableArray* partsOfPath = [[appPath componentsSeparatedByString:@"/"] mutableCopy];
        appPath = [partsOfPath lastObject];
        [partsOfPath removeLastObject];
        
        pastas = [[self filesCompatibleWithStructure:[partsOfPath componentsJoinedByString:@"/"] insideFolder:fullFolder] mutableCopy];
        
        if (pastas.count == 0) return pastas;
    }
    
    NSMutableArray* finalFilePaths = [[NSMutableArray alloc] init];
    for (NSString* pasta in pastas)
    {
        if ([[NSFileManager defaultManager] directoryExistsAtPath:pasta])
        {
            NSArray* downloadFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pasta];
            
            for (NSString* downloadItem in downloadFolder)
            {
                if ([self isPath:downloadItem compatibleWithStruct:appPath])
                {
                    NSString* fullPasta = [pasta hasSuffix:@"/"] ? pasta : [pasta stringByAppendingString:@"/"];
                    [finalFilePaths addObject:[NSString stringWithFormat:@"%@%@",fullPasta,downloadItem]];
                }
            }
        }
    }
    
    return finalFilePaths;
}

@end
