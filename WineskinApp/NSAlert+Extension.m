//
//  NSAlert+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSAlert+Extension.h"

#import "NSThread+Extension.h"

#define INPUT_DIALOG_MESSAGE_FIELD_FRAME NSMakeRect(0, 0, 260, 24)

@implementation NSImage (PKImageForAlert)
-(NSImage*)getTintedImageWithColor:(NSColor*)color
{
    NSImage* tinted = [[NSImage alloc] initWithSize:self.size];
    [tinted lockFocus];
    
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    [self drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    
    [color set];
    NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop);
    
    [tinted unlockFocus];
    return tinted;
}
+(NSImage*)stopProgressIcon
{
    NSImage* icon = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
    [icon setSize:NSMakeSize(ALERT_ICON_SIZE, ALERT_ICON_SIZE)];
    return [icon getTintedImageWithColor:[NSColor redColor]];
}
+(NSImage*)cautionIcon
{
    NSImage* icon = [NSImage imageNamed:NSImageNameCaution];
    [icon setSize:NSMakeSize(ALERT_ICON_SIZE, ALERT_ICON_SIZE)];
    return icon;
}
@end

@implementation NSAlert (PKAlert)
+(NSString*)titleForAlertType:(NSAlertType)alertType
{
    switch (alertType)
    {
        case NSAlertTypeCustom:
            return WINESKIN_APP_NAME;
            
        case NSAlertTypeSuccess:
            return NSLocalizedString(@"Success",nil);
            
        case NSAlertTypeWarning:
            return NSLocalizedString(@"Warning",nil);
            
        case NSAlertTypeWinetricks:
            return NSLocalizedString(@"Winetricks No Logs Mode",nil);
            
        case NSAlertTypeError:
            return NSLocalizedString(@"Error",nil);
            
        case NSAlertTypeCritical:
            return NSLocalizedString(@"Error",nil);
            
        default: break;
    }
    
    return @"";
}
-(void)setIconWithAlertType:(NSAlertType)alertType
{
    switch (alertType)
    {
        case NSAlertTypeWarning:
            [self setAlertStyle:NSCriticalAlertStyle];
            break;
        case NSAlertTypeWinetricks:
            [self setAlertStyle:NSCriticalAlertStyle];
            break;
        case NSAlertTypeError:
            [self setIcon:[NSImage cautionIcon]];
            break;
        case NSAlertTypeCritical:
            [self setIcon:[NSImage stopProgressIcon]];
            break;
        default: break;
    }
}

+(void)showAlertMessageWithException:(NSException*)exception
{
    [self showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];
}
+(void)showAlertOfType:(NSAlertType)alertType withMessage:(NSString*)message
{
    NSString* alertTitle = [self titleForAlertType:alertType];
    
    [self showAlertMessage:message withTitle:alertTitle withSettings:^(NSAlert* alert)
     {
         [alert setIconWithAlertType:alertType];
     }];
}
+(void)showAlertMessage:(NSString*)message withTitle:(NSString*)title withSettings:(void (^)(NSAlert* alert))optionsForAlert
{
    if ([NSThread isMainThread])
    {
        NSAlert* msgBox = [[NSAlert alloc] init];
        [msgBox setMessageText: title];
        [msgBox addButtonWithTitle:NSLocalizedString(@"OK",nil)];
        [msgBox setInformativeText: message];
        
        optionsForAlert(msgBox);
        
        [msgBox runModal];
    }
    else
    {
        NSCondition* lock = [[NSCondition alloc] init];
        [NSThread dispatchBlockInMainQueue:^
         {
             NSAlert* msgBox = [[NSAlert alloc] init];
             [msgBox setMessageText: title];
             [msgBox addButtonWithTitle:NSLocalizedString(@"OK",nil)];
             [msgBox setInformativeText: message];
             
             optionsForAlert(msgBox);
             
             [msgBox runModal];
             [lock signal];
             [lock unlock];
         }];
        [lock lock];
        [lock wait];
        [lock unlock];
    }
}

