//
//  NSPortManager.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 01/09/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPortManager.h"

#import "NSPathUtilities.h"

#import "NSData+Extension.h"
#import "NSTask+Extension.h"
#import "NSImage+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"
#import "NSMutableDictionary+Extension.h"

#define SMALLER_ICONSET_NEEDED_SIZE 16
#define BIGGEST_ICONSET_NEEDED_SIZE 1024

#define TIFF2ICNS_ICON_SIZE 512

@implementation NSMutableString (PKMutableString)

- (void)replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement
{
    [self replaceOccurrencesOfString:target withString:replacement options:0 range:NSMakeRange(0, self.length)];
}

@end

@implementation NSPortManager

+(NSPortManager*)managerWithPath:(NSString*)path
{
    if (!path || ![path hasSuffix:@".app"]) return nil;
    
    NSPortManager* portManager = [[NSPortManager alloc] init];
    
    portManager.path = path;
    portManager.isCustomEXE = NO;
    
    NSString* plistPath = [NSString stringWithFormat:@"%@%@",path,PLIST_PATH_WINESKIN_WRAPPER];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:plistPath])
    {
        portManager.plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:plistPath];
    }
    
    NSString* x11plistPath = [NSString stringWithFormat:@"%@/Contents/Resources/WSX11Prefs.plist",path];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:x11plistPath])
    {
        portManager.x11Plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:x11plistPath];
    }
    else
    {
        x11plistPath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinEngine.bundle/X11/WSX11Prefs.plist",path];
        if (![[NSFileManager defaultManager] regularFileExistsAtPath:x11plistPath])
        {
            portManager.x11Plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:x11plistPath];
        }
    }
    
    return portManager;
}
+(NSPortManager*)managerWithCustomExePath:(NSString*)path
{
    NSPortManager* portManager = [[NSPortManager alloc] init];
    
    portManager.path = path;
    portManager.isCustomEXE = YES;
    
    NSString* plistPath = [NSString stringWithFormat:@"%@%@",path,PLIST_PATH_WINESKIN_CUSTOM_EXE];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:plistPath])
        portManager.plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:plistPath];
    
    return portManager;
}

-(id)plistObjectForKey:(NSString*)item
{
    return _plist ? _plist[item] : nil;
}
-(void)setPlistObject:(id)object forKey:(NSString*)item
{
    if (_plist)
    {
        if (object)
             [_plist setObject:object forKey:item];
        else [_plist removeObjectForKey:item];
    }
}
-(void)synchronizePlist
{
    if (_plist)
    {
        if (_isCustomEXE)
             [_plist writeToFile:[NSString stringWithFormat:@"%@%@",self.path,PLIST_PATH_WINESKIN_CUSTOM_EXE] atomically:YES];
        else [_plist writeToFile:[NSString stringWithFormat:@"%@%@",self.path,PLIST_PATH_WINESKIN_WRAPPER]    atomically:YES];
    }
}

-(id)x11PlistObjectForKey:(NSString*)item
{
    return _x11Plist ? _x11Plist[item] : nil;
}
-(void)setX11PlistObject:(id)object forKey:(NSString*)item
{
    if (_x11Plist) [_x11Plist setObject:object forKey:item];
}
-(void)synchronizeX11Plist
{
    if (_x11Plist) [_x11Plist writeToFile:[NSString stringWithFormat:@"%@/Contents/Resources/WSX11Prefs.plist",self.path] atomically:YES];
}

-(void)setIconWithImage:(NSImage*)sourceImage
{
    if (!sourceImage) return;
    
    NSString* icnsFileName = [self plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ICON_PATH];
    if (!icnsFileName) return;
    
    NSString* icnsPath = [NSString stringWithFormat:@"%@/Contents/Resources/%@",self.path,icnsFileName];
    BOOL result = [sourceImage saveAsIcnsAtPath:icnsPath];
    
    if (result)
    {
        [[NSWorkspace sharedWorkspace] setIcon:nil forFile:self.path options:NSExcludeQuickDrawElementsIconCreationOption];
    }
    else
    {
        [[NSWorkspace sharedWorkspace] setIcon:sourceImage forFile:self.path options:NSExcludeQuickDrawElementsIconCreationOption];
    }
}

