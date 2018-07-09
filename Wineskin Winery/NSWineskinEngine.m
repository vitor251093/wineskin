//
//  NSWineskinEngine.m
//  Porting Kit
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import "NSWineskinEngine.h"

//#import "NSFileManager+Compression.h"

//#import "NSPathUtilities.h"

//#import "NSWebUtilities.h"

#define MINIMUM_ENGINE_NAME_LENGTH 4

#define IDENTIFIER_PREFIX_LENGTH 2

#define DEFAULT_WINESKIN_ENGINE_IDENTIFIER @"WS"
#define DEFAULT_WINESKIN_ENGINE_VERSION    9

#define WINESKIN_LIBRARY_ENGINES_FOLDER [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines",NSHomeDirectory()]

static NSString *const REGEX_VALID_WINESKIN_ENGINE =                 @"[A-Z]{2}[0-9]+Wine(CX|CXG|Staging)?(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_WINE_ENGINE =            @"[A-Z]{2}[0-9]+Wine(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_STAGING_ENGINE =         @"[A-Z]{2}[0-9]+WineStaging(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_CROSSOVER_ENGINE =       @"[A-Z]{2}[0-9]+WineCX(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINESKIN_CROSSOVER_GAMES_ENGINE = @"[A-Z]{2}[0-9]+WineCXG(64Bit)?[0-9\\.]+[^\\n]*";
static NSString *const REGEX_VALID_WINE_VERSION =                    @"[0-9]+(\\.[0-9]+)*([-\\.]{1}rc[0-9]+)?";

@implementation NSWineskinEngine

+(NSComparisonResult)alphabeticalOrderOfFirstString:(NSString*)PK1 andSecondString:(NSString*)PK2
{
    if (PK1.length == 0) return NSOrderedDescending;
    if (PK2.length == 0) return NSOrderedAscending;
    
    for (int x = 0; x < PK1.length && x < PK2.length; x++)
    {
        if ([PK1 characterAtIndex:x] < [PK1 characterAtIndex:x]) return NSOrderedAscending;
        if ([PK1 characterAtIndex:x] > [PK1 characterAtIndex:x]) return NSOrderedDescending;
    }
    if (PK1.length > PK2.length) return NSOrderedDescending;
    if (PK1.length < PK2.length) return NSOrderedAscending;
    
    return NSOrderedSame;
}
+(NSComparisonResult)orderOfFirstWineskinEngine:(NSWineskinEngine*)wineskinEngine1 andSecondWineskinEngine:(NSWineskinEngine*)wineskinEngine2
{
    if (wineskinEngine1.engineVersion > wineskinEngine2.engineVersion) return NSOrderedAscending;
    if (wineskinEngine1.engineVersion < wineskinEngine2.engineVersion) return NSOrderedDescending;
    
    BOOL wineskinEngineValidType1 = wineskinEngine1.engineType != NSWineskinEngineOther;
    BOOL wineskinEngineValidType2 = wineskinEngine2.engineType != NSWineskinEngineOther;
    
    if (wineskinEngineValidType1 && wineskinEngineValidType2)
    {
        // At this point: Wine, Staging, CrossOver and CrossOver Games
        
        BOOL wineskinEngineIsNotCrossOver1 = (wineskinEngine1.engineType == NSWineskinEngineWine ||
                                              wineskinEngine1.engineType == NSWineskinEngineWineStaging);
        BOOL wineskinEngineIsNotCrossOver2 = (wineskinEngine2.engineType == NSWineskinEngineWine ||
                                              wineskinEngine2.engineType == NSWineskinEngineWineStaging);
        
        if (wineskinEngineIsNotCrossOver1 && wineskinEngineIsNotCrossOver2)
        {
            VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.wineVersion
                                                      withVersionString:wineskinEngine2.wineVersion];
            if (result == VMMVersionCompareSame)
            {
                if (wineskinEngine1.engineType == NSWineskinEngineWineStaging &&
                    wineskinEngine2.engineType != NSWineskinEngineWineStaging) return NSOrderedAscending;
                
                if (wineskinEngine1.engineType != NSWineskinEngineWineStaging &&
                    wineskinEngine2.engineType == NSWineskinEngineWineStaging) return NSOrderedDescending;
                
                if ( wineskinEngine1.is64Bit && !wineskinEngine2.is64Bit) return NSOrderedAscending;
                if (!wineskinEngine1.is64Bit &&  wineskinEngine2.is64Bit) return NSOrderedDescending;
                
                return [self alphabeticalOrderOfFirstString:wineskinEngine1.complement andSecondString:wineskinEngine2.complement];
            }
            return (result == VMMVersionCompareSecondIsNewest) ? NSOrderedDescending : NSOrderedAscending;
        }
        else if (wineskinEngineIsNotCrossOver1) return NSOrderedAscending;
        else if (wineskinEngineIsNotCrossOver2) return NSOrderedDescending;
        
        
        // At this point: CrossOver and CrossOver Games
        
        if (wineskinEngine1.engineType == NSWineskinEngineCrossOver && wineskinEngine2.engineType == NSWineskinEngineCrossOver)
        {
            VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.wineVersion
                                                      withVersionString:wineskinEngine2.wineVersion];
            if (result == VMMVersionCompareSame)
            {
                if ( wineskinEngine1.is64Bit && !wineskinEngine2.is64Bit) return NSOrderedAscending;
                if (!wineskinEngine1.is64Bit &&  wineskinEngine2.is64Bit) return NSOrderedDescending;
                
                return [self alphabeticalOrderOfFirstString:wineskinEngine1.complement andSecondString:wineskinEngine2.complement];
            }
            return (result == VMMVersionCompareSecondIsNewest) ? NSOrderedDescending : NSOrderedAscending;
        }
        else if (wineskinEngine1.engineType == NSWineskinEngineCrossOver) return NSOrderedAscending;
        else if (wineskinEngine2.engineType == NSWineskinEngineCrossOver) return NSOrderedDescending;
        
        
        // At this point: CrossOver Games
        
        VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.wineVersion
                                                  withVersionString:wineskinEngine2.wineVersion];
        if (result == VMMVersionCompareSame)
        {
            if ( wineskinEngine1.is64Bit && !wineskinEngine2.is64Bit) return NSOrderedAscending;
            if (!wineskinEngine1.is64Bit &&  wineskinEngine2.is64Bit) return NSOrderedDescending;
            
            return [self alphabeticalOrderOfFirstString:wineskinEngine1.complement andSecondString:wineskinEngine2.complement];
        }
        return (result == VMMVersionCompareSecondIsNewest) ? NSOrderedDescending : NSOrderedAscending;
    }
    else if (wineskinEngineValidType1) return NSOrderedAscending;
    else if (wineskinEngineValidType2) return NSOrderedDescending;
    
    return [self alphabeticalOrderOfFirstString:wineskinEngine1.complement andSecondString:wineskinEngine2.complement];
}

