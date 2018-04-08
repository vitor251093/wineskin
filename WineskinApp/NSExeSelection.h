//
//  SelectMainEXE.h
//  Porting Center
//
//  Created by Vitor Marques de Miranda.
//  Copyright 2014 UFRJ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSExeSelection : NSObject

+(NSString*)getAutorunPathFromFile:(NSString*)arquivo forPort:(NSString*)wrapperUrl;

+(NSString*)selectAsMainExe:(NSString*)arquivo forPort:(NSString*)wrapperUrl;

@end
