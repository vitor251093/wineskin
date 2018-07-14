//
//  NSWineskinPortDataWriter.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 08/06/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSWineskinPortDataWriter.h"

#import "NSPathUtilities.h"
#import "NSWineskinEngine.h"

#import "NSComputerInformation.h"

#import "NSData+Extension.h"
#import "NSTask+Extension.h"
#import "NSString+Extension.h"
#import "NSThread+Extension.h"
#import "NSSavePanel+Extension.h"
#import "NSFileManager+Extension.h"

@implementation NSWineskinPortDataWriter

//Saving registry changes instructions
+(BOOL)removeFromRegistryAppsThatRunAutomaticallyOnWrapperStartupAtPort:(NSPortManager*)port
{
    NSString* registry = @"[Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run]";
    [port deleteRegistry:registry fromRegistryFileNamed:USER_REG];
    return [port addRegistry:[NSString stringWithFormat:@"%@\n",registry] fromRegistryFileNamed:USER_REG];
}

//Custom EXE Functions
+(void)setMainExePath:(NSString*)exePath atPort:(NSPortManager*)port
{
    if (!exePath) return;
    
    NSString* dictPath = [exePath stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    NSString* winPath = [NSPathUtilities getFileNameOfWindowsPath:dictPath];
    NSString* flags = [NSPathUtilities getFlagsOfWindowsPath:dictPath];
    
    if ([winPath contains:@"*"])
    {
        NSString* newWinPath = [port completeWindowsPath:winPath];
        if (newWinPath) winPath = newWinPath;
    }
    
    if ([[[winPath getFragmentAfter:nil andBefore:@":"] lowercaseString] isEqualToString:@"c"])
    {
        [port setPlistObject:[winPath componentsSeparatedByString:@":"][1]   forKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH];
        [port setPlistObject:@(![winPath.lowercaseString hasSuffix:@".exe"]) forKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE];
        [port setPlistObject:flags                                           forKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS];
    }
    else
    {
        NSString* batFilePath = [NSString stringWithFormat:@"/exec%u.bat",arc4random()];
        NSString* way = [NSPathUtilities getMacPathForWindowsPath:[NSString stringWithFormat:@"C:%@",batFilePath] ofWrapper:port.path];
        
        [port setPlistObject:@TRUE       forKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE];
        [port setPlistObject:batFilePath forKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH];
        
        dictPath = [NSString stringWithFormat:@"\"%@\" %@",winPath,flags];
        [dictPath writeToFile:way atomically:YES encoding:NSStringEncodingConversionAllowLossy];
    }
}
+(void)setAutomaticScreenOptions:(BOOL)automatic fullscreen:(BOOL)fullscreen virtualDesktop:(BOOL)virtualDesktop resolution:(NSString*)resolution colors:(int)colors sleep:(int)sleep atPort:(NSPortManager*)port
{
    [port setPlistObject:@(automatic)  forKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_ARE_AUTOMATIC];
    [port setPlistObject:@(fullscreen) forKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_IS_FULLSCREEN];
    
    if (!automatic && virtualDesktop)
    {
        [port setPlistObject:[NSString stringWithFormat:@"%@x%dsleep%d", resolution,colors,sleep]
                      forKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
    }
    else
    {
        [port setPlistObject:[NSString stringWithFormat:@"novdx%dsleep%d",colors,sleep]
                      forKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
    }
    
    [port synchronizePlist];
}

//Saving Data instructions
+(BOOL)saveCloseSafely:(NSNumber*)closeSafely atPort:(NSPortManager*)port
{
    NSString* wineskinQuitScriptPath = [NSString stringWithFormat:@"%@/Contents/Resources/Scripts/WineskinQuitScript",
                                        port.path];
    NSString* text = [NSString stringWithContentsOfFile:wineskinQuitScriptPath encoding:NSASCIIStringEncoding];
    NSArray* fragments = [text componentsSeparatedByString:@"wineskinAppChoice="];
    NSString* part2;
    
    if ([closeSafely intValue] != 0)
        part2 = [fragments[1] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@"2"];
    else part2 = [fragments[1] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@"1"];
    
    text = [NSString stringWithFormat:@"%@wineskinAppChoice=%@",fragments[0],part2];
    [text writeToFile:wineskinQuitScriptPath atomically:YES encoding:NSStringEncodingConversionAllowLossy];
    
    return TRUE;
}
+(BOOL)saveCopyrightsAtPort:(NSPortManager*)port
{
    NSString *companyFile = [NSString stringWithFormat:@"%@/Contents/Resources/English.lproj/InfoPlist.strings",port.path];
    
    long year = (long)[[[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:NSDate.date] year];
    NSString* copyright = [NSString stringWithFormat:@"Copyright © 2014-%ld PortingKit.com. All rights reserved.", year];
    
    NSString *companyContent = [NSString stringWithFormat:@"NSHumanReadableCopyright=\"%@\";",copyright];
    [companyContent writeToFile:companyFile atomically:NO encoding:NSUTF8StringEncoding];
    
    return TRUE;
}
+(BOOL)saveWinedbg:(BOOL)Debugger atPort:(NSPortManager*)port
{
    NSString* key;
    NSString* value;
    NSString* winedbgRegistry = @"[Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\AeDebug]";
    
    key = @"Debugger";
    value = (Debugger ? @"\"false\"" : @"\"true\"");
    
    return [port setValues:@{key:value} forEntry:winedbgRegistry atRegistryFileNamed:SYSTEM_REG];
}
+(BOOL)saveMacDriver:(BOOL)macdriver atPort:(NSPortManager*)port
{
    NSString* driversRegistry = @"[Software\\\\Wine\\\\Drivers]";
    NSString* graphicsValue = (macdriver ? @"\"mac,x11\"" : @"\"x11,mac\"");
    return [port setValues:@{@"Graphics":graphicsValue} forEntry:driversRegistry atRegistryFileNamed:USER_REG];
}
+(BOOL)saveDirect3DBoost:(BOOL)direct3DBoost withEngine:(NSString*)engine atPort:(NSPortManager*)port
{
    if (![NSWineskinEngine isCsmtCompatibleWithEngine:engine])
    {
        return FALSE;
    }
    
    NSString* key;
    NSString* value;
    NSString* direct3DRegistry = @"[Software\\\\Wine\\\\Direct3D]";
    
    if ([NSWineskinEngine csmtUsesNewRegistryWithEngine:engine])
    {
        key = @"csmt";
        value = (direct3DBoost ? @"dword:00000001" : @"dword:00000000");
    }
    else
    {
        key = @"CSMT";
        value = (direct3DBoost ? @"\"enabled\"" : @"\"disabled\"");
    }
    
    return [port setValues:@{key:value} forEntry:direct3DRegistry atRegistryFileNamed:USER_REG];
}
+(BOOL)saveDecorateWindow:(BOOL)decorate atPort:(NSPortManager*)port
{
    NSString* decorateValue = (decorate ? @"\"Y\"" : @"\"N\"");
    NSString* x11DriverRegistry = @"[Software\\\\Wine\\\\X11 Driver]";
    
    return [port setValues:@{@"Managed"  :decorateValue,
                             @"Decorated":decorateValue} forEntry:x11DriverRegistry atRegistryFileNamed:USER_REG];
}
+(BOOL)saveRetinaMode:(BOOL)retinaModeOn withEngine:(NSString*)engine atPort:(NSPortManager*)port
{
    BOOL enableRetinaModeOn = retinaModeOn && [NSWineskinEngine isHighQualityModeCompatibleWithEngine:engine];
    
    BOOL result = true;
    result = [port setValues:@{@"LogPixels": (enableRetinaModeOn ? @"dword:000000c0" : @"dword:00000060")}
                    forEntry:@"[Control Panel\\\\Desktop]" atRegistryFileNamed:USER_REG];
    if (!result) return false;
    
    result = [port setValues:@{@"RetinaMode": (enableRetinaModeOn ? @"\"Y\"" : @"\"N\"")}
                    forEntry:@"[Software\\\\Wine\\\\Mac Driver]" atRegistryFileNamed:USER_REG];
    return result;
}

+(BOOL)setMainExeName:(NSString*)name version:(NSString*)version icon:(NSImage*)icon path:(NSString*)path atPort:(NSPortManager*)port
{
    [port setPlistObject:version forKey:WINESKIN_WRAPPER_PLIST_KEY_VERSION];
    
    if (icon && [icon isKindOfClass:[NSImage class]])
    {
        [port setIconWithImage:icon];
    }
    
    [self setMainExePath:path atPort:port];
    
    if (name)
    {
        [port setPlistObject:name forKey:WINESKIN_WRAPPER_PLIST_KEY_NAME];
        [port setPlistObject:[NSString stringWithFormat:@"%@.Wineskin.prefs",name] forKey:WINESKIN_WRAPPER_PLIST_KEY_IDENTIFIER];
    }
    
    [port synchronizePlist];
    
    return YES;
}
+(BOOL)addCustomExeWithName:(NSString*)name version:(NSString*)version icon:(NSImage*)icon path:(NSString*)path atPortAtPath:(NSString*)portPath
{
    NSString* customEXEapp = [NSString stringWithFormat:@"%@/Wineskin.app/Contents/Resources/CustomEXE.app",portPath];
    NSString* customEXEPath = [NSString stringWithFormat:@"%@/%@.app",portPath,name];
    [[NSFileManager defaultManager] copyItemAtPath:customEXEapp toPath:customEXEPath];
    
    NSPortManager* activePort = [NSPortManager managerWithCustomExePath:customEXEPath];

    [activePort setPlistObject:version forKey:WINESKIN_WRAPPER_PLIST_KEY_VERSION];
    
    if (activePort && [activePort isKindOfClass:[NSImage class]])
    {
        [activePort setIconWithImage:icon];
    }
    
    [self setMainExePath:path atPort:activePort];
    
    [activePort synchronizePlist];
    
    return YES;
}

@end
