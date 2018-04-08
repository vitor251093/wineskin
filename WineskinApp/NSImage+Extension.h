//
//  NSImage+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 12/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSImage_Extension_Class
#define NSImage_Extension_Class

#import <Foundation/Foundation.h>

@interface NSImage (PKImage)

-(NSImage*)imageByFramingImageResizing:(BOOL)willResize;

-(BOOL)saveAsIcnsAtPath:(NSString*)icnsPath;

@end

#endif
