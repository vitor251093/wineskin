//
//  NSPortDataLoader.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 07/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPortDataLoader.h"

#import "NSWineskinEngine.h"

#import "NSUtilities.h"
#import "NSPathUtilities.h"

#import "NSDropIconView.h"

#import "NSAlert+Extension.h"
#import "NSImage+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

@implementation NSPortDataLoader

+(NSString*)getPrimaryWineskinWrapperEngineAtPath:(NSString*)path
{
    NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle/version",path];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:wswineVersion])
    {
        return [[NSString stringWithContentsOfFile:wswineVersion encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\n"][0];
    }
    
    return nil;
}
+(NSString*)getWineskinWrapperEngineFromInfFileAtPath:(NSString*)wineInfPath
{
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:wineInfPath])
    {
        NSArray* frags = [[NSString stringWithContentsOfFile:wineInfPath encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\n"];
        if (frags.count > 1)
        {
            NSString* newWrapperEngine = frags[1];
            if ([newWrapperEngine contains:@"Wine"])
            {
                return [NSWineskinEngine mostRecentVersionOfEngine:newWrapperEngine];
            }
        }
    }
    
    return nil;
}
+(NSString*)wineskinEngineOfPortAtPath:(NSString*)path
{
    NSString* primaryEngine = [self getPrimaryWineskinWrapperEngineAtPath:path];
    BOOL primaryEngineExists = !!primaryEngine;
    BOOL primaryEngineIsDesirable = [primaryEngine matchesWithRegex:REGEX_WINESKIN_ENGINE];
    
    if (primaryEngineExists && primaryEngineIsDesirable)
    {
        return primaryEngine;
    }
    
    NSString* wineInfPath = [NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle/share/wine/wine.inf",path];
    NSString* secondaryEngine = [self getWineskinWrapperEngineFromInfFileAtPath:wineInfPath];
    BOOL secondaryEngineExists = !!secondaryEngine;
    BOOL secondaryEngineIsDesirable = [secondaryEngine matchesWithRegex:REGEX_WINESKIN_ENGINE];
    
    if (secondaryEngineExists && secondaryEngineIsDesirable)
    {
        return secondaryEngine;
    }
    
    if ([primaryEngine isEqualToString:secondaryEngine])
    {
        return primaryEngine;
    }
    
    if ([primaryEngine hasPrefix:@"WS"]) return primaryEngine;
    return secondaryEngine;
}
+(NSString*)engineOfPortAtPath:(NSString*)path
{
    return [self wineskinEngineOfPortAtPath:path];
}

+(NSString*)getMenubarItemFunctionFromFile:(NSString*)menuFile ofPort:(NSString*)port
{
    menuFile = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinMenuScripts/%@",port,menuFile];
    if ([[NSFileManager defaultManager] fileExistsAtPath:menuFile])
    {
        NSString* text = [NSString stringWithContentsOfFile:menuFile encoding:NSASCIIStringEncoding error:nil];
        
        NSArray* fragments = [text componentsSeparatedByString:@"export WINEPREFIX=\"$CONTENTSFOLD/Resources\"\n"];
        if ([fragments count]==1) fragments = [text componentsSeparatedByString:@"CONTENTSFOLD=\"$PWD\"\n"];
        if ([fragments count]>1)
        {
            NSString* command = fragments[1];
            while ([command hasPrefix:@"\n"]) command = [command substringFromIndex:1];
            while ([command hasSuffix:@"\n"]) command = [command substringToIndex:command.length-1];
            return command;
        }
        return @" ";
    }
    return @" ";
}

+(BOOL)macDriverIsEnabledAtPort:(NSString*)path withEngine:(NSString*)engine
{
    if ([NSWineskinEngine isMacDriverCompatibleWithEngine:engine])
    {
        NSPortManager* port = [NSPortManager managerWithPath:path];
        NSString* driversVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Drivers]" fromRegistryFileNamed:USER_REG];
        if (driversVariable)
        {
            driversVariable = [NSPortManager getStringValueForKey:@"Graphics" fromRegistryString:driversVariable];
            return driversVariable && [driversVariable isEqualToString:@"mac"];
        }
    }
    
    return FALSE;
}
+(BOOL)winedbgIsDisabledAtPort:(NSString*)path
{
    NSPortManager* port = [NSPortManager managerWithPath:path];
    NSString* winedbgVariable = [port getRegistryEntry:@"[Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\AeDebug]" fromRegistryFileNamed:SYSTEM_REG];
    if (winedbgVariable)
    {
        winedbgVariable = [NSPortManager getStringValueForKey:@"Debugger" fromRegistryString:winedbgVariable];
        if (winedbgVariable) return [winedbgVariable isEqualToString:@"false"];
        }
    return false;
}
+(BOOL)decorateWindowIsEnabledAtPort:(NSString*)path
{
    NSPortManager* port = [NSPortManager managerWithPath:path];
    
    NSString* X11Driver = [port getRegistryEntry:@"[Software\\\\Wine\\\\X11 Driver]" fromRegistryFileNamed:USER_REG];
    NSString* managed   = [NSPortManager getStringValueForKey:@"Managed" fromRegistryString:X11Driver];
    NSString* decorated = [NSPortManager getStringValueForKey:@"Decorated" fromRegistryString:X11Driver];
    
    BOOL notManaged   = !managed   || [managed   isEqualToString:@"N"];
    BOOL notDecorated = !decorated || [decorated isEqualToString:@"N"];
    return X11Driver && !(notManaged && notDecorated);
}
+(BOOL)direct3DBoostIsEnabledAtPort:(NSString*)path
{
    NSPortManager* port = [NSPortManager managerWithPath:path];
    
    NSString* direct3DVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Direct3D]" fromRegistryFileNamed:USER_REG];
    if (direct3DVariable)
    {
        NSString* engine = [NSPortDataLoader engineOfPortAtPath:path];
        
        if (![NSWineskinEngine isCsmtCompatibleWithEngine:engine])
        {
            return false;
        }
        
        if ([NSWineskinEngine csmtUsesNewRegistryWithEngine:engine])
        {
            direct3DVariable = [NSPortManager getValueForKey:@"csmt" fromRegistryString:direct3DVariable];
            if (direct3DVariable) return [direct3DVariable isEqualToString:@"dword:00000001"];
        }
        else
        {
            direct3DVariable = [NSPortManager getStringValueForKey:@"CSMT" fromRegistryString:direct3DVariable];
            if (direct3DVariable) return [direct3DVariable isEqualToString:@"enabled"];
        }
    }
    
    return false;
}
+(BOOL)retinaModeIsEnabledAtPort:(NSString*)path withEngine:(NSString*)engine
{
    if ([NSWineskinEngine isHighQualityModeCompatibleWithEngine:engine])
    {
        NSPortManager* port = [NSPortManager managerWithPath:path];
        NSString* macDriverVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Mac Driver]" fromRegistryFileNamed:USER_REG];
        if (macDriverVariable)
        {
            macDriverVariable = [NSPortManager getStringValueForKey:@"RetinaMode" fromRegistryString:macDriverVariable];
            return macDriverVariable && [macDriverVariable isEqualToString:@"Y"];
        }
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

+(BOOL)isImage:(NSImage*)icns2 equalsToImage:(NSImage*)icns
{
    NSData *data1 = [[icns imageByFramingImageResizing:YES] TIFFRepresentation];
    NSBitmapImageRep *imageRep1 = [NSBitmapImageRep imageRepWithData:data1];
    data1 = [imageRep1 representationUsingType:NSPNGFileType properties:@{}];
    
    NSData *data2 = [[icns2 imageByFramingImageResizing:YES] TIFFRepresentation];
    NSBitmapImageRep *imageRep2 = [NSBitmapImageRep imageRepWithData:data2];
    data2 = [imageRep2 representationUsingType:NSPNGFileType properties:@{}];
    
    return [data1 isEqualToData:data2];
}
+(NSImage*)getIconImageAtPort:(NSString*)path
{
    NSImage* img;
    NSString* gameImageFileName = [NSUtilities getPlistItem:WINESKIN_WRAPPER_PLIST_KEY_ICON_PATH fromWrapper:path];
    
    if (gameImageFileName)
    {
        if (![gameImageFileName hasSuffix:@".icns"]) gameImageFileName = [gameImageFileName stringByAppendingString:@".icns"];
        NSString* gameImageCompletePath = [NSString stringWithFormat:@"%@/Contents/Resources/%@",path,gameImageFileName];
        NSImage* gameImage = [[NSImage alloc] initWithContentsOfFile:gameImageCompletePath];
        img = gameImage;
    }
    
    NSImage* quicklookIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] imageByFramingImageResizing:YES];;
    if (!img || ![self isImage:quicklookIcon equalsToImage:img])
    {
        img = [quicklookIcon imageByFramingImageResizing:YES];
    }
    
    return img;
}