-(NSString*)runWithArguments:(NSArray*)args
{
    NSString* appPath = [NSPathUtilities wineskinFrameworkBinForPortAtPath:self.path];
    return [NSTask runProgram:appPath atRunPath:nil withFlags:args wait:YES];
}
-(NSString*)installWinetrick:(NSString*)winetrick
{
    if (!winetrick) return false;
    [self runWithArguments:@[@"WSS-winetricks",winetrick]];
    
    NSString* logPath = [NSString stringWithFormat:@"%@/Contents/Resources/Logs/Winetricks.log",self.path];
    NSString* log = [NSString stringWithContentsOfFile:logPath encoding:NSASCIIStringEncoding];
    return log;
}

-(NSString*)runEXE:(NSString*)installerFile withFlags:(NSString*)flags
{
    NSString* fileToRun;
    NSString* installerFileWindowsPath;
    
    if ([installerFile hasPrefix:@"/"])
    {
        installerFileWindowsPath = [NSPathUtilities getWindowsPathForMacPath:installerFile ofWrapper:self.path];
    }
    else
    {
        installerFileWindowsPath = installerFile;
    }
    
    installerFileWindowsPath = [installerFileWindowsPath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    
    // Using the 'start' application will make the cmd window disappear
    NSString* batFileContent = [NSString stringWithFormat:@"start \"%@\" %@",installerFileWindowsPath,flags];
    
    // Choosing bat path and saving
    NSString* batFileLocation;
    for (int x = 0; batFileLocation == nil; x++)
    {
        batFileLocation = [NSPathUtilities getMacPathForWindowsPath:[NSString stringWithFormat:@"C:/wineskinTemp%d.bat",x]
                                                          ofWrapper:self.path];
        if ([[NSFileManager defaultManager] regularFileExistsAtPath:batFileLocation]) batFileLocation = nil;
    }
    
    [batFileContent writeToFile:batFileLocation atomically:YES encoding:NSASCIIStringEncoding];
    
    fileToRun = batFileLocation;
    
    
    // Running file
    //[self setPlistObject:@TRUE forKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE];
    //[self synchronizePlist];
    
    NSDebugLog(@"Running %@ in %@",batFileContent,self.path);
    NSString* log = [self runWithArguments:@[@"WSS-installer",fileToRun]];
    
    //[self setPlistObject:nil forKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE];
    //[self synchronizePlist];
    
    
    // Removing bat file
    [[NSFileManager defaultManager] removeItemAtPath:fileToRun];
    
    return log;
}

-(void)addToPortCreationLog:(NSString*)newLogs
{
    if (!newLogs) return;
    
    NSString* logPath = [NSString stringWithFormat:@"%@/Contents/Resources/install.log",self.path];
    NSString* log = [NSString stringWithContentsOfFile:logPath encoding:NSASCIIStringEncoding];
    
    if (!log) log = @"";
    else log = [log stringByAppendingString:@"\n\n\n\n\n"];
    
    log = [log stringByAppendingString:newLogs];
    
    [log writeToFile:logPath atomically:YES encoding:NSASCIIStringEncoding];
}

// Get available Winetricks list
-(NSString*)getFieldValue:(NSString*)field fromDescription:(NSString*)description
{
    field = [NSString stringWithFormat:@"%@=\"",field];
    return [description getFragmentAfter:field andBefore:@"\""];
}
-(NSMutableDictionary*)getFunctionFromDescription:(NSString*)description
{
    NSMutableDictionary* newFunction = [[NSMutableDictionary alloc] init];
    
    while ([description hasPrefix:@" "]) description = [description substringFromIndex:1];
    NSString* base = [description getFragmentAfter:@" " andBefore:@"\\\n"];
    newFunction[@"Type"] = base ? base : @"";
    
    description = [NSString stringWithFormat:@" %@",description];
    base = [description getFragmentAfter:@" " andBefore:@"\\\n"];
    newFunction[@"Name"] = base ? base : @"";
    
    return newFunction;
}
-(NSArray*)getAvailableWinetricksList
{
    NSString* winetricksPath = [NSString stringWithFormat:@"%@/Wineskin.app/Contents/Resources/winetricks",self.path];
    NSString* winetricksRaw = [[NSString alloc] initWithContentsOfFile:winetricksPath encoding:NSASCIIStringEncoding error:nil];
    
    NSMutableArray* newList = [[NSMutableArray alloc] init];
    NSMutableArray* winetricksItems = [[winetricksRaw componentsSeparatedByString:@"\nw_metadata "] mutableCopy];
    [winetricksItems removeObjectAtIndex:0];
    
    for (__strong NSString* winetrickItem in winetricksItems)
    {
        NSMutableDictionary* newFunction = [self getFunctionFromDescription:winetrickItem];
        
        NSString* dllsList = [winetrickItem getFragmentAfter:@"w_override_dlls native,builtin " andBefore:@"\n"];
        if (!dllsList) dllsList = [winetrickItem getFragmentAfter:@"w_override_dlls native " andBefore:@"\n"];
        if (dllsList)  newFunction[@"DLLs"] = dllsList;
        
        winetrickItem = [winetrickItem getFragmentAfter:nil andBefore:@"\nload_"];
        NSString* titleField = [self getFieldValue:@"title" fromDescription:winetrickItem];
        NSString* yearField = [self getFieldValue:@"year" fromDescription:winetrickItem];
        NSString* publisherField = [self getFieldValue:@"publisher" fromDescription:winetrickItem];
        
        NSString* description = titleField;
        if (yearField && publisherField)
        {
            description = [NSString stringWithFormat:@"%@ (Copyright © %@ %@. All rights reserved.)",
                           titleField, yearField, publisherField];
        }
        
        newFunction[@"Description"] = description ? description : @"";
        
        [newList addObject:newFunction];
    }
    
    NSSortDescriptor *descript = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
    [newList sortUsingDescriptors:@[descript]];
    
    descript = [[NSSortDescriptor alloc] initWithKey:@"Type" ascending:YES];
    [newList sortUsingDescriptors:@[descript]];
    
    return newList;
}
-(BOOL)isWinetrickAvailableForInstalling:(NSString*)winetrickName
{
    for (NSDictionary* winetrick in [self getAvailableWinetricksList])
    {
        if ([[winetrick[@"Name"] lowercaseString] isEqualToString:winetrickName.lowercaseString]) return YES;
    }
    
    return NO;
}

// Path utilities
-(NSString*)completeWindowsPath:(NSString*)windowsPath
{
    NSString* macPath = [[windowsPath substringFromIndex:3] stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    NSString* driveC = [NSPathUtilities getMacPathForWindowsDrive:'C' ofWrapper:self.path];
    
    NSArray* arquivos = [NSPathUtilities filesCompatibleWithStructure:macPath insideFolder:driveC];
    macPath = arquivos.count == 0 ? nil : arquivos[0];
    
    return macPath ? [NSPathUtilities getWindowsPathForMacPath:macPath ofWrapper:self.path] : nil;
}
-(NSString*)programFilesPathFor64bitsApplication:(BOOL)is64bits
{
    NSString* reg = [self getRegistryEntry:@"[Software\\\\Microsoft\\\\Windows\\\\CurrentVersion]" fromRegistryFileNamed:SYSTEM_REG];
    NSString* value = nil;
    
    if (!is64bits)
    {
        value = [NSPortManager getStringValueForKey:@"ProgramFilesDir (x86)" fromRegistryString:reg];
        if (value) value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"/"];
    }
    
    if (!value)
    {
        value = [NSPortManager getStringValueForKey:@"ProgramFilesDir" fromRegistryString:reg];
        if (value) value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"/"];
    }
    
    if (!value) value = @"C:/Program Files";
    return value;
}

