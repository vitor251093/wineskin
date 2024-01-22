//
//  NSPortDataLoader.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 07/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSPortManager.h"
#import "NSWineskinEngine.h"

@interface NSPortDataLoader : NSObject

+(NSString*)wineskinEngineOfPortAtPath:(NSString*)path;
+(NSString*)engineOfPortAtPath:(NSString*)path;

+(BOOL)macDriverIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine;
+(BOOL)winedbgIsDisabledAtPort:(NSString*)path;
+(BOOL)decorateWindowIsEnabledAtPort:(NSString*)path;
+(BOOL)direct3DBoostIsEnabledAtPort:(NSString*)path;
+(BOOL)retinaModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine;
+(BOOL)CommandModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine;
+(BOOL)OptionModeIsEnabledAtPort:(NSString*)path withEngine:(NSWineskinEngine*)engine;
+(BOOL)FontSmoothingIsEnabledAtPort:(NSString*)path;

+(NSImage*)getIconImageAtPort:(NSString*)path;

+(BOOL)isCloseNicelyEnabledAtPort:(NSPortManager*)port;

+(NSString*)pathForMainExeAtPort:(NSString*)port;

@end
