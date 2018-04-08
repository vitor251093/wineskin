//
//  NSFileManager+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSFileManager+Extension.h"

#import "NSAlert+Extension.h"
#import "NSTask+Extension.h"

@implementation NSFileManager (PKFileManager)

-(BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath
{
    NSError* error;
    BOOL created = [self createSymbolicLinkAtPath:path withDestinationPath:destPath error:&error];
    
    if (error)
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while creating symbolic link: %@",nil), error.localizedDescription]];
    
    return created;
}
-(BOOL)createDirectoryAtPath:(NSString*)path withIntermediateDirectories:(BOOL)interDirs
{
    NSError* error;
    BOOL created = [self createDirectoryAtPath:path withIntermediateDirectories:interDirs attributes:nil error:&error];
    
    if (error)
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while creating folder: %@",nil), error.localizedDescription]];
    
    return created;
}
-(BOOL)moveItemAtPath:(NSString*)path toPath:(NSString*)destination
{
    NSError* error;
    BOOL created = [self moveItemAtPath:path toPath:destination error:&error];
    
    if (error)
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while moving file: %@",nil),
                                                               error.localizedDescription]];
    
    return created;
}
-(BOOL)copyItemAtPath:(NSString*)path toPath:(NSString*)destination
{
    NSError* error;
    BOOL created = [self copyItemAtPath:path toPath:destination error:&error];
    
    if (error)
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while copying file: %@",nil), error.localizedDescription]];
    
    return created;
}
-(BOOL)removeItemAtPath:(NSString*)path
{
    if (![self fileExistsAtPath:path]) return YES;
    
    NSError* error;
    BOOL created = [self removeItemAtPath:path error:&error];
    
    if (error)
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while removing file: %@",nil), error.localizedDescription]];
    
    return created;
}
-(BOOL)directoryExistsAtPath:(NSString*)path
{
    BOOL isDir = NO;
    return [self fileExistsAtPath:path isDirectory:&isDir] && isDir;
}
-(BOOL)regularFileExistsAtPath:(NSString*)path
{
    BOOL isDir = NO;
    return [self fileExistsAtPath:path isDirectory:&isDir] && !isDir;
}
-(NSArray*)contentsOfDirectoryAtPath:(NSString*)path
{
    if (![self fileExistsAtPath:path])
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while listing folder contents: %@ doesn't exist.",nil), path.lastPathComponent]];
        return @[];
    }
    
    if (![self directoryExistsAtPath:path])
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while listing folder contents: %@ is not a folder.",nil), path.lastPathComponent]];
        return @[];
    }
    
    NSError* error;
    NSArray* created = [self contentsOfDirectoryAtPath:path error:&error];
    
    if (error)
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while listing folder contents: %@",nil), error.localizedDescription]];
        return @[];
    }
    
    NSMutableArray* createdMutable = [created mutableCopy];
    [createdMutable removeObject:@".DS_Store"];
    
    return createdMutable;
}
-(NSString*)destinationOfSymbolicLinkAtPath:(NSString *)path
{
    NSError* error;
    NSString* destination = [self destinationOfSymbolicLinkAtPath:path error:&error];
    
    if (error)
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"Error while retrieving symbolic link destination: %@",nil),error.localizedDescription]];
    }
    
    return destination;
}

-(unsigned long long int)sizeOfRegularFileAtPath:(NSString*)path
{
    NSDictionary *fileDictionary = [self attributesOfItemAtPath:path error:nil];
    return fileDictionary ? [fileDictionary[NSFileSize] unsignedLongLongValue] : 0;
}
-(unsigned long long int)sizeOfDirectoryAtPath:(NSString*)path
{
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
    unsigned long long int fileSize = 0;
    
    for (NSString* file in filesArray)
    {
        NSString* filePath = [path stringByAppendingPathComponent:file];
        
        if (![self destinationOfSymbolicLinkAtPath:filePath error:nil])
        {
            fileSize += [self sizeOfRegularFileAtPath:filePath];
        }
    }
    
    return fileSize;
}

@end
