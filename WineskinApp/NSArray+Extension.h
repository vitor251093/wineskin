//
//  NSArray+Extension.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 15/05/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSArray (PKArray)

-(NSArray*)sortedDictionariesArrayWithKey:(NSString *)key orderingByValuesOrder:(NSArray*)value;

@end
