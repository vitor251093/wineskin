//
//  NSPortManager.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 01/09/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SYSTEM_REG @"system"
#define USER_REG   @"user"

@interface NSPortManager : NSObject

@property (nonatomic) BOOL isCustomEXE;
@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSMutableDictionary* plist;

+(NSPortManager*)managerWithPath:(NSString*)path;
+(NSPortManager*)managerWithCustomExePath:(NSString*)path;

-(void)setIconWithImage:(NSImage*)sourceImage;

-(NSString*)runWithArguments:(NSArray*)args;
-(NSString*)installWinetrick:(NSString*)winetrick;

-(NSString*)runEXE:(NSString*)installerFile withFlags:(NSString*)flags;

-(id)plistObjectForKey:(NSString*)item;
-(void)setPlistObject:(id)object forKey:(NSString*)item;
-(void)synchronizePlist;

-(void)addToPortCreationLog:(NSString*)newLogs;

-(BOOL)isWinetrickAvailableForInstalling:(NSString*)winetrickName;

-(NSString*)completeWindowsPath:(NSString*)windowsPath;

-(NSString*)programFilesPathFor64bitsApplication:(BOOL)is64bits;

-(NSString*)getPathForRegistryFile:(NSString*)reg;
-(BOOL)addRegistry:(NSString*)lines fromRegistryFileNamed:(NSString*)reg;
-(BOOL)deleteRegistry:(NSString*)line fromRegistryFileNamed:(NSString*)reg;
-(NSArray*)getRegistriesWithGramar:(NSString*)gramar fromRegistryFileNamed:(NSString*)reg;
-(NSString*)getRegistryEntry:(NSString*)line fromRegistryFileNamed:(NSString*)reg;

+(NSString*)getRegistryEntry:(NSString*)line fromRegistryString:(NSString*)text;

-(void)setValue:(NSString*)value forKey:(NSString*)key atRegistryEntryString:(NSMutableString*)registry;
-(void)setValues:(NSDictionary*)values atRegistryEntryString:(NSMutableString*)registry;
-(BOOL)setValues:(NSDictionary*)values forEntry:(NSString*)registryEntry atRegistryFileNamed:(NSString*)regFileName;

+(NSString*)getStringValueForKey:(NSString*)value fromRegistryString:(NSString*)registry;
+(NSString*)getValueForKey:(NSString*)value fromRegistryString:(NSString*)registry;

@end
