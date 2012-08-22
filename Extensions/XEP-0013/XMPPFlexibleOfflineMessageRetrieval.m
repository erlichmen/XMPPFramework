//
//  XMPPFlexibleOfflineMessageRetrieval.m
//  shakka.me
//
//  Created by Shay Erlichmen on 14/08/12.
//  Copyright (c) 2012 shakka.me. All rights reserved.
//

#import "XMPPFlexibleOfflineMessageRetrieval.h"
#import "XMPPLogging.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NS_DISCO_ITEMS  @"http://jabber.org/protocol/disco#items"
#define NS_OFFLINE    @"http://jabber.org/protocol/offline"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPFlexibleOfflineMessageRetrieval()
@property (nonatomic, strong) NSMutableArray *offlineMessages;
@end

@implementation XMPPFlexibleOfflineMessageRetrieval


+(XMPPIQ *)createDiscoIq:(XMPPStream *)xmppStream section:(NSString*)section {
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *toValue = [myJID domain];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:[NSString stringWithFormat:@"http://jabber.org/protocol/disco#%@", section]];
    
    [query addAttributeWithName:@"node" stringValue:NS_OFFLINE];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get"];
	[iq addAttributeWithName:@"to" stringValue:toValue];
    [iq addChild:query];
    
    return iq;
}

+(XMPPIQ *)createDiscoInfoIq:(XMPPStream *)xmppStream {
    // <iq type='get'>
    //   <query xmlns='http://jabber.org/protocol/disco#info'/>
    //  </iq>
 
    return [XMPPFlexibleOfflineMessageRetrieval createDiscoIq:xmppStream section:@"info"];
}

+(XMPPIQ *)createDiscoItemsIq:(XMPPStream *)xmppStream {
    // <iq type='get'>
    //   <query xmlns='http://jabber.org/protocol/disco#items'/>
    //  </iq>
    
    return [XMPPFlexibleOfflineMessageRetrieval createDiscoIq:xmppStream section:@"items"];
}

+(void)sendInfoDisco:(XMPPStream *)xmppStream {
    XMPPIQ *response = [XMPPFlexibleOfflineMessageRetrieval createDiscoInfoIq:xmppStream];
    	
   [xmppStream sendElement:response];
}

+(void)sendItemsDisco:(XMPPStream *)xmppStream {
    XMPPIQ *response = [XMPPFlexibleOfflineMessageRetrieval createDiscoItemsIq:xmppStream];
    
    [xmppStream sendElement:response];
}

-(void)retrieveItems {
    [XMPPFlexibleOfflineMessageRetrieval sendItemsDisco:self.xmppStream];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
    [XMPPFlexibleOfflineMessageRetrieval sendInfoDisco:sender];
    [XMPPFlexibleOfflineMessageRetrieval sendItemsDisco:sender];
}

+(XMPPIQ *)createItemNode:(NSString *)action node:(NSString *)node {
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get"];
    NSXMLElement *offline = [NSXMLElement elementWithName:@"offline" xmlns:NS_OFFLINE];
    
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"action" stringValue:action];
	[item addAttributeWithName:@"node" stringValue:node];
    
    [iq addChild:offline];
    [offline addChild:item];
    
    return iq;
}

- (void)fetchItem:(NSString *)node {
    // <iq type='get' id='view1'>
    //   <offline xmlns='http://jabber.org/protocol/offline'>
    //     <item action='view' node='2003-02-27T22:52:37.225Z'/>
    //   </offline>
    // </iq>
 
    [self.xmppStream sendElement:[XMPPFlexibleOfflineMessageRetrieval createItemNode:@"action" node:node]];
}

- (void)deleteItem:(NSString *)node {
    // <iq type='get' id='remove1'>
    //   <offline xmlns='http://jabber.org/protocol/offline'>
    //     <item action='remove' node='2003-02-27T22:52:37.225Z'/>
    //   </offline>
    // </iq>

    [self.xmppStream sendElement:[XMPPFlexibleOfflineMessageRetrieval createItemNode:@"remove" node:node]];    
}

-(NSMutableArray *)loadOfflineMessages:(NSXMLElement*)itemsQuery {
    NSArray *items = [itemsQuery elementsForName:@"item"];
    NSMutableArray *offlineMessages = [[NSMutableArray alloc] initWithCapacity:[items count]];
    
    NSUInteger i;
    for(i = 0; i < [items count]; i++)
    {
        NSString *fromJidStr = [[[items objectAtIndex:i] attributeForName:@"from"] stringValue];
        
        XMPPJID *fromJid = [XMPPJID jidWithString:fromJidStr];
        
        NSString *node = [[[items objectAtIndex:i] attributeForName:@"node"] stringValue];
        
        NSMutableDictionary *message = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        node,  @"node",
                                        fromJid, @"from",
                                        nil];
        
        [offlineMessages addObject:message];
    }
    
    return offlineMessages;
}

-(BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    NSXMLElement *itemsQuery = [iq elementForName:@"query" xmlns:NS_DISCO_ITEMS];
    if (itemsQuery != nil) {
        NSString *node = [itemsQuery attributeStringValueForName:@"node"];
        if ([node isEqualToString:NS_OFFLINE] == NO) {
            return NO;
        }
        
        NSMutableArray *offlineMessages = [self loadOfflineMessages:itemsQuery];

        [multicastDelegate xmppFlexibleOfflineMessageRetrieval:self didReceiveOfflineMessages:offlineMessages];
        
        return YES;
    }
    
    return NO;
}

@end
