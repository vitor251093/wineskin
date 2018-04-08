//
//  NSWebUtilities.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSWebUtilities_Class
#define NSWebUtilities_Class

#import <Foundation/Foundation.h>

@interface NSWebUtilities : NSObject

+(NSString*)timeNeededToDownload:(long long int)needed withSpeed:(long long int)speed;

@end

#endif
