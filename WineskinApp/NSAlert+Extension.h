//
//  NSAlert+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSAlert_Extension_Class
#define NSAlert_Extension_Class

#import <Foundation/Foundation.h>

typedef enum NSAlertType
{
    NSAlertTypeSuccess,
    NSAlertTypeWarning,
    NSAlertTypeWinetricks,
    NSAlertTypeError,
    NSAlertTypeCritical,
    NSAlertTypeCustom
} NSAlertType;

@interface NSImage (PKImageForAlert)
@end

@interface NSAlert (PKAlert)

+(void)showAlertMessageWithException:(NSException*)exception;
+(void)showAlertOfType:(NSAlertType)alertType withMessage:(NSString*)message;
+(void)showAlertMessage:(NSString*)message withTitle:(NSString*)title withSettings:(void (^)(NSAlert* alert))optionsForAlert;

+(BOOL)showBooleanAlertMessage:(NSString*)message withTitle:(NSString*)title withDefault:(BOOL)yesDefault;
+(BOOL)showBooleanAlertOfType:(NSAlertType)alertType withMessage:(NSString*)message withDefault:(BOOL)yesDefault;

+(NSString*)inputDialogWithTitle:(NSString*)prompt message:(NSString*)message defaultValue:(NSString*)defaultValue;

@end

#endif