+(NSMutableArray*)getListOfAvailableEnginesOffline
{
    NSString* supportedExtension = @".tar.7z";
    NSMutableArray* list = [[NSMutableArray alloc] init];
    
    NSArray* fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:WINESKIN_LIBRARY_ENGINES_FOLDER];
    for (NSString* file in fileList)
    {
        if (file.length > IDENTIFIER_PREFIX_LENGTH)
        {
            NSRange wineRange = [file rangeOfString:@"Wine"];
            
            if (wineRange.location != NSNotFound)
            {
                NSString* newObject = [file substringFromIndex:wineRange.location];
                
                if (newObject.length > wineRange.length)
                {
                    if ([newObject hasSuffix:supportedExtension])
                    {
                        newObject = [newObject substringToIndex:newObject.length - supportedExtension.length];
                    }
                    newObject = [newObject substringFromIndex:wineRange.length];
                    
                    if (newObject.length > 0)
                    {
                        newObject = file;
                        
                        if ([newObject hasSuffix:supportedExtension])
                        {
                            newObject = [newObject substringToIndex:newObject.length - supportedExtension.length];
                        }
                        
                        if (![list containsObject:newObject]) [list addObject:newObject];
                    }
                }
            }
        }
    }
    
    return list;
}
+(NSMutableArray<NSWineskinEngine*>*)getListOfAvailableEngines
{
    NSMutableArray* wineskinEngines;
    
    @autoreleasepool
    {
        wineskinEngines = [self getListOfAvailableEnginesOffline];
        wineskinEngines = [[wineskinEngines arrayByRemovingRepetitions] mutableCopy];
        
        [wineskinEngines replaceObjectsWithVariation:^NSWineskinEngine*(NSString* object, NSUInteger index)
        {
            return [NSWineskinEngine wineskinEngineWithString:object];
        }];
        
        [wineskinEngines sortUsingComparator:^NSComparisonResult(NSWineskinEngine* obj1, NSWineskinEngine* obj2)
        {
            if ([obj1 isKindOfClass:[NSWineskinEngine class]] && [obj2 isKindOfClass:[NSWineskinEngine class]])
            {
                return [self orderOfFirstWineskinEngine:obj1 andSecondWineskinEngine:obj2];
            }
            if ([obj1 isKindOfClass:[NSWineskinEngine class]])
            {
                return NSOrderedAscending;
            }
            if ([obj2 isKindOfClass:[NSWineskinEngine class]])
            {
                return NSOrderedDescending;
            }
             
            return NSOrderedSame;
        }];
        
        [wineskinEngines replaceObjectsWithVariation:^NSWineskinEngine*(NSWineskinEngine* object, NSUInteger index)
        {
            if ([object isKindOfClass:[NSWineskinEngine class]] == false)
            {
                return nil;
            }
             
            return object;
        }];
        
        [wineskinEngines removeObject:[NSNull null]];
    }
    
    return wineskinEngines;
}

