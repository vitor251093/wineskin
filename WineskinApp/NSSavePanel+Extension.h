//
//  NSSavePanel+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#ifndef NSSavePanel_Extension_Class
#define NSSavePanel_Extension_Class

#import <Foundation/Foundation.h>

@interface NSSavePanel (PKSavePanel)

-(void)setInitialDirectory:(NSString*)path;

-(void)setWindowTitle:(NSString*)string;

@end

#endif
