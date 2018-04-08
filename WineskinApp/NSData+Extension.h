//
//  NSData+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSData_Extension_Class
#define NSData_Extension_Class

#import <Foundation/Foundation.h>

@interface NSData (PKData)

+(NSData*)dataWithContentsOfURL:(NSURL *)url timeoutInterval:(long long int)timeoutInterval;

@end

#endif
