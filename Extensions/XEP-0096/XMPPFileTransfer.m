//
//  XMPPFileTransfer.m
//  shakka.me
//
//  Created by Shay Erlichmen on 11/07/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import "XMPPFileTransfer.h"
#import "XMPPFramework.h"
#import "TURNSocket.h"

#define NS_FILETRANSFER @"http://jabber.org/protocol/si"
#define NS_FEATURE      @"http://jabber.org/protocol/feature-neg"
#define NS_DATA         @"jabber:x:data"
#define NS_BYTESTREAMS  @"http://jabber.org/protocol/bytestreams"
#define PROFILE_FILE_TRANSFER @"http://jabber.org/protocol/si/profile/file-transfer"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface FileReceiver : NSObject
-(FileReceiver *) initWithUrl:(NSString *)filenameFullPath sender:(XMPPJID *)sender sid:(NSString *)transferSid size:(int)fileSize;
@property (nonatomic, strong) TURNSocket *socket;
@property (nonatomic) int totalData;
@property (nonatomic, strong, readwrite) NSOutputStream *fileStream;
@property (nonatomic, strong) NSString *fullPath;
@property (nonatomic, strong) XMPPJID *sender;
@property (nonatomic, strong) NSString *sid;
@property (nonatomic) int size;
@end

@interface FileReceiver()
@end

@implementation FileReceiver
@synthesize socket, totalData, fullPath, fileStream, sender, sid;

-(FileReceiver *) initWithUrl:(NSString *)filenameFullPath sender:(XMPPJID *)from sid:(NSString *)transferSid size:(int)fileSize {
    
    self = [super init];
    
    if (self) {
        self.fullPath = filenameFullPath;
        self.sender = from;
        self.sid = transferSid;
        self.size = fileSize;
        self.fileStream = [NSOutputStream outputStreamToFileAtPath:self.fullPath append:NO];
        [self.fileStream open];
    }
    
    return self;
}
@end

@interface FileTransfer : NSObject
@property (nonatomic, strong) XMPPJID *receiver;
@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) TURNSocket *senderSock;
@property (nonatomic, strong) BeginSendingBlock_t success;
@property (nonatomic, strong) EndSendingBlock_t finish;
@property (nonatomic) UInt32 totalData;
@property (nonatomic, readonly) long tag;
-(FileTransfer *)initWithReceiver:(XMPPJID *)to sessionId:(NSString *)sid onSuccess:(BeginSendingBlock_t)successBlock onFinish:(EndSendingBlock_t)finishBlock;
@end

@implementation FileTransfer
@synthesize receiver, sessionId, senderSock, tag = _tag, totalData;

-(void)notifySuccess:(SenderBlock_t)dataSender {
    _tag = [[NSDate date] timeIntervalSince1970];
    self.success(dataSender);
}

-(FileTransfer *)initWithReceiver:(XMPPJID *)to sessionId:(NSString *)sid onSuccess:(BeginSendingBlock_t)successBlock onFinish:(EndSendingBlock_t)finishBlock {
    self = [super init];
    if (self) {
        self.receiver = to;
        self.sessionId = sid;
        self.success = successBlock;
        self.finish = finishBlock;
        _tag = -1;
    }
    
    return self;
}
@end

@interface XMPPFileTransfer()
@property (nonatomic, strong, readonly) NSMutableDictionary *receiveringTransfers;
@property (nonatomic, strong, readonly) NSMutableDictionary *pendingTransfers;
@end


@implementation XMPPFileTransfer
@synthesize receiveringTransfers = _receiveringTransfers;
@synthesize pendingTransfers = _pendingTransfers;

-(id) init {
   if (self = [super init]) {
        self.filenameResolver = ^(NSString* filename, XMPPJID* jid) {
            return filename;
        };
    }
    
    return self;
}

-(FileReceiver *)createFileReceiver:(XMPPIQ *)iq {
    NSXMLElement *si = [iq elementForName:@"si" xmlns:NS_FILETRANSFER];
    
    if (si == nil) {
        return nil;
    }
    
    NSXMLElement *fileElement = [si elementForName:@"file" xmlns:PROFILE_FILE_TRANSFER];
    
    if (fileElement == nil) {
        return nil;
    }
    
    NSString *filename = [[fileElement attributeForName:@"name"] stringValue];
    int size = [[[fileElement attributeForName:@"size"] stringValue] intValue];
    NSString *sid = [[si attributeForName:@"id"] stringValue];
    
    XMPPJID *from = [iq from];
    
    NSString *fullPath = self.filenameResolver(filename, iq.from);
    return [[FileReceiver alloc] initWithUrl:fullPath sender:from sid:sid size:size];
}

