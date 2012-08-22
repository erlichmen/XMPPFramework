//
//  NSString+XMPPDateTimeProfiles.h
//  shakka.me
//
//  Created by Shay Erlichmen on 20/08/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (XMPPDateTimeProfiles)
+ (NSString *)xmppDateTimeStringWithDate:(NSDate *)date;
@end
