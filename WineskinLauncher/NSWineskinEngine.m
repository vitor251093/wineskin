//
//  NSWineskinEngine.m
//  Porting Kit
//
//  Created by Vitor Marques de Miranda on 23/02/15.
//  Copyright (c) 2015 Vitor Marques de Miranda. All rights reserved.
//

#import "NSWineskinEngine.h"

#import "NSPortManager.h"
#import "NSPathUtilities.h"

#define MINIMUM_ENGINE_NAME_LENGTH 4

#define IDENTIFIER_PREFIX_LENGTH 2

#define DEFAULT_WINESKIN_ENGINE_IDENTIFIER @"WS"
#define DEFAULT_WINESKIN_ENGINE_VERSION    9

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
            VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.version withVersionString:wineskinEngine2.version];
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
            VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.version withVersionString:wineskinEngine2.version];
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
        
        VMMVersionCompare result = [VMMVersion compareVersionString:wineskinEngine1.version withVersionString:wineskinEngine2.version];
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
        wineskinEngine.version = nil;
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
        wineskinEngine.version = version;
        wineskinEngine.complement = [tempEngineString substringFromIndex:version.length];
    }
    else
    {
        wineskinEngine.version = @"";
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
    wineskinEngine.version = version;
    wineskinEngine.engineType = engineType;
    wineskinEngine.complement = complement ? complement : @"";
    wineskinEngine.is64Bit = is64Bit;
    wineskinEngine.engineVersion = DEFAULT_WINESKIN_ENGINE_VERSION;
    
    return wineskinEngine;
}
    
