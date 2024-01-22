//
//  NSString+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSString+Extension.h"

#import "NSData+Extension.h"
#import "NSTask+Extension.h"
#import "NSAlert+Extension.h"

#import "NSComputerInformation.h"

@implementation NSString (PKString)

-(BOOL)contains:(NSString*)string
{
    return [self rangeOfString:string].location != NSNotFound;
}
-(BOOL)matchesWithRegex:(NSString*)regexString
{
    NSPredicate* regex = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexString];
    return [regex evaluateWithObject:self];
}

-(NSString*)newUUIDString
{
    @autoreleasepool
    {
        if ([NSComputerInformation isSystemMacOsEqualOrSuperiorTo:@"10.8"] == false)
        {
            @autoreleasepool
            {
                CFUUIDRef udid = CFUUIDCreate(NULL);
                NSString* newUUID = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, udid));
                CFRelease(udid);
                return newUUID;
            }
        }
        
        return [[NSUUID UUID] UUIDString];
    }
}
-(NSArray<NSString*>*)componentsMatchingWithRegex:(NSString*)regexString
{
    NSMutableArray* matches;
    
    // Is class NSRegularExpression available
    if ([NSComputerInformation isSystemMacOsEqualOrSuperiorTo:@"10.7"] == false)
    {
        // TODO: Find a different way to replace NSRegularExpression... there must be a better way
        
        @autoreleasepool
        {
            NSString* uuid = [self newUUIDString];
            NSString* pyFileName  = [NSString stringWithFormat:@"pythonRegex%@.py",uuid];
            NSString* datFileName = [NSString stringWithFormat:@"pythonFile%@.dat",uuid];
            
            NSString* pythonScriptPath = [NSString stringWithFormat:@"%@%@",NSTemporaryDirectory(),pyFileName ];
            NSString* stringFilePath   = [NSString stringWithFormat:@"%@%@",NSTemporaryDirectory(),datFileName];
            
            NSArray* pythonScriptContentsArray = @[@"import re",
                                                   @"import os",
                                                   @"dir_path = os.path.dirname(os.path.abspath(__file__))",
                                                   [NSString stringWithFormat:@"text_file = open(dir_path + \"/%@\", \"r\")",datFileName],
                                                   @"text = text_file.read()",
                                                   [NSString stringWithFormat:@"regex = re.compile(r\"(%@)\")",regexString],
                                                   @"matches = regex.finditer(text)",
                                                   @"for match in matches:",
                                                   @"    print match.group()"];
            NSString* pythonScriptContents = [pythonScriptContentsArray componentsJoinedByString:@"\n"];
            
            [self                 writeToFile:stringFilePath   atomically:YES encoding:NSASCIIStringEncoding];
            [pythonScriptContents writeToFile:pythonScriptPath atomically:YES encoding:NSASCIIStringEncoding];
            
            NSString* output = [NSTask runProgram:@"python" atRunPath:nil withFlags:@[pythonScriptPath] wait:YES];
            matches = [[output componentsSeparatedByString:@"\n"] mutableCopy];
            [matches removeObject:@""];
        }
        
        return matches;
    }
    
    @autoreleasepool
    {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:0 error:NULL];
        NSArray* rangeArray = [regex matchesInString:self options:0 range:NSMakeRange(0, self.length)];
        
        matches = [[NSMutableArray alloc] init];
        for (NSTextCheckingResult *match in rangeArray)
        {
            [matches addObject:[self substringWithRange:match.range]];
        }
    }
    
    return matches;
}

