//
//  NSWineskinEngine.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import "NSWineskinEngine.h"

#import "NSTask+Extension.h"
#import "NSAlert+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

#import "NSUtilities.h"
#import "NSWebUtilities.h"

@implementation NSWineskinEngine

+(NSComparisonResult)alphabeticalOrderOfFirstString:(NSString*)PK1 andSecondString:(NSString*)PK2
{
    for (int x = 0; x < PK1.length && x < PK2.length; x++)
    {
        if ([PK1 characterAtIndex:x] < [PK1 characterAtIndex:x]) return NSOrderedAscending;
        if ([PK1 characterAtIndex:x] > [PK1 characterAtIndex:x]) return NSOrderedDescending;
    }
    if (PK1.length > PK2.length) return NSOrderedDescending;
    if (PK1.length < PK2.length) return NSOrderedAscending;
    
    return NSOrderedSame;
}
+(NSComparisonResult)orderOfFirstWineskinEngine:(NSString*)PK1 andSecondWineskinEngine:(NSString*)PK2
{
    if ([PK1 hasPrefix:@"WS"] && [PK2 hasPrefix:@"WS"])
    {
        if (PK1.length > 7 && PK2.length > 7)
        {
            NSUInteger wineLocationPK1 = [PK1 rangeOfString:@"Wine"].location;
            NSUInteger wineLocationPK2 = [PK2 rangeOfString:@"Wine"].location;
            
            if (wineLocationPK1 != NSNotFound && wineLocationPK2 != NSNotFound)
            {
                NSString* noWinePK1 = [PK1 substringFromIndex:wineLocationPK1+4];
                NSString* noWinePK2 = [PK2 substringFromIndex:wineLocationPK2+4];
                
                BOOL isStagingPK1 = [noWinePK1 hasPrefix:@"Staging"];
                BOOL isStagingPK2 = [noWinePK2 hasPrefix:@"Staging"];
                
                if (isStagingPK1) noWinePK1 = [noWinePK1 substringFromIndex:7];
                if (isStagingPK2) noWinePK2 = [noWinePK2 substringFromIndex:7];
                
                BOOL is64BitPK1 = [noWinePK1 hasPrefix:@"64Bit"];
                BOOL is64BitPK2 = [noWinePK2 hasPrefix:@"64Bit"];
                
                if (is64BitPK1) noWinePK1 = [noWinePK1 substringFromIndex:5];
                if (is64BitPK2) noWinePK2 = [noWinePK2 substringFromIndex:5];
                
                BOOL noWinePK1StartsWithNumber = [[noWinePK1 substringToIndex:1] intValue] != 0;
                BOOL noWinePK2StartsWithNumber = [[noWinePK2 substringToIndex:1] intValue] != 0;
                
                if (noWinePK1StartsWithNumber && noWinePK2StartsWithNumber)
                {
                    NSComparisonResult result = [NSUtilities compareVersionString:noWinePK1 withVersionString:noWinePK2];
                    if (result == NSOrderedSame)
                    {
                        if ( is64BitPK1 && !is64BitPK2) return NSOrderedAscending;
                        if (!is64BitPK1 &&  is64BitPK2) return NSOrderedDescending;
                        
                        if ( isStagingPK1 && !isStagingPK2) return NSOrderedAscending;
                        if (!isStagingPK1 &&  isStagingPK2) return NSOrderedDescending;
                    }
                    return result;
                    
                }
                else if (noWinePK1StartsWithNumber) return NSOrderedAscending;
                else if (noWinePK2StartsWithNumber) return NSOrderedDescending;
                
                
                BOOL noWinePK1IsCrossOver = [noWinePK1 hasPrefix:@"CX"];
                BOOL noWinePK2IsCrossOver = [noWinePK2 hasPrefix:@"CX"];
                
                if (noWinePK1IsCrossOver && noWinePK2IsCrossOver)
                {
                    BOOL noWinePK1IsCrossOverGames = [[noWinePK1 substringFromIndex:2] hasPrefix:@"G"];
                    BOOL noWinePK2IsCrossOverGames = [[noWinePK2 substringFromIndex:2] hasPrefix:@"G"];
                    
                    if (noWinePK1IsCrossOverGames && noWinePK2IsCrossOverGames)
                    {
                        return [NSUtilities compareVersionString:[noWinePK1 substringFromIndex:3]
                                               withVersionString:[noWinePK2 substringFromIndex:3]];
                    }
                    else if (noWinePK1IsCrossOverGames) return NSOrderedDescending;
                    else if (noWinePK2IsCrossOverGames) return NSOrderedAscending;
                    
                    return [NSUtilities compareVersionString:[noWinePK1 substringFromIndex:2]
                                           withVersionString:[noWinePK2 substringFromIndex:2]];
                }
                else if (noWinePK1IsCrossOver) return NSOrderedAscending;
                else if (noWinePK2IsCrossOver) return NSOrderedDescending;
                
                NSComparisonResult result2 = [self alphabeticalOrderOfFirstString:noWinePK1 andSecondString:noWinePK2];
                if (result2 == NSOrderedSame)
                {
                    if ( is64BitPK1 && !is64BitPK2) return NSOrderedAscending;
                    if (!is64BitPK1 &&  is64BitPK2) return NSOrderedDescending;
                }
                
                return result2;
                
            }
            else if (wineLocationPK1 != NSNotFound) return NSOrderedAscending;
            else if (wineLocationPK2 != NSNotFound) return NSOrderedDescending;
        }
        else if (PK1.length > 7) return NSOrderedAscending;
        else if (PK2.length > 7) return NSOrderedDescending;
    }
    else if ([PK1 hasPrefix:@"WS"]) return NSOrderedAscending;
    else if ([PK2 hasPrefix:@"WS"]) return NSOrderedDescending;
    
    return [self alphabeticalOrderOfFirstString:PK1 andSecondString:PK2];
}
+(BOOL)isWineskinEngine:(NSString*)PK1 newestThanWineskinEngine:(NSString*)PK2
{
    return [self orderOfFirstWineskinEngine:PK1 andSecondWineskinEngine:PK2] == NSOrderedAscending;
}
+(BOOL)isWineskinEngine:(NSString*)PK1 oldestThanWineskinEngine:(NSString*)PK2
{
    return [self orderOfFirstWineskinEngine:PK1 andSecondWineskinEngine:PK2] == NSOrderedDescending;
}