+(NSString*)getWineskinWrapperEngineFromVersionFileOfPortAtPath:(NSString*)path
{
    @autoreleasepool
    {
        NSString* wswineVersion = [NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle/version",path];
        if (![[NSFileManager defaultManager] regularFileExistsAtPath:wswineVersion])
        {
            NSString* wineskinEngineBundlePath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinEngine.bundle",path];
            if ([[NSFileManager defaultManager] fileExistsAtPath:wineskinEngineBundlePath])
            {
                NSString* bundleSymlinkDestination = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:wineskinEngineBundlePath];
                
                if (bundleSymlinkDestination != nil)
                {
                    return [[bundleSymlinkDestination lastPathComponent] stringByDeletingPathExtension];
                }
            }
            
            return nil;
        }
        
        NSString* version = [NSString stringWithContentsOfFile:wswineVersion encoding:NSASCIIStringEncoding];
        return [version getFragmentAfter:nil andBefore:@"\n"];
    }
}
+(NSString*)getWineskinWrapperEngineFromWineBinaryAtPath:(NSString*)wineBinaryPath
{
    @autoreleasepool
    {
        if (![[NSFileManager defaultManager] regularFileExistsAtPath:wineBinaryPath]) return nil;
        
        NSString* winelinePrefix = @"wine-";
        NSString* wineVersion = [NSTask runCommand:@[wineBinaryPath, @"--version"]];
        if (![wineVersion hasPrefix:winelinePrefix]) return nil;
        
        NSString* stagingString = [wineVersion getFragmentAfter:@"(" andBefore:@")"];
        BOOL isStaging = stagingString && [stagingString isEqualToString:@"Staging"];
        
        wineVersion = [wineVersion stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        wineVersion = [wineVersion substringFromIndex:winelinePrefix.length];
        
        NSUInteger stagingStringLength = stagingString.length + 3;
        if (isStaging) wineVersion = [wineVersion substringToIndex:wineVersion.length - stagingStringLength];
        
        return [NSWineskinEngine wineskinEngineOfType:isStaging ? NSWineskinEngineWineStaging : NSWineskinEngineWine is64Bit:NO
                                            ofVersion:wineVersion withComplement:nil].engineName;
    }
}
+(NSString*)getWineskinWrapperEngineFromInfFileAtPath:(NSString*)wineInfPath
{
    @autoreleasepool
    {
        if (![[NSFileManager defaultManager] regularFileExistsAtPath:wineInfPath]) return nil;
        
        NSArray* frags = [[NSString stringWithContentsOfFile:wineInfPath encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\n"];
        if (frags.count <= 1) return nil;
        
        NSString* newWrapperEngine = frags[1];
        if (![newWrapperEngine contains:@"Wine "]) return nil;
        
        newWrapperEngine = [newWrapperEngine getFragmentAfter:@"Wine " andBefore:@"\n"];
        return [NSWineskinEngine wineskinEngineOfType:NSWineskinEngineWine is64Bit:NO
                                            ofVersion:newWrapperEngine withComplement:nil].engineName;
    }
}
    
+(NSWineskinEngine*)wineskinEngineOfPortAtPath:(NSString*)path
{
    NSString* firstEngine = [self getWineskinWrapperEngineFromVersionFileOfPortAtPath:path];
    BOOL firstEngineExists = (firstEngine != nil);
    BOOL firstEngineIsDesirable = firstEngine ? [firstEngine matchesWithRegex:REGEX_VALID_WINESKIN_ENGINE] : false;
    
    if (firstEngineExists && firstEngineIsDesirable)
    {
        return [NSWineskinEngine wineskinEngineWithString:firstEngine];
    }
    
    NSString* WSConfigFilePath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinEngine.bundle/X11/WSConfig.txt",path];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:WSConfigFilePath])
    {
        NSString* engineText = [NSString stringWithContentsOfFile:WSConfigFilePath encoding:NSASCIIStringEncoding];
        engineText = [engineText getFragmentAfter:nil andBefore:@"\n"];
        if (engineText && engineText.length > 3)
        {
            return [NSWineskinEngine wineskinEngineWithString:engineText];
        }
    }
    
    NSString* binFolder = [NSPathUtilities wineBundleBinFolderForPortAtPath:path];
    NSString* wineBinaryPath = binFolder ? [NSString stringWithFormat:@"%@/wine",binFolder] : nil;
    NSString* secondEngine = wineBinaryPath ? [self getWineskinWrapperEngineFromWineBinaryAtPath:wineBinaryPath] : nil;
    BOOL secondEngineExists = (secondEngine != nil);
    
    if (secondEngineExists)
    {
        return [NSWineskinEngine wineskinEngineWithString:secondEngine];
    }
    
    NSString* shareFolder = [NSPathUtilities wineBundleShareFolderForPortAtPath:path];
    NSString* wineInfPath = shareFolder ? [NSString stringWithFormat:@"%@/wine/wine.inf",shareFolder] : nil;
    NSString* thirdEngine = wineInfPath ? [self getWineskinWrapperEngineFromInfFileAtPath:wineInfPath] : nil;
    BOOL thirdEngineExists = (thirdEngine != nil);
    
    if (thirdEngineExists)
    {
        return [NSWineskinEngine wineskinEngineWithString:thirdEngine];
    }
    
    if (firstEngineExists)
    {
        return [NSWineskinEngine wineskinEngineWithString:firstEngine];
    }
    
    return nil;
}


-(BOOL)isEngineVersionAtLeast:(NSString*)versionToCompare
{
    return [VMMVersion compareVersionString:self.version withVersionString:versionToCompare] != VMMVersionCompareSecondIsNewest;
}
-(NSString*)engineName
{
    if (!self.version) return self.complement;
    
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
                                                           engineTypeString, is64Bit, self.version, self.complement];
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
            
            return [self isEngineVersionAtLeast:@"12.0.0"];
            
        case NSWineskinEngineWineStaging:
            
            // The first Wine Staging version is based on Wine 1.7.7, so it always had Mac Driver
            // https://github.com/wine-compholio/wine-staging/releases?after=v1.7.9
            
            return true;
            
        case NSWineskinEngineWine:
            
            // Technically Mac Driver was created at 1.5.20, but only at 1.5.22 it became usable
            // https://www.winehq.org/announce/1.5.22
            
            return [self isEngineVersionAtLeast:@"1.5.22"];
            
        default:
            break;
    }
    
    return true;
}
-(BOOL)isMacDriverDefaultGraphics
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
            
            return [self isEngineVersionAtLeast:@"12.0.0"];
            
        case NSWineskinEngineWineStaging:
            
            // The first Wine Staging version is based on Wine 1.7.7, so it always had Mac Driver
            // https://github.com/wine-compholio/wine-staging/releases?after=v1.7.9
            
            return true;
            
        case NSWineskinEngineWine:
            
            // Since 1.5.28, MacDriver is default on Wine
            // https://wiki.winehq.org/MacOS_FAQ#How_do_I_switch_between_the_Mac.2FX11_drivers.3F
            
            return [self isEngineVersionAtLeast:@"1.5.28"];
            
        default:
            break;
    }
    
    return true;
}

@end