+(NSString*)wineskinVersionFromWineskinEngineNameFinal:(NSString*)tempEngineString
{
    if (IsClassNSRegularExpressionAvailable)
    {
        NSArray* tempEngineStringVersions = [tempEngineString componentsMatchingWithRegex:REGEX_VALID_WINE_VERSION];
        NSString* version = tempEngineStringVersions.firstObject;
        if (!version || ![tempEngineString hasPrefix:version]) return nil;
        return version;
    }
    
    NSMutableArray* versionComponents = [[NSMutableArray alloc] init];
    NSNumber* versionNumber = [tempEngineString initialIntegerValue];
    NSString* versionNumberString;
    
    while (versionNumber)
    {
        versionNumberString = [NSString stringWithFormat:@"%d",versionNumber.intValue];
        tempEngineString = [tempEngineString substringFromIndex:versionNumberString.length];
        [versionComponents addObject:versionNumberString];
        
        if ([tempEngineString hasPrefix:@"."])
        {
            tempEngineString = [tempEngineString substringFromIndex:1];
        }
        else
        {
            break;
        }
        
        versionNumber = [tempEngineString initialIntegerValue];
    }
    
    if (versionComponents.count == 0) return nil;
    NSString* version = [versionComponents componentsJoinedByString:@"."];
    
    if ([tempEngineString.lowercaseString hasPrefix:@"-rc"] || [tempEngineString.lowercaseString hasPrefix:@".rc"])
    {
        version = [version stringByAppendingString:[tempEngineString substringToIndex:3]];
        tempEngineString = [tempEngineString substringFromIndex:3];
        
        versionNumber = [tempEngineString initialIntegerValue];
        if (versionNumber != nil)
        {
            versionNumberString = [NSString stringWithFormat:@"%d",versionNumber.intValue];
            version = [version stringByAppendingString:versionNumberString];
        }
    }
    
    return version;
}
+(NSWineskinEngine*)wineskinEngineWithString:(NSString*)engineString
{
    if (!engineString || engineString.length < MINIMUM_ENGINE_NAME_LENGTH) return nil;
    
    NSWineskinEngine* wineskinEngine = [[NSWineskinEngine alloc] init];
    
    if (![engineString matchesWithRegex:REGEX_VALID_WINESKIN_ENGINE])
    {
        wineskinEngine.engineIdentifier = nil;
        wineskinEngine.engineVersion = 0;
        wineskinEngine.wineVersion = nil;
        wineskinEngine.engineType = NSWineskinEngineOther;
        wineskinEngine.complement = engineString;
        wineskinEngine.is64Bit = false;
        return wineskinEngine;
    }
    
    wineskinEngine.engineType = NSWineskinEngineOther;
    if ([engineString matchesWithRegex:REGEX_VALID_WINESKIN_WINE_ENGINE])            wineskinEngine.engineType = NSWineskinEngineWine;
    if ([engineString matchesWithRegex:REGEX_VALID_WINESKIN_STAGING_ENGINE])         wineskinEngine.engineType = NSWineskinEngineWineStaging;
    if ([engineString matchesWithRegex:REGEX_VALID_WINESKIN_CROSSOVER_ENGINE])       wineskinEngine.engineType = NSWineskinEngineCrossOver;
    if ([engineString matchesWithRegex:REGEX_VALID_WINESKIN_CROSSOVER_GAMES_ENGINE]) wineskinEngine.engineType = NSWineskinEngineCrossOverGames;
    
    NSRange wineWordRange = [engineString rangeOfString:@"Wine"];
    NSString* tempEngineString = [engineString substringFromIndex:wineWordRange.location + wineWordRange.length];
    
    switch (wineskinEngine.engineType)
    {
        case NSWineskinEngineWineStaging:
            tempEngineString = [tempEngineString substringFromIndex:7];
            break;
            
        case NSWineskinEngineCrossOver:
            tempEngineString = [tempEngineString substringFromIndex:2];
            break;
            
        case NSWineskinEngineCrossOverGames:
            tempEngineString = [tempEngineString substringFromIndex:3];
            break;
            
        default:
            break;
    }
    
    NSString* component64Bit = @"64Bit";
    wineskinEngine.is64Bit = [tempEngineString hasPrefix:component64Bit];
    if (wineskinEngine.is64Bit) tempEngineString = [tempEngineString substringFromIndex:component64Bit.length];
    
    NSString* version = [self wineskinVersionFromWineskinEngineNameFinal:tempEngineString];
    if (version && [tempEngineString hasPrefix:version])
    {
        wineskinEngine.wineVersion = version;
        wineskinEngine.complement = [tempEngineString substringFromIndex:version.length];
    }
    else
    {
        wineskinEngine.wineVersion = @"";
        wineskinEngine.complement = tempEngineString;
    }
    
    wineskinEngine.engineIdentifier = [engineString substringToIndex:IDENTIFIER_PREFIX_LENGTH];
    
    tempEngineString = [engineString substringWithRange:NSMakeRange(IDENTIFIER_PREFIX_LENGTH,
                                                                    wineWordRange.location - IDENTIFIER_PREFIX_LENGTH)];
    wineskinEngine.engineVersion = tempEngineString.intValue;
    
    return wineskinEngine;
}