-(XMPPIQ*)startFileTransfarResponse:(XMPPIQ *)iq {
    FileReceiver *fileReceiver = [self createFileReceiver:iq];
    
    if (fileReceiver == nil) {
        return nil;
    }
    
    [self.receiveringTransfers setValue:fileReceiver forKey:fileReceiver.sid];
    
    // Response
    //<iq type="result" to="user1@xmpp.shakka.me/Shays-Mac-mini" id="aaffa">
    //  <si xmlns="http://jabber.org/protocol/si">
    //      <feature xmlns="http://jabber.org/protocol/feature-neg">
    //          <x xmlns="jabber:x:data" type="submit">
    //              <field var="stream-method">
    //                  <value>http://jabber.org/protocol/bytestreams</value>
    //              </field>
    //          </x>
    //      </feature>
    //  </si>
    // </iq>
    
    
    XMPPIQ *response = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:NS_FILETRANSFER];
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature" xmlns:NS_FEATURE];
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:NS_DATA];
    
    [x addAttributeWithName:@"type" stringValue:@"submit"];
    
    NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
    
    NSXMLElement *value = [NSXMLElement elementWithName:@"value"];
    [value setStringValue:NS_BYTESTREAMS];
    
    [response addChild:si];
    [si addChild:feature];
    [feature addChild:x];
    [x addChild:field];    
    [field addChild:value];

    return response;
}

- (XMPPIQ*)startFileTransfarRequest:(XMPPJID *)to name:(NSString*)name size:(int)size fileId:(NSString*)fileId {
    // Request
    
    //<iq type="set" to="user2@xmpp.shakka.me/Shays-Mac-mini" id="aaffa" from="user1@xmpp.shakka.me/Shays-Mac-mini">
    //  <si xmlns="http://jabber.org/protocol/si" profile="http://jabber.org/protocol/si/profile/file-transfer" id="s5b_c1268eb4d8796ddc">
    //      <file xmlns="http://jabber.org/protocol/si/profile/file-transfer" size="27373070" name="2.dmg">
    //          <range/>
    //      </file>
    //      <feature xmlns="http://jabber.org/protocol/feature-neg">
    //          <x xmlns="jabber:x:data" type="form">
    //              <field type="list-single" var="stream-method">
    //                  <option>
    //                      <value>http://jabber.org/protocol/bytestreams</value>
    //                  </option>
    //              </field>
    //          </x>
    //      </feature>
    //  </si>
    //</iq>
    
    XMPPIQ *request = [XMPPIQ iqWithType:@"set" to:to elementID:[XMPPStream generateUUID]];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:NS_FILETRANSFER];
    [si addAttributeWithName:@"profile" stringValue:PROFILE_FILE_TRANSFER];
    [si addAttributeWithName:@"id" stringValue:fileId];

    if (name == nil) {
        name = fileId;
    }
    
    NSXMLElement *file = [NSXMLElement elementWithName:@"file" xmlns:PROFILE_FILE_TRANSFER];
    [file addAttributeWithName:@"size" stringValue:[NSString stringWithFormat:@"%d", size]];
    [file addAttributeWithName:@"name" stringValue:name];

    NSXMLElement *range = [NSXMLElement elementWithName:@"range"];
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature" xmlns:NS_FEATURE];
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:NS_DATA];
    
    [x addAttributeWithName:@"type" stringValue:@"form"];
    
    NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
    [field addAttributeWithName:@"type" stringValue:@"list-single"];
    [field addAttributeWithName:@"var" stringValue:@"stream-method"];

    NSXMLElement *option = [NSXMLElement elementWithName:@"option"];
    
    NSXMLElement *value = [NSXMLElement elementWithName:@"value"];
    [value setStringValue:NS_BYTESTREAMS];
    
    [request addChild:si];
    [si addChild:file];
    [file addChild:range];
    
    [si addChild:feature];
    [feature addChild:x];
    [x addChild:field];    
    [field addChild:option];
    [option addChild:value];
    
    return request;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Delegate method to receive incoming IQ stanzas.
 **/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    if ([TURNSocket isNewStartTURNRequest:iq]) {
        TURNSocket *receiverSock = [[TURNSocket alloc] initWithStream:self.xmppStream incomingTURNRequest:iq];
        
        FileReceiver *fileReceiver = [self.receiveringTransfers valueForKey:receiverSock.sid];
        
        if (fileReceiver != nil) {
            fileReceiver.socket = receiverSock;
            [receiverSock startWithDelegate:self delegateQueue:dispatch_get_main_queue() skipDiscoverCandidate:true];
        } else {
            return NO;
        }
        
        return YES;
    } 
    
    NSXMLElement *si = [iq elementForName:@"si" xmlns:NS_FILETRANSFER];
    if (si == nil) {
        return NO;
    }
    
    if ([iq isSetIQ]) {
        // Request
        
        //<iq type="set" to="user2@xmpp.shakka.me/Shays-Mac-mini" id="aaffa" from="user1@xmpp.shakka.me/Shays-Mac-mini">	
        //  <si xmlns="http://jabber.org/protocol/si" profile="http://jabber.org/protocol/si/profile/file-transfer" id="s5b_c1268eb4d8796ddc">
        //      <file xmlns="http://jabber.org/protocol/si/profile/file-transfer" size="27373070" name="2.dmg">
        //          <range/>
        //      </file>
        //      <feature xmlns="http://jabber.org/protocol/feature-neg">
        //          <x xmlns="jabber:x:data" type="form">
        //              <field type="list-single" var="stream-method">
        //                  <option>
        //                      <value>http://jabber.org/protocol/bytestreams</value>
        //                  </option>
        //              </field>
        //          </x>
        //      </feature>
        //  </si>
        //</iq>
        

        XMPPIQ *response = [self startFileTransfarResponse:iq];
        
        if (response == nil) {
            return NO;
        }
        
        [sender sendElement:response];
        
        return YES;
    } else if ([iq isResultIQ]) {
        // <iq type="result" to="user1@xmpp.shakka.me/Shays-Mac-mini" id="aaffa" from="user2@xmpp.shakka.me/Shays-Mac-mini">
		//   <si xmlns="http://jabber.org/protocol/si">
        //     <feature xmlns="http://jabber.org/protocol/feature-neg">
        //       <x xmlns="jabber:x:data" type="submit">
        //         <field var="stream-method">
        //           <value>http://jabber.org/protocol/bytestreams</value>
        //         </field>
        //       </x>
        //     </feature>
		//   </si>
        // </iq>
        
        FileTransfer *fileTransfer = [self.pendingTransfers objectForKey:iq.elementID];
        if (fileTransfer == nil) {
            NSLog(@"ERROR: ");
            return NO;
        }
        
        TURNSocket *senderSock = [[TURNSocket alloc] initWithStream:self.xmppStream toJID:fileTransfer.receiver];
        
        [senderSock setProxyCandidatesJIDs:[NSArray arrayWithObjects:[XMPPJID jidWithString: @"proxy.xmpp.shakka.me"], nil]]; // XXX HARDCODE
        
        fileTransfer.senderSock = senderSock;
        senderSock.sid = fileTransfer.sessionId;
        
        [senderSock startWithDelegate:self delegateQueue:dispatch_get_main_queue() skipDiscoverCandidate:true];
        return YES;  
    }

	return NO;	
}