//Add, delete and get registry entries
-(NSString*)getPathForRegistryFile:(NSString*)reg
{
    NSString* cxPath = [NSString stringWithFormat:@"%@/Contents/SharedSupport/CrossOverGames/support/default/%@.reg",self.path,reg];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:cxPath])
    {
        return cxPath;
    }
    
    return [NSString stringWithFormat:@"%@/Contents/Resources/%@.reg",self.path,reg];
}
-(BOOL)addRegistry:(NSString*)lines fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    text = [NSString stringWithFormat:@"%@\n\n\n%@",text,lines];
    return [text writeToFile:regFile atomically:NO encoding:NSASCIIStringEncoding];
}
-(BOOL)deleteRegistry:(NSString*)line fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    if (!text) return false;
    
    NSMutableArray* fragments = [[text componentsSeparatedByString:line] mutableCopy];
    if (fragments.count > 1)
    {
        NSString *remove = @"";
        NSScanner *scanner = [NSScanner scannerWithString:text];
        [scanner scanUpToString:line intoString:nil];
        while(![scanner isAtEnd])
        {
            NSString *substring = nil;
            [scanner scanString:line intoString:nil];
            
            if([scanner scanUpToString:@"\n\n" intoString:&substring])
                remove = [NSString stringWithFormat:@"%@%@",remove,substring];
            
            [scanner scanUpToString:line intoString:nil];
        }
        text = [text stringByReplacingOccurrencesOfString:line withString:@""];
        text = [text stringByReplacingOccurrencesOfString:remove withString:@""];
        while ([text contains:@"\n\n\n"]) text = [text stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    }
    
    return [text writeToFile:regFile atomically:NO encoding:NSASCIIStringEncoding];
}
-(NSArray*)getRegistriesWithGramar:(NSString*)gramar fromRegistryFileNamed:(NSString*)reg
{
    //A gramática mencionada é apenas uma entrada de registro com um * no lugar de um dos campos
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    NSMutableArray* objects = [NSMutableArray new];
    NSArray* gramarParts = [gramar componentsSeparatedByString:@"*"];
    
    NSArray* registriesParts = [text componentsSeparatedByString:gramarParts[0]];
    NSString* registry;
    int x;
    
    for (int y = 1; y < registriesParts.count; y ++)
    {
        registry = [registriesParts[y] getFragmentAfter:nil andBefore:@"\n\n"];
        NSArray* registryParts = [registry componentsSeparatedByString:@"\n"];
        
        if (registryParts.count > 1)
        {
            NSString* text2 = [NSString stringWithFormat:@"%@%@",gramarParts[0],registryParts[0]];
            
            if ([text2 contains:gramarParts[1]])
            {
                for (x = 1; x < registryParts.count; x++) text2 = [NSString stringWithFormat:@"%@\n%@",text2,registryParts[x]];
                [objects addObject:text2];
            }
        }
    }
    return objects;
}
-(NSString*)getRegistryEntry:(NSString*)line fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    return [NSPortManager getRegistryEntry:line fromRegistryString:text];
}
+(NSString*)getRegistryEntry:(NSString*)line fromRegistryString:(NSString*)text
{
    NSString* registry = [text getFragmentAfter:line andBefore:@"\n\n"];
    if (registry)
    {
        NSMutableArray* fragments2 = [[registry componentsSeparatedByString:@"\n"] mutableCopy];
        if (fragments2.count > 1)
        {
            [fragments2 removeObjectAtIndex:0];
            return [fragments2 componentsJoinedByString:@"\n"];
        }
    }
    
    return @"";
}

