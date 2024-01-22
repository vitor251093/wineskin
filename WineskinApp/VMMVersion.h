//
//  VMMVersion.h
//  Wineskin
//
//  Created by Vitor Marques de Miranda on 08/10/18.
//

#import <Foundation/Foundation.h>

typedef enum VMMVersionCompare
{
    VMMVersionCompareFirstIsNewest,
    VMMVersionCompareSecondIsNewest,
    VMMVersionCompareSame
} VMMVersionCompare;

@interface VMMVersion : NSObject

@property (nonatomic, strong) NSArray<NSString*>* _Nonnull components;

-(nonnull instancetype)initWithString:(nonnull NSString*)string;
-(VMMVersionCompare)compareWithVersion:(nonnull VMMVersion*)version;

+(VMMVersionCompare)compareVersionString:(nonnull NSString*)PK1 withVersionString:(nonnull NSString*)PK2;

@end
