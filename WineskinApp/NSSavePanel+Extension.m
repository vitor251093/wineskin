//
//  NSSavePanel+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSSavePanel+Extension.h"

#import "NSComputerInformation.h"

@implementation NSSavePanel (PKSavePanel)

-(void)setInitialDirectory:(NSString*)path
{
    [self setDirectoryURL:[NSURL fileURLWithPath:path isDirectory:YES]];
}

-(void)setWindowTitle:(NSString*)string
{
    if ([self isKindOfClass:[NSOpenPanel class]])
    {
        if (IS_SYSTEM_MAC_OS_10_11_OR_SUPERIOR) [self setMessage:string];
        else [self setTitle:string];
    }
    else
    {
        [self setTitle:string];
    }
}

@end