- (NSMutableDictionary *)pendingTransfers {
    if (_pendingTransfers == nil) {
        _pendingTransfers = [[NSMutableDictionary alloc] init];
    }
    
    return _pendingTransfers;
}

- (NSMutableDictionary *)receiveringTransfers {
    if (_receiveringTransfers == nil) {
        _receiveringTransfers = [[NSMutableDictionary alloc] init];
    }
    
    return _receiveringTransfers;
}

- (void)send:(XMPPJID *)to name:(NSString *)name size:(int)size onSuccess:(BeginSendingBlock_t)successBlock onFinish:(EndSendingBlock_t)finishBlock onProcessMessage:(ProcessMessageBlock_t)processBlock {
    NSString *fileId = [XMPPStream generateUUID];
    XMPPIQ* fileTransferIq = [self startFileTransfarRequest:to name:name size:size fileId:fileId];
    if (processBlock) {
        NSXMLElement *si = [fileTransferIq elementForName:@"si" xmlns:NS_FILETRANSFER];
        processBlock(si);
    }
    
    FileTransfer* fileTransfer = [[FileTransfer alloc] initWithReceiver:to sessionId:fileId onSuccess:successBlock onFinish:finishBlock];
     
    [self.pendingTransfers setValue:fileTransfer forKey:fileTransfer.sessionId];
    [self.pendingTransfers setValue:fileTransfer forKey:fileTransferIq.elementID];
    
    [self.xmppStream sendElement:fileTransferIq];
}

-(FileReceiver *) FileReceiverFromSocket:(TURNSocket *)turnSocket {
    for (FileReceiver *item in self.receiveringTransfers.allValues) {
        if (item.socket == turnSocket)
            return item;
    }
    
    return nil;
}

// TODO: use dict instead of array
-(FileTransfer *) FileTransferByTag:(long)tag {
    for (FileTransfer *fileTransfer in [self.pendingTransfers allValues]) {
        if (fileTransfer.tag == tag) {
            return fileTransfer;
        }
    }
    
    return nil;
}

-(FileTransfer *) FileTransferFromSocket:(TURNSocket *)turnSocket {
    for (FileTransfer *fileTransfer in [self.pendingTransfers allValues]) {
        if (fileTransfer.senderSock == turnSocket) {
            return fileTransfer;
        }
    }
    
    return nil;
}

