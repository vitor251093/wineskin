//
//  NSUtilities.h
//  Gamma Board
//
//  Created by Vitor Marques de Miranda on 27/04/14.
//  Copyright (c) 2014 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUtilities : NSObject

+(id)getPlistItem:(NSString*)item fromWrapper:(NSString*)wrapper;
+(id)getPlistItem:(NSString*)item fromPlist:(NSString*)plist fromWrapper:(NSString*)wrapper;

@end