//Set value at registry entries
-(void)setValue:(NSString*)value forKey:(NSString*)key atRegistryEntryString:(NSMutableString*)registry
{
    NSString* keyEqualString = key ? [NSString stringWithFormat:@"\"%@\"=",key] : @"@=";
    NSRange valueRange = [registry rangeAfterString:keyEqualString andBeforeString:@"\n"];
    
    if (!value || value.length == 0)
    {
        if (valueRange.location == NSNotFound)
        {
            return;
        }
        
        NSRange keyRange = [registry rangeOfString:keyEqualString];
        [registry replaceCharactersInRange:NSMakeRange(keyRange.location, keyRange.length + valueRange.length) withString:@""];
        
        if ([registry contains:@"\n\n"]) [registry replaceOccurrencesOfString:@"\n\n" withString:@"\n"];
        
        return;
    }
    
    if (valueRange.location != NSNotFound)
    {
        [registry replaceCharactersInRange:valueRange withString:value];
        return;
    }
    
    [registry setString:[NSString stringWithFormat:@"%@%@\n%@",keyEqualString,value,registry]];
}
-(void)setValues:(NSDictionary*)values atRegistryEntryString:(NSMutableString*)registry
{
    for (NSString* key in values.allKeys)
    {
        [self setValue:values[key] forKey:key atRegistryEntryString:registry];
    }
}
-(BOOL)setValues:(NSDictionary*)values forEntry:(NSString*)registryEntry atRegistryFileNamed:(NSString*)regFileName
{
    NSMutableString* registry2 = [[self getRegistryEntry:registryEntry fromRegistryFileNamed:regFileName] mutableCopy];
    
    [self setValues:values atRegistryEntryString:registry2];
    
    BOOL deleted = [self deleteRegistry:registryEntry fromRegistryFileNamed:regFileName];
    if (!deleted) return false;
    
    return [self addRegistry:[NSString stringWithFormat:@"%@\n%@\n",registryEntry,registry2] fromRegistryFileNamed:regFileName];
}

//Get values from registry entries
+(NSString*)getStringValueForKey:(NSString*)value fromRegistryString:(NSString*)registry
{
    NSString* keyEqualString = value ? [NSString stringWithFormat:@"\"%@\"=\"",value] : @"@=\"";
    return [registry getFragmentAfter:keyEqualString andBefore:@"\""];
}
+(NSString*)getValueForKey:(NSString*)value fromRegistryString:(NSString*)registry
{
    NSString* keyEqualString = value ? [NSString stringWithFormat:@"\"%@\"=",value] : @"@=";
    return [registry getFragmentAfter:keyEqualString andBefore:@"\n"];
}

@end
