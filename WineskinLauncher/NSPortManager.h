//
//  NSPortManager.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 01/09/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SYSTEM_REG  @"system"
#define USER_REG    @"user"
#define USERDEF_REG @"userdef"

@interface NSPortManager : NSObject
{
    NSFileHandle *portTrackerFileHandle;
    NSString* portPathBackup;
}

typedef enum {
    NSPortManagerTypeWrapper,
    NSPortManagerTypeCustomExe
} NSPortManagerType;

@property (nonatomic) NSPortManagerType type;
@property (nonatomic, strong) NSMutableDictionary* plist;
@property (nonatomic, strong) NSMutableDictionary* x11Plist;

+(NSPortManager*)managerForWrapperAtPath:(NSString*)path;
+(NSPortManager*)managerForCustomExeAtPath:(NSString*)path;

+(NSPortManager*)managerForPortAtPath:(NSString*)path;;

-(BOOL)isWrapper;
-(BOOL)isCustomEXE;

-(NSString*)path;

-(BOOL)mainExeHasInvalidPath;

-(NSString*)runWithArguments:(NSArray*)args forcingLogReturn:(BOOL)returnLog;
-(NSString*)installWinetrick:(NSString*)winetrick;

-(NSString*)runEXE:(NSString*)installerFile withFlags:(NSString*)flags;

-(id)plistObjectForKey:(NSString*)item;
-(void)setPlistObject:(id)object forKey:(NSString*)item;
-(BOOL)synchronizePlist;

-(id)x11PlistObjectForKey:(NSString*)item;
-(void)setX11PlistObject:(id)object forKey:(NSString*)item;
-(BOOL)synchronizeX11Plist;

-(BOOL)isWinetrickAvailableForInstalling:(NSString*)winetrickName;

-(NSString*)completeWindowsPath:(NSString*)windowsPath;

-(NSString*)programFilesPathFor64bitsApplication:(BOOL)is64bits;

-(NSString*)getPathForRegistryFile:(NSString*)reg;
-(void)addRegistry:(NSString*)lines fromRegistryFileNamed:(NSString*)reg;
-(void)deleteRegistry:(NSString*)line fromRegistryFileNamed:(NSString*)reg;
-(NSArray*)getRegistriesWithGramar:(NSString*)gramar fromRegistryFileNamed:(NSString*)reg;
-(NSString*)getRegistryEntry:(NSString*)line fromRegistryFileNamed:(NSString*)reg;

+(NSString*)getRegistryEntry:(NSString*)line fromRegistryString:(NSString*)text;

-(void)setValue:(NSString*)value forKey:(NSString*)key atRegistryEntryString:(NSMutableString*)registry;
-(void)setValues:(NSDictionary*)values atRegistryEntryString:(NSMutableString*)registry;
-(void)setValues:(NSDictionary*)values forEntry:(NSString*)registryEntry atRegistryFileNamed:(NSString*)regFileName;

+(NSString*)getStringValueForKey:(NSString*)value fromRegistryString:(NSString*)registry;
+(NSString*)getValueForKey:(NSString*)value fromRegistryString:(NSString*)registry;
+(NSArray*)getKeysFromRegistryString:(NSString*)registry;

@end