+(NSString*)humanReadableSizeForBytes:(long long int)bytes withDecimalMeasureSystem:(BOOL)measure
{
    NSString* result = @"";
    int degree = 0;
    int minorBytes = 0;
    int divisor = measure ? 1000 : 1024;
    
    while (bytes/divisor && degree < 8)
    {
        minorBytes=bytes%divisor;
        bytes/=divisor;
        degree++;
    }
    
    switch (degree)
    {
        case 0:  result = @"b";  break;
        case 1:  result = @"Kb"; break;
        case 2:  result = @"Mb"; break;
        case 3:  result = @"Gb"; break;
        case 4:  result = @"Tb"; break;
        case 5:  result = @"Pb"; break;
        case 6:  result = @"Eb"; break;
        case 7:  result = @"Zb"; break;
        default: result = @"Yb"; break;
    }
    
    minorBytes = ((minorBytes*1000)/divisor)/100;
    if (minorBytes) result = [NSString stringWithFormat:@".%d%@",minorBytes,result];
    
    return [NSString stringWithFormat:@"%lld%@",bytes,result];
}
+(NSString*)stringWithHexString:(NSString*)string
{
    NSMutableString * newString = [[NSMutableString alloc] init];
    NSScanner *scanner = [[NSScanner alloc] initWithString:string];
    unsigned value;
    while ([scanner scanHexInt:&value])
    {
        if (value==0) [newString appendString:@"\0"];
        else [newString appendFormat:@"%c",(char)(value & 0xFF)];
    }
    return newString;
}
+(NSString*)stringByRemovingEvenCharsFromString:(NSString*)text
{
    NSMutableString* text2 = [NSMutableString stringWithString:@""];
    int x;
    for (x = 0; x < text.length; x = x+2)
    {
        [text2 appendString:[text substringWithRange:NSMakeRange(x,1)]];
    }
    return text2;
}

-(NSRange)rangeAfterString:(NSString*)before andBeforeString:(NSString*)after
{
    NSRange beforeRange = before ? [self rangeOfString:before] : NSMakeRange(0, 0);
    
    if (beforeRange.location == NSNotFound)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    
    CGFloat afterBeforeRangeStart = beforeRange.location + beforeRange.length;
    NSRange afterBeforeRange = NSMakeRange(afterBeforeRangeStart, self.length - afterBeforeRangeStart);
    NSRange afterRange = after ? [self rangeOfString:after options:0 range:afterBeforeRange] : NSMakeRange(NSNotFound, 0);
    
    if (afterRange.location == NSNotFound)
    {
        return afterBeforeRange;
    }
    
    return NSMakeRange(afterBeforeRangeStart, afterRange.location - afterBeforeRangeStart);
}
-(NSString*)getFragmentAfter:(NSString*)before andBefore:(NSString*)after
{
    NSRange range = [self rangeAfterString:before andBeforeString:after];
    if (range.location != NSNotFound) return [self substringWithRange:range];
    return nil;
}

-(NSNumber*)initialIntegerValue
{
    NSNumber* numberValue;
    
    @autoreleasepool
    {
        NSMutableString* originalString = [self mutableCopy];
        NSMutableString* newString = [NSMutableString stringWithString:@""];
        NSRange firstCharRange = NSMakeRange(0, 1);
        
        while (originalString.length > 0 && [originalString characterAtIndex:0] >= '0' && [originalString characterAtIndex:0] <= '9')
        {
            [newString appendString:[originalString substringWithRange:firstCharRange]];
            [originalString deleteCharactersInRange:firstCharRange];
        }
        
        if (newString.length > 0) numberValue = [[NSNumber alloc] initWithInt:newString.intValue];
    }
    
    return numberValue;
}

+(NSString*)stringWithContentsOfFile:(NSString*)file encoding:(NSStringEncoding)enc
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:file]) return nil;
    
    NSError* error;
    NSString* string = [self stringWithContentsOfFile:file encoding:enc error:&error];
    
    if (error)
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while reading file: %@",nil), error.localizedDescription]];
    }
    
    return string;
}
+(NSString*)stringWithContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)enc timeoutInterval:(long long int)timeoutInterval
{
    NSData* stringData = [NSData dataWithContentsOfURL:url timeoutInterval:timeoutInterval];
    
    if (!stringData)
    {
        return nil;
    }
    
    return [[NSString alloc] initWithData:stringData encoding:enc];
}

-(BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc
{
    NSError* error;
    BOOL created = [self writeToFile:path atomically:useAuxiliaryFile encoding:enc error:&error];
    
    if (error)
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while writting file: %@",nil), error.localizedDescription]];
    }
    
    return created;
}

-(BOOL)isAValidURL
{
    if (![self hasPrefix:@"http://"] && ![self hasPrefix:@"https://"] && ![self hasPrefix:@"ftp://"]) return false;
    
    NSURL *candidateURL = [NSURL URLWithString:self];
    return candidateURL && candidateURL.scheme && candidateURL.host;
}

@end
