//
//  NSWineskinEngine.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSWineskinEngine : NSObject

+(NSMutableArray*)getListOfLocalEngines;

+(BOOL)isMacDriverCompatibleWithEngine:(NSString*)engineString;
+(BOOL)isCsmtCompatibleWithEngine:(NSString*)engineString;
+(BOOL)csmtUsesNewRegistryWithEngine:(NSString*)engineString;
+(BOOL)isHighQualityModeCompatibleWithEngine:(NSString*)engineString;

+(NSString*)mostRecentVersionOfEngine:(NSString*)engine;

+(NSString*)localPathForEngine:(NSString*)engine;

@end