+(NSWineskinEngine*)wineskinEngineOfType:(NSWineskinEngineType)engineType is64Bit:(BOOL)is64Bit ofVersion:(NSString*)version withComplement:(NSString*)complement
{
    NSWineskinEngine* wineskinEngine = [[NSWineskinEngine alloc] init];
    
    if (!version || ![version matchesWithRegex:REGEX_VALID_WINE_VERSION])
    {
        return nil;
    }
    
    wineskinEngine.engineIdentifier = DEFAULT_WINESKIN_ENGINE_IDENTIFIER;
    wineskinEngine.engineVersion = 0;
    wineskinEngine.wineVersion = version;
    wineskinEngine.engineType = engineType;
    wineskinEngine.complement = complement ? complement : @"";
    wineskinEngine.is64Bit = is64Bit;
    
    NSString* halfOfTheEngineName = [wineskinEngine.engineName substringFromIndex:IDENTIFIER_PREFIX_LENGTH + 1];
    for (NSString* engineName in [self getListOfAvailableEngines])
    {
        if ([engineName hasSuffix:halfOfTheEngineName])
        {
            NSString* firstHalf = [engineName substringToIndex:engineName.length - halfOfTheEngineName.length];
            NSString* engineVersion = [firstHalf substringFromIndex:IDENTIFIER_PREFIX_LENGTH];
            if (engineVersion.intValue != 0)
            {
                wineskinEngine.engineIdentifier = [firstHalf substringToIndex:IDENTIFIER_PREFIX_LENGTH];
                wineskinEngine.engineVersion = engineVersion.intValue;
                break;
            }
        }
    }
    
    if (wineskinEngine.engineVersion == 0)
    {
        wineskinEngine.engineVersion = DEFAULT_WINESKIN_ENGINE_VERSION;
    }
    
    return wineskinEngine;
}


-(BOOL)isWineVersionAtLeast:(NSString*)versionToCompare
{
    return [VMMVersion compareVersionString:self.wineVersion withVersionString:versionToCompare] != VMMVersionCompareSecondIsNewest;
}
-(NSString*)engineName
{
    if (!self.wineVersion) return self.complement;
    
    NSString* is64Bit = self.is64Bit ? @"64Bit" : @"";
    NSString* engineTypeString = @"";
    int wineskinEngineVersion = self.engineVersion;
    
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            engineTypeString = @"CXG";
            break;
            
        case NSWineskinEngineCrossOver:
            engineTypeString = @"CX";
            break;
            
        case NSWineskinEngineWineStaging:
            engineTypeString = @"Staging";
            break;
            
        case NSWineskinEngineWine:
            break;
            
        default:
            break;
    }
    
    return [NSString stringWithFormat:@"%@%dWine%@%@%@%@", self.engineIdentifier, wineskinEngineVersion,
            engineTypeString, is64Bit, self.wineVersion, self.complement];
}

