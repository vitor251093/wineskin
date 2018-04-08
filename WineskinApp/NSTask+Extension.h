//
//  NSTask+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSTask_Extension_Class
#define NSTask_Extension_Class

#import <Foundation/Foundation.h>

@interface NSTask (PKTask)

+(NSString*)runProgram:(NSString*)program atRunPath:(NSString*)path withFlags:(NSArray*)flags wait:(BOOL)wait;
+(NSString*)runProgram:(NSString*)program withEnvironment:(NSDictionary*)env withFlags:(NSArray*)flags;

@end

#endif
