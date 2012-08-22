#import <Foundation/Foundation.h>

@class XMPPIQ;
@class XMPPJID;
@class XMPPStream;
@class GCDAsyncSocket;

/**
 * TURNSocket is an implementation of XEP-0065: SOCKS5 Bytestreams.
 *
 * It is used for establishing an out-of-band bytestream between any two XMPP users,
 * mainly for the purpose of file transfer.
**/
@interface TURNSocket : NSObject
{
	int state;
	BOOL isClient;
	
	dispatch_queue_t turnQueue;
	
	XMPPStream *xmppStream;
	NSString *iqId;
	
	id delegate;
	dispatch_queue_t delegateQueue;
	
	dispatch_source_t turnTimer;
	
	NSString *discoUUID;
	dispatch_source_t discoTimer;
	
	NSArray *proxyCandidates;
	NSUInteger proxyCandidateIndex;
	
	NSMutableArray *candidateJIDs;
	NSUInteger candidateJIDIndex;
	
	NSMutableArray *streamhosts;
	NSUInteger streamhostIndex;
	
	XMPPJID *proxyJID;
	NSString *proxyHost;
	UInt16 proxyPort;
	
	GCDAsyncSocket *asyncSocket;
	
	NSDate *startTime, *finishTime;
}

+ (BOOL)isNewStartTURNRequest:(XMPPIQ *)iq;

+ (NSArray *)proxyCandidates;
+ (void)setProxyCandidates:(NSArray *)candidates;

- (void)setProxyCandidatesJIDs:(NSArray *)candidates;

@property (nonatomic, strong) NSString *sid;
@property (nonatomic, strong) XMPPJID *jid;

- (id)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid;
- (id)initWithStream:(XMPPStream *)xmppStream incomingTURNRequest:(XMPPIQ *)iq;

- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue skipDiscoverCandidate:(bool)skipDiscoverCandidate;

- (BOOL)isClient;

- (void)abort;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol TURNSocketDelegate
@optional
- (void)turnSocket:(TURNSocket *)sender didReadData:(NSData *)data withTag:(long)tag fromSocket:(GCDAsyncSocket*) socket;
- (void)turnSocket:(TURNSocket *)sender didDisconnect:(NSError *)err fromSocket:(GCDAsyncSocket *)socket;
- (void)turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket;
- (void)turnSocket:(TURNSocket *)sender didWritePartialDataOfLength:(NSUInteger)partialLength withTag:(long)tag fromSocket:(GCDAsyncSocket*) socket;
- (void)turnSocket:(TURNSocket *)sender didWriteDataWithTag:(long)tag fromSocket:(GCDAsyncSocket*) socket;
- (void)turnSocketDidFail:(TURNSocket *)sender;

@end