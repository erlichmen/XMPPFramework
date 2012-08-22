//
//  XMPPFileTransfer.h
//  shakka.me
//
//  Created by Shay Erlichmen on 11/07/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import "XMPPModule.h"

@class XMPPJID, GCDAsyncSocket;

typedef void (^SenderBlock_t)(NSData* data, NSTimeInterval timeout);

typedef void (^ProcessMessageBlock_t)(NSXMLElement *si);
typedef void (^BeginSendingBlock_t)(SenderBlock_t sender);
typedef void (^EndSendingBlock_t)(NSError * error, UInt32 totalData);
typedef NSString * (^FilenameResolver_t)(NSString* filename, XMPPJID* jid);

@interface XMPPFileTransfer : XMPPModule
- (void)send:(XMPPJID *)to name:(NSString*)filename size:(int)size onSuccess:(BeginSendingBlock_t)successBlock onFinish:(EndSendingBlock_t)finishBlock onProcessMessage:(ProcessMessageBlock_t)processBlock;

@property (nonatomic, strong) FilenameResolver_t filenameResolver;
@end

@protocol XMPPFileTransferDelegate
@optional
- (void)xmppFileTransfer:(XMPPFileTransfer *)sender didReceiveFile:(NSString *)fullPath from:(XMPPJID *)sender;
@end
