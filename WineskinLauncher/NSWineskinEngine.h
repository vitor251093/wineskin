//
//  NSWineskinEngine.h
//  Porting Kit
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const REGEX_VALID_WINESKIN_ENGINE =                 @"[A-Z]{2}[0-9]+Wine(CX|CXG|Staging)?(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_WINE_ENGINE =            @"[A-Z]{2}[0-9]+Wine(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_STAGING_ENGINE =         @"[A-Z]{2}[0-9]+WineStaging(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_CROSSOVER_ENGINE =       @"[A-Z]{2}[0-9]+WineCX(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_CROSSOVER_GAMES_ENGINE = @"[A-Z]{2}[0-9]+WineCXG(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINE_VERSION =                    @"[0-9]+(\\.[0-9]+)*([-\\.]{1}rc[0-9]+)?";

typedef enum {
    NSWineskinEngineWine,
    NSWineskinEngineWineStaging,
    NSWineskinEngineCrossOver,
    NSWineskinEngineCrossOverGames,
    NSWineskinEngineOther
} NSWineskinEngineType;

@interface NSWineskinEngine : NSObject

@property (nonatomic, strong) NSString* engineIdentifier;
@property (nonatomic) int engineVersion;
@property (nonatomic, strong) NSString* version;
@property (nonatomic, strong) NSString* complement;
@property (nonatomic) NSWineskinEngineType engineType;
@property (nonatomic) BOOL is64Bit;
    
+(NSWineskinEngine*)wineskinEngineWithString:(NSString*)engineString;

+(NSWineskinEngine*)wineskinEngineOfType:(NSWineskinEngineType)engineType is64Bit:(BOOL)is64Bit ofVersion:(NSString*)version withComplement:(NSString*)complement;

+(NSWineskinEngine*)wineskinEngineOfPortAtPath:(NSString*)path;
    
-(NSString*)engineName;
-(BOOL)isCompatibleWithMacDriver;
-(BOOL)isMacDriverDefaultGraphics;

@end
