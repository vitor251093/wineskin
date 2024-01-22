//
//  NSMutableArray+Extension.h
//  Wineskin
//
//  Created by Vitor Marques de Miranda on 08/10/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableArray<ObjectType> (PKMutableArray)

-(void)replaceObjectsWithVariation:(_Nullable id (^_Nonnull)(id _Nonnull object, NSUInteger index))newObjectForObject;

@end

NS_ASSUME_NONNULL_END
