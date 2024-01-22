//
//  NSWineskinEngine.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    NSWineskinEngineWine,
    NSWineskinEngineWineStaging,
    NSWineskinEngineProton,
    NSWineskinEngineCrossOver,
    NSWineskinEngineCrossOverGames,
    NSWineskinEngineOther
} NSWineskinEngineType;

@interface NSWineskinEngine : NSObject

-(NSString*)engineName;
@property (nonatomic, strong) NSString* engineIdentifier;
@property (nonatomic) int engineVersion;
@property (nonatomic, strong) NSString* wineVersion;
@property (nonatomic, strong) NSString* complement;
@property (nonatomic) NSWineskinEngineType engineType;
@property (nonatomic) BOOL is64Bit;
@property (nonatomic) BOOL vulkanEnabled;
@property (nonatomic) BOOL gnutlsEnabled;

+(NSMutableArray<NSWineskinEngine*>*)getListOfLocalEngines;

+(NSWineskinEngine*)wineskinEngineWithString:(NSString*)engineString;

-(BOOL)isCompatibleWithMacDriver;
-(BOOL)isCompatibleWithCsmt;
-(BOOL)isCompatibleWithCommandCtrl;
-(BOOL)isCompatibleWithOptionAlt;
-(BOOL)csmtUsesNewRegistry;
-(BOOL)isCompatibleWithHighQualityMode;
-(BOOL)isCompatibleWith16Bit;
-(BOOL)isForceWinetricksNeeded;

+(NSString*)localPathForEngine:(NSString*)engine;

@end
