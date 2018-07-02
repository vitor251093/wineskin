//
//  NSWineskinEngine.h
//  Porting Kit
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

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
@property (nonatomic, strong) NSString* wineVersion;
@property (nonatomic, strong) NSString* complement;
@property (nonatomic) NSWineskinEngineType engineType;
@property (nonatomic) BOOL is64Bit;

+(NSMutableArray<NSWineskinEngine*>*)getListOfAvailableEngines;

+(NSWineskinEngine*)wineskinEngineWithString:(NSString*)engineString;

+(NSWineskinEngine*)wineskinEngineOfType:(NSWineskinEngineType)engineType is64Bit:(BOOL)is64Bit ofVersion:(NSString*)version withComplement:(NSString*)complement;

-(NSString*)engineName;
-(NSString*)localPath;
-(BOOL)isCompatibleWithMacDriver;
-(BOOL)isCompatibleWithCsmt;
-(BOOL)csmtUsesNewRegistry;
-(BOOL)isCompatibleWithHighQualityMode;
-(BOOL)isCompatibleWith16Bit;

-(BOOL)isCompatibleWithSteam;
-(BOOL)isCompatibleWithOrigin;
-(BOOL)isCompatibleWithUplay;
-(BOOL)isCompatibleWithGOGGalaxy;

+(NSString*)localPathForEngine:(NSString*)engine;

@end