-(NSString*)localPath
{
    return [NSWineskinEngine localPathForEngine:self.engineName];
}

-(BOOL)isCompatibleWithMacDriver
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before Mac Driver existed
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            return false;
            
        case NSWineskinEngineCrossOver:
            
            // Even been based in Wine 1.5.15, CrossOver uses its own Mac Driver implementation since that version
            // https://www.codeweavers.com/products/more-information/changelog#12.0.0
            
            return [self isWineVersionAtLeast:@"12.0.0"];
            
        case NSWineskinEngineWineStaging:
            
            // The first Wine Staging version is based on Wine 1.7.7, so it always had Mac Driver
            // https://github.com/wine-compholio/wine-staging/releases?after=v1.7.9
            
            return true;
            
        case NSWineskinEngineWine:
            
            // Technically Mac Driver was created at 1.5.20, but only at 1.5.22 it became usable
            // https://www.winehq.org/announce/1.5.22
            
            return [self isWineVersionAtLeast:@"1.5.22"];
            
        default:
            break;
    }
    
    return true;
}
-(BOOL)isCompatibleWithCsmt
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before CSMT existed
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            return false;
            
        case NSWineskinEngineCrossOver:
            
            // Called 'Performance Enhanced Graphics' by CrossOver, but it's the same thing
            // https://www.codeweavers.com/products/more-information/changelog#13.0.0
            
            return [self isWineVersionAtLeast:@"13.0.0"];
            
        case NSWineskinEngineWineStaging:
            
            // Staging added CSMT in the 1.7.33 version
            // https://wine-staging.com/news/2014-12-15-release-1.7.33.html
            
            if (![self isWineVersionAtLeast:@"1.7.33"]) return false;
            
            
            // Staging disabled CSMT between 1.9.6 and 1.9.9
            // https://wine-staging.com/news/2016-03-21-release-1.9.6.html
            // https://wine-staging.com/news/2016-05-18-release-1.9.10.html
            
            if ([self isWineVersionAtLeast:@"1.9.6"] && ![self isWineVersionAtLeast:@"1.9.10"]) return false;
            return true;
            
        case NSWineskinEngineWine:
            
            // CSMT was added to Wine in the 2.6 version
            // https://www.winehq.org/news/2017041301
            
            return [self isWineVersionAtLeast:@"2.6"];
            
        default:
            break;
    }
    
    return true;
}
-(BOOL)csmtUsesNewRegistry
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before CSMT existed
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            return false;
            
        case NSWineskinEngineCrossOver:
            
            // As of 2017-10-02 (CX 16.2.5), CX last merge with Wine was with Wine 2.0, so it doesn't have Wine's CSMT,
            // but Wine's CSMT may have came from CrossOver, so CrossOver CSMT possibly always had the new registry.
            // TODO: Needs to check, and might change in the future in case 'false'
            
            return false;
            
        case NSWineskinEngineWineStaging:
            
            // Technically, Staging CSMT should have been replaced by Wine's in 1.9.10
            // TODO: Needs to check
            
            return [self isWineVersionAtLeast:@"1.9.10"];
            
        case NSWineskinEngineWine:
            
            // CSMT was added to Wine in the 2.6 version, and it always used it in that way
            // https://www.winehq.org/news/2017041301
            
            return [self isWineVersionAtLeast:@"2.6"];
            
        default:
            break;
    }
    
    return true;
}
-(BOOL)isCompatibleWithHighQualityMode
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before the retina mode existed
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            return false;
            
        case NSWineskinEngineCrossOver:
            
            // Even been based in Wine 1.8, CrossOver 15.0.0 included its own retina support
            // https://www.codeweavers.com/products/more-information/changelog#15.0.0
            
            return [self isWineVersionAtLeast:@"15.0.0"];
            
        case NSWineskinEngineWineStaging:
        case NSWineskinEngineWine:
            
            // Wine added that feature in 1.9.10, and Staging received it since then
            // https://www.winehq.org/news/2016051701
            
            return [self isWineVersionAtLeast:@"1.9.10"];
            
        default:
            break;
    }
    
    return true;
}
-(BOOL)isCompatibleWith16Bit
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before 16 bit stopped working
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            return true;
            
        case NSWineskinEngineCrossOver:
            
            // Starting by 12.5.0, CrossOver merged itself with Wine 1.6, so 16 bit should have stopped working
            // https://www.codeweavers.com/products/more-information/changelog#12.5.0
            
            return [self isWineVersionAtLeast:@"12.5.0"] == false;
            
        case NSWineskinEngineWineStaging:
            
            // The first Wine Staging version is based on Wine 1.7.7, so it never had 16-bit compatibility
            // https://github.com/wine-compholio/wine-staging/releases?after=v1.7.9
            
            return false;
            
        case NSWineskinEngineWine:
            
            // That feature stopped working after Wine 1.5.20 in Wineskin
            // TODO: Needs reference
            
            return [self isWineVersionAtLeast:@"1.5.21"] == false;
            
        default:
            break;
    }
    
    return true;
}

