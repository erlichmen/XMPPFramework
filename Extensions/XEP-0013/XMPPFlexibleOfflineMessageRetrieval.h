	//
//  XMPPFlexibleOfflineMessageRetrieval.h
//  shakka.me
//
//  Created by Shay Erlichmen on 14/08/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import "XMPPModule.h"

@interface XMPPFlexibleOfflineMessageRetrieval : XMPPModule
-(void)retrieveItems;
-(void)fetchItem:(NSString *)node;
-(void)deleteItem:(NSString *)node;
@end


@protocol XMPPFlexibleOfflineMessageRetrievalDelegate
@optional
- (void)xmppFlexibleOfflineMessageRetrieval:(XMPPFlexibleOfflineMessageRetrieval *)sender didReceiveOfflineMessages:(NSMutableArray *)messages;
@end