-(void) triggerRead:(GCDAsyncSocket *)socket length:(NSUInteger)length {
    if (length == 0) {
        [socket readDataWithTimeout:-1 tag:0];
    } else {
        [socket readDataToLength:length withTimeout:-1 tag:0];
    }
}

- (void) turnSocket:(TURNSocket *)sender didDisconnect:(NSError *)error fromSocket:(GCDAsyncSocket *) socket {

    FileReceiver* fileReceiver = [self FileReceiverFromSocket:sender];
    if (fileReceiver) {
        NSLog(@"Transfer ended %g MB %@ %@", fileReceiver.totalData / (1024.0 * 1024.0), fileReceiver.fullPath, error);
        if (fileReceiver.fileStream != nil) {
            [fileReceiver.fileStream close];
            fileReceiver.fileStream = nil;
        }
        
        if (fileReceiver.size == 0) {
            [multicastDelegate xmppFileTransfer:self didReceiveFile:fileReceiver.fullPath from:fileReceiver.sender];
        }
    }
}

- (void)turnSocket:(TURNSocket *)sender didReadData:(NSData *)data withTag:(long)tag fromSocket:(GCDAsyncSocket *) socket {
    
//    NSLog(@"read data %d", [data length]);
    FileReceiver* fileReceiver = [self FileReceiverFromSocket:sender];
    if (fileReceiver) {
        fileReceiver.totalData += data.length;

        NSInteger dataLength = data.length;
        const uint8_t *dataBytes  = data.bytes;
        
        NSInteger bytesWrittenSoFar = 0;
        do {
            NSInteger bytesWritten = [fileReceiver.fileStream write:&dataBytes[bytesWrittenSoFar] maxLength:dataLength - bytesWrittenSoFar];
            assert(bytesWritten != 0);
            if (bytesWritten == -1) {
                // TODO: finish the file download
                break;
            } else {
                bytesWrittenSoFar += bytesWritten;
            }
        } while (bytesWrittenSoFar != dataLength);
        
        int remainingSize = fileReceiver.size > 0 ? fileReceiver.size - fileReceiver.totalData : 0;
        
        if ((fileReceiver.size > 0 && remainingSize == 0) || data.length == 0) {
            [fileReceiver.fileStream close];
            fileReceiver.fileStream = nil;
            [multicastDelegate xmppFileTransfer:self didReceiveFile:fileReceiver.fullPath from:fileReceiver.sender];
        }
        
        [self triggerRead:socket length:remainingSize];
    }
}

- (void)turnSocket:(TURNSocket *)sender didWritePartialDataOfLength:(NSUInteger)partialLength withTag:(long)tag fromSocket:(GCDAsyncSocket*) socket {
    
}

- (void)turnSocket:(TURNSocket *)sender didWriteDataWithTag:(long)tag fromSocket:(GCDAsyncSocket*) socket {
    FileTransfer* fileTransfer = [self FileTransferByTag:tag];
    
    if (fileTransfer && fileTransfer.finish) {
        fileTransfer.finish(nil, fileTransfer.totalData);
    }    
}

-(void) turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket {
    FileReceiver* fileReceiver = [self FileReceiverFromSocket:sender];
    if (fileReceiver) {
        NSLog(@"Socket Suceeed Port For File Transfer: %d",socket.localPort);
        [self triggerRead:socket length:fileReceiver.size];
    } else {
        FileTransfer* fileTransfer = [self FileTransferFromSocket:sender];
        
        SenderBlock_t sender = ^(NSData * data, NSTimeInterval timeout) {
            if (data == nil) {
                [socket disconnectAfterWriting];
                return;
            }
            fileTransfer.totalData += data.length;
            [socket writeData:data withTimeout:timeout tag:fileTransfer.tag];
        };
        
        if (fileTransfer) {
            [fileTransfer notifySuccess:sender];
        } else {
            NSLog(@"ERROR: invalid socket");
        }
    }

    /*if ([self.turnSockets containsObject:sender]) {
        NSLog(@"File Transfer Ulastiiiiiiii");
        NSUInteger indexOfObj = [self.turnSockets indexOfObject:sender];
        [self.turnSockets removeObjectAtIndex:indexOfObj];
    }*/
}

-(void) turnSocketDidFinish:(TURNSocket *)sender {
    // TODO: remove the turnSocket from the file recivers
}

-(void) turnSocketDidFail:(TURNSocket *)sender {
    NSLog(@"Socket Failed For File Transfer");
    
    FileReceiver* fileReceiver = [self FileReceiverFromSocket:sender];
    if (fileReceiver) {
        NSLog(@"File Transfer Failedddddd");
    }
}
@end
