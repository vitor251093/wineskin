//
//  NSMutableDictionary+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/07/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSMutableDictionary_Extension_Class
#define NSMutableDictionary_Extension_Class

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (PKMutableDictionary)

+(instancetype)mutableDictionaryWithContentsOfFile:(NSString*)filePath;

@end

#endif
