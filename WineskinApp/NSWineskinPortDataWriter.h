//
//  NSWineskinPortDataWriter.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 08/06/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSPortManager.h"

@interface NSWineskinPortDataWriter : NSObject

//Saving registry changes instructions
+(BOOL)removeFromRegistryAppsThatRunAutomaticallyOnWrapperStartupAtPort:(NSPortManager*)port;
//Saving Data instructions
+(BOOL)saveCloseSafely:(NSNumber*)closeSafely atPort:(NSPortManager*)port;
+(BOOL)saveCopyrightsAtPort:(NSPortManager*)port;
+(BOOL)saveWinedbg:(BOOL)Debugged atPort:(NSPortManager*)port;
+(BOOL)saveMacDriver:(BOOL)macdriver atPort:(NSPortManager*)port;
+(BOOL)saveDirect3DBoost:(BOOL)direct3DBoost withEngine:(NSString*)engine atPort:(NSPortManager*)port;
+(BOOL)saveDecorateWindow:(BOOL)decorate atPort:(NSPortManager*)port;
+(BOOL)saveRetinaMode:(BOOL)retinaModeOn withEngine:(NSString*)engine atPort:(NSPortManager*)port;
+(BOOL)saveCommandMode:(BOOL)commandModeOn withEngine:(NSString*)engineString atPort:(NSPortManager*)port;
+(BOOL)saveOptionMode:(BOOL)optionModeOn withEngine:(NSString*)engineString atPort:(NSPortManager*)port;
+(BOOL)saveFontSmoothingMode:(BOOL)fontsmoothingModeOn atPort:(NSPortManager*)port;

+(BOOL)setMainExeName:(NSString*)name version:(NSString*)version icon:(NSImage*)icon path:(NSString*)path atPort:(NSPortManager*)port;
+(BOOL)addCustomExeWithName:(NSString*)name version:(NSString*)version icon:(NSImage*)icon path:(NSString*)path atPortAtPath:(NSString*)portPath;

@end
