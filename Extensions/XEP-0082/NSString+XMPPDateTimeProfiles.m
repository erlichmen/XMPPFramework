//
//  NSString+XMPPDateTimeProfiles.m
//  shakka.me
//
//  Created by Shay Erlichmen on 20/08/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import "NSString+XMPPDateTimeProfiles.h"
#import "XMPPDateTimeProfiles.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface NSDate(XMPPDateTimeProfilesPrivate)
- (NSString *)xmppStringWithDateFormat:(NSString *)dateFormat;
@end

@implementation NSString(XMPPDateTimeProfiles)

+ (NSString *)xmppDateTimeStringWithDate:(NSDate *)date {
    return [XMPPDateTimeProfiles formatDateTimeUTC:date];
}

@end
