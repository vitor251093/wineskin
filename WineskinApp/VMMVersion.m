//
//  VMMVersion.m
//  Wineskin
//
//  Created by Vitor Marques de Miranda on 08/10/18.
//

#import "VMMVersion.h"
#import "NSString+Extension.h"

@implementation VMMVersion

-(nonnull instancetype)initWithString:(nonnull NSString*)string
{
    self = [super init];
    if (self)
    {
        self.components = [string componentsSeparatedByString:@"."];
    }
    return self;
}
-(VMMVersionCompare)compareWithVersion:(nonnull VMMVersion*)version
{
    @autoreleasepool
    {
        NSArray<NSString*>* PKArray1 = self.components;
        NSArray<NSString*>* PKArray2 = version.components;
        
        for (int x = 0; x < PKArray1.count && x < PKArray2.count; x++)
        {
            if ([PKArray1[x] initialIntegerValue].intValue < [PKArray2[x] initialIntegerValue].intValue)
                return VMMVersionCompareSecondIsNewest;
            
            if ([PKArray1[x] initialIntegerValue].intValue > [PKArray2[x] initialIntegerValue].intValue)
                return VMMVersionCompareFirstIsNewest;
            
            if (PKArray1[x].length > PKArray2[x].length) return VMMVersionCompareFirstIsNewest;
            if (PKArray1[x].length < PKArray2[x].length) return VMMVersionCompareSecondIsNewest;
        }
        
        if (PKArray1.count < PKArray2.count) return VMMVersionCompareSecondIsNewest;
        if (PKArray1.count > PKArray2.count) return VMMVersionCompareFirstIsNewest;
        
        return VMMVersionCompareSame;
    }
}

+(VMMVersionCompare)compareVersionString:(nonnull NSString*)PK1 withVersionString:(nonnull NSString*)PK2
{
    @autoreleasepool
    {
        VMMVersion* version1 = [[VMMVersion alloc] initWithString:PK1];
        VMMVersion* version2 = [[VMMVersion alloc] initWithString:PK2];
        
        return [version1 compareWithVersion:version2];
    }
}

@end