+(NSMutableArray*)getListOfLocalEngines
{
    NSArray* validExtensions = EXTENSIONS_COMPATIBLE_WITH_7Z_AND_7ZA;
    NSMutableArray* list = [[NSMutableArray alloc] init];
    
    NSArray* fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:WINESKIN_LIBRARY_ENGINES_FOLDER];
    for (NSString* file in fileList)
    {
        if ([file hasPrefix:@"WS"] && file.length > 2)
        {
            NSRange wineRange = [file rangeOfString:@"Wine"];
            
            if (wineRange.location != NSNotFound)
            {
                NSString* newObject = [file substringFromIndex:wineRange.location];
                
                if (newObject.length > 4)
                {
                    while ([validExtensions containsObject:newObject.pathExtension])
                    {
                        newObject = newObject.stringByDeletingPathExtension;
                    }
                    newObject = [newObject substringFromIndex:4];
                    
                    if (newObject.length > 0)
                    {
                        newObject = file;
                        
                        while ([validExtensions containsObject:newObject.pathExtension])
                        {
                            newObject = newObject.stringByDeletingPathExtension;
                        }
                        
                        if (![list containsObject:newObject]) [list addObject:newObject];
                    }
                }
            }
        }
    }

    NSArray* wineskinEngines = [list sortedArrayUsingComparator:^NSComparisonResult(NSString* PK1, NSString* PK2)
    {
        return [self orderOfFirstWineskinEngine:PK1 andSecondWineskinEngine:PK2];
    }];
    
    return [wineskinEngines mutableCopy];
}

