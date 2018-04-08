//
//  NSData+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSData+Extension.h"

@implementation NSData (PKData)
+(NSData*)dataWithContentsOfURL:(NSURL *)url timeoutInterval:(long long int)timeoutInterval
{
    NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:timeoutInterval];
    
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    NSData* stringData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error || response.statusCode < 200 || response.statusCode >= 300 || !stringData)
    {
        return nil;
    }
    
    return stringData;
}

@end
