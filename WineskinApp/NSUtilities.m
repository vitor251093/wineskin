//
//  NSUtilities.m
//  Gamma Board
//
//  Created by Vitor Marques de Miranda on 27/04/14.
//  Copyright (c) 2014 Vitor Marques de Miranda. All rights reserved.
//

#import "NSUtilities.h"

#import "NSTask+Extension.h"
#import "NSString+Extension.h"
#import "NSThread+Extension.h"
#import "NSFileManager+Extension.h"
#import "NSMutableDictionary+Extension.h"

#define SOURCE_DIALOG_VIEW_WIDTH_MODIFIER_LIMIT 3
#define SOURCE_DIALOG_VIEW_WIDTH_MODIFIER_LESS  -20
#define SOURCE_DIALOG_VIEW_WIDTH_MODIFIER_MORE  30

#define SOURCE_DIALOG_BUTTONS_LATERAL       0
#define SOURCE_DIALOG_BUTTONS_SPACE         10
#define SOURCE_DIALOG_ICON_WIDTH            80
#define SOURCE_DIALOG_ICON_HEIGHT           80
#define SOURCE_DIALOG_ICON_BORDER_WITH_TEXT 30
#define SOURCE_DIALOG_ICON_BORDER           10
#define SOURCE_DIALOG_ICON_IMAGE_BORDER     10
#define SOURCE_DIALOG_ICONS_AT_X            3

@implementation NSUtilities

static NSAlert* _alertSources;

//Plist functions
+(id)getPlistItem:(NSString*)item fromWrapper:(NSString*)wrapper
{
    return [self getPlistItem:item fromPlist:PLIST_PATH_WINESKIN_WRAPPER fromWrapper:wrapper];
}
+(id)getPlistItem:(NSString*)item fromPlist:(NSString*)plist fromWrapper:(NSString*)wrapper
{
    return [[NSMutableDictionary mutableDictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@%@",wrapper,plist]] objectForKey:item];
}

@end