+(NSString*)pathForBatFileAtCDrivePath:(NSString*)batPath atPort:(NSString*)portPath
{
    NSString* bat = [[NSString stringWithFormat:@"C:/%@",batPath] stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    NSString* way = [NSPathUtilities getMacPathForWindowsPath:bat ofWrapper:portPath];
    NSString* batContents = [NSString stringWithContentsOfFile:way encoding:NSASCIIStringEncoding];
    return [batContents stringByReplacingOccurrencesOfString:@"\n" withString:@" & "];
}
+(NSString*)pathForMainExeAtPort:(NSString*)port
{
    NSString* flag = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS;
    NSString* path = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH;
    
    NSString* customFile = [NSUtilities getPlistItem:path fromWrapper:port];
    NSString* flags = [NSUtilities getPlistItem:flag fromWrapper:port];
    if (!flags) flags = @"";
    
    if ([customFile hasSuffix:@".bat"])
    {
        return [self pathForBatFileAtCDrivePath:customFile atPort:port];
    }
    
    return [[[NSString stringWithFormat:@"\"C:/%@\" %@",customFile,flags] stringByReplacingOccurrencesOfString:@"//" withString:@"/"]
                                                                          stringByReplacingOccurrencesOfString:@"/"  withString:@"\\"];
}
+(NSString*)pathForCustomEXEFileAtPath:(NSString*)wrap withPlist:(NSString*)plist atPort:(NSString*)port
{
    NSString* path = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH;
    NSString* flag = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS;
    
    NSString* progPath = [NSUtilities getPlistItem:path fromPlist:plist fromWrapper:wrap];
    if ([progPath hasSuffix:@".bat"])
    {
        progPath = [self pathForBatFileAtCDrivePath:progPath atPort:port];
    }
    else
    {
        NSString* fullPath = [NSString stringWithFormat:@"C:/%@",progPath];
        fullPath = [fullPath stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
        
        NSString* flags = [NSUtilities getPlistItem:flag fromPlist:plist fromWrapper:wrap];
        if (!flags) flags = @"";
        
        progPath = [NSString stringWithFormat:@"\"%@\" %@",fullPath,flags];
    }
    
    return progPath;
}

+(BOOL)isCloseNicelyEnabledAtPort:(NSPortManager*)port
{
    NSString* wineskinQuitScriptPath = [NSString stringWithFormat:@"%@/Contents/Resources/Scripts/WineskinQuitScript",
                                        port.path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:wineskinQuitScriptPath])
    {
        NSString* text = [NSString stringWithContentsOfFile:wineskinQuitScriptPath encoding:NSASCIIStringEncoding error:nil];
        NSArray* fragments = [text componentsSeparatedByString:@"wineskinAppChoice="];
        fragments = [fragments[1] componentsSeparatedByString:@"\n"];
        
        return [fragments[0] isEqualToString:@"2"];
    }
    
    return false;
}

@end
