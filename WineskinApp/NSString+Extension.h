//
//  NSString+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSString_Extension_Class
#define NSString_Extension_Class

#import <Foundation/Foundation.h>

@interface NSString (PKString)

-(BOOL)contains:(NSString*)string;
-(BOOL)matchesWithRegex:(NSString*)regexString;
-(NSArray<NSString*>*)componentsMatchingWithRegex:(NSString*)regexString;

+(NSString*)humanReadableSizeForBytes:(long long int)bytes withDecimalMeasureSystem:(BOOL)measure;
+(NSString*)stringWithHexString:(NSString*)string;
+(NSString*)stringByRemovingEvenCharsFromString:(NSString*)text;

-(NSRange)rangeAfterString:(NSString*)before andBeforeString:(NSString*)after;
-(NSString*)getFragmentAfter:(NSString*)before andBefore:(NSString*)after;

-(NSNumber*)initialIntegerValue;

+(NSString*)stringWithContentsOfFile:(NSString*)file encoding:(NSStringEncoding)enc;
+(NSString*)stringWithContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)enc timeoutInterval:(long long int)timeoutInterval;

-(BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc;

-(BOOL)isAValidURL;

@end

#endif
