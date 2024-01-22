//
//  NSFileManager+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSFileManager_Extension_Class
#define NSFileManager_Extension_Class

#import <Foundation/Foundation.h>

@interface NSFileManager (PKFileManager)

-(BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath;
-(BOOL)createDirectoryAtPath:(NSString*)path withIntermediateDirectories:(BOOL)interDirs;
-(BOOL)moveItemAtPath:(NSString*)path toPath:(NSString*)destination;
-(BOOL)copyItemAtPath:(NSString*)path toPath:(NSString*)destination;
-(BOOL)removeItemAtPath:(NSString*)path;
-(BOOL)directoryExistsAtPath:(NSString*)path;
-(BOOL)regularFileExistsAtPath:(NSString*)path;
-(NSArray*)contentsOfDirectoryAtPath:(NSString*)path;
-(NSString*)destinationOfSymbolicLinkAtPath:(NSString *)path;

-(unsigned long long int)sizeOfRegularFileAtPath:(NSString*)path;
-(unsigned long long int)sizeOfDirectoryAtPath:(NSString*)path;

@end

#endif