-(BOOL)isCompatibleWithSteam
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            
            // The last CrossOver Games version was released before the Steam update of July 2016
            // https://www.codeweavers.com/products/more-information/changelog#10.3.0
            
            break;
            
        case NSWineskinEngineCrossOver:
            
            // Starting by 16.2.5, CrossOver added the fix to the Steam update of July 2016 bug
            // https://www.codeweavers.com/products/more-information/changelog#16.2.5
            
            if ([self isWineVersionAtLeast:@"16.2.5"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineWineStaging:
            
            // This is the first Wine Staging version to implement the bug fix to the Steam update of July 2016
            // https://www.wine-staging.com/news/2017-07-12-release-2.12.html
            
            if ([self isWineVersionAtLeast:@"2.12"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineWine:
            
            // This is the first vanilla Wine version to implement the bug fix to the Steam update of July 2016
            // https://www.winehq.org/announce/2.13
            
            if ([self isWineVersionAtLeast:@"2.13"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineOther:
            return true;
            
        default:
            break;
    }
    
    // The engine may be patched with the Steam fix
    return [self.complement.lowercaseString contains:@"steam"];
}
-(BOOL)isCompatibleWithOrigin
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            break;
            
        case NSWineskinEngineCrossOver:
            break;
            
        case NSWineskinEngineWineStaging:
            if ([self isWineVersionAtLeast:@"2.6"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineWine:
            break;
            
        default:
            break;
    }
    
    return false;
}
-(BOOL)isCompatibleWithUplay
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            break;
            
        case NSWineskinEngineCrossOver:
            break;
            
        case NSWineskinEngineWineStaging:
            if ([self isWineVersionAtLeast:@"2.6"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineWine:
            break;
            
        default:
            break;
    }
    
    return false;
}
-(BOOL)isCompatibleWithGOGGalaxy
{
    switch (self.engineType)
    {
        case NSWineskinEngineCrossOverGames:
            break;
            
        case NSWineskinEngineCrossOver:
            break;
            
        case NSWineskinEngineWineStaging:
            if ([self isWineVersionAtLeast:@"2.16"])
            {
                return true;
            }
            break;
            
        case NSWineskinEngineWine:
            if ([self isWineVersionAtLeast:@"2.16"])
            {
                return true;
            }
            break;
            
        default:
            break;
    }
    
    return false;
}


+(NSString*)localPathForEngine:(NSString*)engine
{
    NSArray* validExtensions = @[@"tar.7z"];
    NSArray* enginesList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:WINESKIN_LIBRARY_ENGINES_FOLDER];
    
    for (NSString* engineFileName in enginesList)
    {
        if ([engineFileName hasPrefix:[engine stringByAppendingString:@"."]])
        {
            NSString* engineFileNameNoExtension = engineFileName;
            
            while ([engineFileNameNoExtension pathExtension])
            {
                if ([validExtensions containsObject:engineFileNameNoExtension.pathExtension.lowercaseString])
                {
                    engineFileNameNoExtension = engineFileNameNoExtension.stringByDeletingPathExtension;
                }
                else
                {
                    break;
                }
            }
            
            if ([engine isEqualToString:engineFileNameNoExtension])
            {
                return [NSString stringWithFormat:@"%@/%@",WINESKIN_LIBRARY_ENGINES_FOLDER,engineFileName];
            }
        }
    }
    
    return nil;
}

@end