+(BOOL)showBooleanAlertMessage:(NSString*)message withTitle:(NSString*)title withDefault:(BOOL)yesDefault
{
    return [self showBooleanAlertMessage:message withTitle:title withDefault:yesDefault withSettings:^(NSAlert* alert) {}];
}
+(BOOL)showBooleanAlertOfType:(NSAlertType)alertType withMessage:(NSString*)message withDefault:(BOOL)yesDefault
{
    NSString* alertTitle = [self titleForAlertType:alertType];
    
    return [self showBooleanAlertMessage:message withTitle:alertTitle withDefault:yesDefault withSettings:^(NSAlert* alert)
            {
                [alert setIconWithAlertType:alertType];
            }];
}
+(BOOL)showBooleanAlertMessage:(NSString*)message withTitle:(NSString*)title withDefault:(BOOL)yesDefault withSettings:(void (^)(NSAlert* alert))setAlertSettings
{
    __block NSString* defaultButton;
    __block NSString* alternateButton;
    if (yesDefault)
    {
        defaultButton = NSLocalizedString(@"Yes",nil);
        alternateButton = NSLocalizedString(@"No",nil);
    }
    else
    {
        defaultButton = NSLocalizedString(@"No",nil);
        alternateButton = NSLocalizedString(@"Yes",nil);
    }
    
    if ([NSThread isMainThread])
    {
        BOOL value = !yesDefault;
        
        NSAlert *alert = [NSAlert alertWithMessageText:title != nil ? title : @""
                                         defaultButton:defaultButton
                                       alternateButton:alternateButton
                                           otherButton:nil
                             informativeTextWithFormat:@"%@",message];
        
        setAlertSettings(alert);
        
        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) value = yesDefault;
        
        return value;
    }
    else
    {
        NSCondition* lock = [[NSCondition alloc] init];
        __block BOOL value = !yesDefault;
        [NSThread dispatchBlockInMainQueue:^
         {
             NSAlert *alert = [NSAlert alertWithMessageText:title != nil ? title : @""
                                              defaultButton:defaultButton
                                            alternateButton:alternateButton
                                                otherButton:nil
                                  informativeTextWithFormat:@"%@",message];
             
             setAlertSettings(alert);
             
             NSInteger button = [alert runModal];
             if (button == NSAlertDefaultReturn) value = yesDefault;
             
             [lock signal];
             [lock unlock];
         }];
        
        [lock lock];
        [lock wait];
        [lock unlock];
        return value;
    }
}

+(NSString*)inputDialogWithTitle:(NSString*)prompt message:(NSString*)message defaultValue:(NSString*)defaultValue
{
    if ([NSThread isMainThread])
    {
        NSAlert *alert = [NSAlert alertWithMessageText:prompt
                                         defaultButton:NSLocalizedString(@"OK",nil)
                                       alternateButton:NSLocalizedString(@"Cancel",nil)
                                           otherButton:nil
                             informativeTextWithFormat:@"%@",message];
        
        NSTextField *input = [[NSTextField alloc] initWithFrame:INPUT_DIALOG_MESSAGE_FIELD_FRAME];
        if (defaultValue) [input setStringValue:defaultValue];
        [alert setAccessoryView:input];
        
        if ([alert runModal] == NSAlertDefaultReturn)
        {
            [input validateEditing];
            return [input stringValue];
        }
        
        return nil;
    }
    else
    {
        NSCondition* lock = [[NSCondition alloc] init];
        __block NSString* value = nil;
        [NSThread dispatchBlockInMainQueue:^
         {
             NSAlert *alert = [NSAlert alertWithMessageText:prompt
                                              defaultButton:NSLocalizedString(@"OK",nil)
                                            alternateButton:NSLocalizedString(@"Cancel",nil)
                                                otherButton:nil
                                  informativeTextWithFormat:@"%@",message];
             
             NSTextField *input = [[NSTextField alloc] initWithFrame:INPUT_DIALOG_MESSAGE_FIELD_FRAME];
             if (defaultValue) [input setStringValue:defaultValue];
             [alert setAccessoryView:input];
             
             if ([alert runModal] == NSAlertDefaultReturn)
             {
                 [input validateEditing];
                 value = [input stringValue];
             }
             [lock signal];
             [lock unlock];
         }];
        [lock lock];
        [lock wait];
        [lock unlock];
        
        return value;
    }
}
@end

