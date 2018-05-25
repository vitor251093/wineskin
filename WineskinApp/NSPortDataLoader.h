//
//  NSPortDataLoader.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 07/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSPortManager.h"

@interface NSPortDataLoader : NSObject

+(NSString*)wineskinEngineOfPortAtPath:(NSString*)path;
+(NSString*)engineOfPortAtPath:(NSString*)path;

+(BOOL)macDriverIsEnabledAtPort:(NSString*)path withEngine:(NSString*)engine;
+(BOOL)decorateWindowIsEnabledAtPort:(NSString*)path;
+(BOOL)direct3DBoostIsEnabledAtPort:(NSString*)path;
+(BOOL)retinaModeIsEnabledAtPort:(NSString*)path withEngine:(NSString*)engine;

+(void)getValuesFromResolutionString:(NSString*)originalResolutionString
                             inBlock:(void (^)(BOOL virtualDesktop, NSString* resolution, int colors, int sleep))resolutionValues;

+(NSImage*)getIconImageAtPort:(NSString*)path;

+(BOOL)isCloseNicelyEnabledAtPort:(NSPortManager*)port;

+(NSString*)pathForMainExeAtPort:(NSString*)port;

@end
