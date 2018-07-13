//
//  NSPathUtilities.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSPathUtilities_Class
#define NSPathUtilities_Class

#import <Foundation/Foundation.h>

@interface NSPathUtilities : NSObject

+(NSString*)wineskinAppBinaryForPortAtPath:(NSString*)path;
+(NSString*)wineskinLauncherBinForPortAtPath:(NSString*)path;

+(NSString*)getMacPathForWindowsDrive:(char)driveLetter ofWrapper:(NSString*)file;
+(NSString*)getMacPathForWindowsPath:(NSString*)exePath ofWrapper:(NSString*)file;
+(NSString*)getWindowsPathForMacPath:(NSString*)exePath ofWrapper:(NSString*)file;

+(NSString*)getFileNameOfWindowsPath:(NSString*)exePath;
+(NSString*)getFlagsOfWindowsPath:(NSString*)exePath;

+(BOOL)isPath:(NSString*)path compatibleWithStruct:(NSString*)structure;
+(NSArray*)filesCompatibleWithStructure:(NSString*)appPath insideFolder:(NSString*)folder;

@end

#endif
