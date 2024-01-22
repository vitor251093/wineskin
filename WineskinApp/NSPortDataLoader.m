//
//  NSPortDataLoader.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 07/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPortDataLoader.h"
#import "NSUtilities.h"
#import "NSPathUtilities.h"

#import "NSDropIconView.h"

#import "NSAlert+Extension.h"
#import "NSImage+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

@implementation NSPortDataLoader

+(NSString*)wineskinEngineOfPortAtPath:(NSString*)path
{
    NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/SharedSupport/wine/version",path];
    //NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/SharedSupport/wswine.bundle/version",path];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:wswineVersion])
    {
        return [[NSString stringWithContentsOfFile:wswineVersion encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\n"][0];
    }
    
    return nil;
}
+(NSString*)engineOfPortAtPath:(NSString*)path
{
    return [self wineskinEngineOfPortAtPath:path];
}

+(BOOL)macDriverIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine
{
    if (engine.isCompatibleWithMacDriver)
    {
        NSPortManager* port = [NSPortManager managerWithPath:path];
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
        NSString* engineString = [NSPortDataLoader engineOfPortAtPath:path];
        NSWineskinEngine* engine = [NSWineskinEngine wineskinEngineWithString:engineString];
        
        if (!engine.isCompatibleWithCsmt)
        {
            return false;
        }
        
        if (engine.csmtUsesNewRegistry)
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
+(BOOL)retinaModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine
{
    if (engine.isCompatibleWithHighQualityMode)
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
+(BOOL)CommandModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine
{
    if (engine.isCompatibleWithCommandCtrl)
    {
        NSPortManager* port = [NSPortManager managerWithPath:path];
        NSString* commandVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Mac Driver]" fromRegistryFileNamed:USER_REG];
    if (commandVariable)
    {
        commandVariable = [NSPortManager getStringValueForKey:@"LeftCommandIsCtrl" fromRegistryString:commandVariable];
        return commandVariable && [commandVariable isEqualToString:@"Y"];
        }
    }
    
    return FALSE;
}
+(BOOL)OptionModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine
{
    if (engine.isCompatibleWithOptionAlt)
    {
        NSPortManager* port = [NSPortManager managerWithPath:path];
        NSString* optionVariable = [port getRegistryEntry:@"[Software\\\\Wine\\\\Mac Driver]" fromRegistryFileNamed:USER_REG];
        if (optionVariable)
        {
            optionVariable = [NSPortManager getStringValueForKey:@"RightOptionIsAlt" fromRegistryString:optionVariable];
            return optionVariable && [optionVariable isEqualToString:@"Y"];
        }
    }
    
    return FALSE;
}
+(BOOL)FontSmoothingIsEnabledAtPort:(NSString*)path
{
    NSPortManager* port = [NSPortManager managerWithPath:path];
    NSString* optionVariable = [port getRegistryEntry:@"[Control Panel\\\\Desktop]" fromRegistryFileNamed:USER_REG];
    if (optionVariable)
    {
        optionVariable = [NSPortManager getStringValueForKey:@"FontSmoothing" fromRegistryString:optionVariable];
        return optionVariable && [optionVariable isEqualToString:@"2"];
    }
    
    return FALSE;
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

+(NSString*)pathForMainExeAtPort:(NSString*)port
{
    NSString* path = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH;
    NSString* flag = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS;
    
    NSString* progPath = [NSUtilities getPlistItem:path fromWrapper:port];
    
    {
        NSString* fullPath = [NSString stringWithFormat:@"C:/%@",progPath];
        fullPath = [[fullPath stringByReplacingOccurrencesOfString:@"//" withString:@"/"]
                    stringByReplacingOccurrencesOfString:@"/"  withString:@"\\"];
        
        NSString* flags = [NSUtilities getPlistItem:flag fromWrapper:port];
        if (!flags) flags = @"";
        
        progPath = [NSString stringWithFormat:@"\"%@\" %@",fullPath,flags];
    }
    
    return progPath;
}
+(NSString*)pathForCustomEXEFileAtPath:(NSString*)wrap withPlist:(NSString*)plist atPort:(NSString*)port
{
    NSString* path = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH;
    NSString* flag = WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS;
    
    NSString* progPath = [NSUtilities getPlistItem:path fromPlist:plist fromWrapper:wrap];

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