+(BOOL)isMacDriverCompatibleWithEngine:(NSString*)engineString
{
    if (!engineString) return true;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_GAMES_ENGINE]) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_ENGINE])
    {
        NSString* requiredCXVersion = @"WS9WineCX12.0.0";
        return [engineString isEqualToString:requiredCXVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredCXVersion];
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_STAGING_ENGINE]) return true;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_WINE_ENGINE])
    {
        NSString* requiredWineVersion = @"WS9Wine1.5.22";
        return [engineString isEqualToString:requiredWineVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredWineVersion];
    }
    
    return true;
}
+(BOOL)isCsmtCompatibleWithEngine:(NSString*)engineString
{
    if (!engineString) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_GAMES_ENGINE]) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_ENGINE])
    {
        NSString* requiredCXVersion = @"WS9WineCX13.0.0";
        return [engineString isEqualToString:requiredCXVersion] ||
        [self isWineskinEngine:engineString newestThanWineskinEngine:requiredCXVersion];
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_STAGING_ENGINE])
    {
        if ([self isWineskinEngine:engineString newestThanWineskinEngine:@"WS9WineStaging64Bit1.9.5"] &&
            [self isWineskinEngine:engineString oldestThanWineskinEngine:@"WS9WineStaging1.9.10"])
        {
            return false;
        }
        
        // TODO: Needs to check
        return true;
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_WINE_ENGINE])
    {
        NSString* requiredWineVersion = @"WS9Wine2.6";
        return [engineString isEqualToString:requiredWineVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredWineVersion];
    }
    
    return true;
}
+(BOOL)csmtUsesNewRegistryWithEngine:(NSString*)engineString
{
    if (!engineString) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_GAMES_ENGINE]) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_ENGINE]) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_STAGING_ENGINE])
    {
        // TODO: Needs to check
        return false;
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_WINE_ENGINE])
    {
        NSString* requiredWineVersion = @"WS9Wine2.6";
        return [engineString isEqualToString:requiredWineVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredWineVersion];
    }
    
    return true;
}
+(BOOL)isHighQualityModeCompatibleWithEngine:(NSString*)engineString
{
    if (!engineString) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_GAMES_ENGINE]) return false;
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_CROSSOVER_ENGINE])
    {
        NSString* requiredCXVersion = @"WS9WineCX15.0.0";
        return [engineString isEqualToString:requiredCXVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredCXVersion];
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_STAGING_ENGINE])
    {
        NSString* requiredWineVersion = @"WS9WineStaging1.9.10";
        return [engineString isEqualToString:requiredWineVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredWineVersion];
    }
    
    if ([engineString matchesWithRegex:REGEX_WINESKIN_WINE_ENGINE])
    {
        NSString* requiredWineVersion = @"WS9Wine1.9.10";
        return [engineString isEqualToString:requiredWineVersion] ||
               [self isWineskinEngine:engineString newestThanWineskinEngine:requiredWineVersion];
    }
    
    return true;
}

+(int)getWineskinMostRecentGenerationOfEngine:(NSString*)engine
{
    if (engine && [engine isKindOfClass:[NSString class]])
    {
        if ([engine matchesWithRegex:REGEX_WINESKIN_CROSSOVER_GAMES_ENGINE])
        {
            return 8;
        }
        
        if ([engine matchesWithRegex:REGEX_WINESKIN_CROSSOVER_ENGINE])
        {
            NSString* requiredCXVersion = @"WS9WineCX11.2.0";
            if (![engine isEqualToString:requiredCXVersion] &&
                [NSWineskinEngine isWineskinEngine:engine oldestThanWineskinEngine:requiredCXVersion])
            {
                return 8;
            }
        }
        
        if ([engine matchesWithRegex:REGEX_WINESKIN_STAGING_ENGINE])
        {
            return 9;
        }
        
        if ([engine matchesWithRegex:REGEX_WINESKIN_WINE_ENGINE])
        {
            NSString* exceptionWineVersion = @"WS9Wine1.4NoXInput2";
            NSString* requiredWineVersion = @"WS9Wine64Bit1.5.2";
            if (![engine isEqualToString:exceptionWineVersion] && ![engine isEqualToString:requiredWineVersion] &&
                [NSWineskinEngine isWineskinEngine:engine oldestThanWineskinEngine:requiredWineVersion])
            {
                return 8;
            }
        }
    }
    
    return 9;
}
+(NSString*)mostRecentVersionOfEngine:(NSString*)engine
{
    if ([engine matchesWithRegex:REGEX_WINESKIN_ENGINE] == false) return engine;
    
    int mostRecentGeneration = [self getWineskinMostRecentGenerationOfEngine:engine];
    
    NSUInteger wineLocationEngine = [engine rangeOfString:@"Wine"].location;
    NSString* versionOnlyEngine = [engine substringFromIndex:wineLocationEngine+4];
    
    return [NSString stringWithFormat:@"WS%dWine%@",mostRecentGeneration,versionOnlyEngine];
}

+(NSString*)localPathForEngine:(NSString*)engine
{
    NSString* engineFile;
    
    for (NSString* engineValidExtension in [EXTENSIONS_COMPATIBLE_WITH_7Z_AND_7ZA arrayByAddingObject:@"tar.7z"])
    {
        engineFile = [NSString stringWithFormat:@"%@/%@.%@",WINESKIN_LIBRARY_ENGINES_FOLDER,engine,engineValidExtension];
        if ([[NSFileManager defaultManager] regularFileExistsAtPath:engineFile])
        {
            return engineFile;
        }
    }
    
    return nil;
}

@end
