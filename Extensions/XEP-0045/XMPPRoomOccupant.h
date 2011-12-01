#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPPresence;


@protocol XMPPRoomOccupant <NSObject>

@property (readonly) XMPPPresence *presence;

@property (readonly) XMPPJID  * jid;      // [presence from]
@property (readonly) NSString * nickname; // [[presence from] nickname]

@property (readonly) NSString * role;
@property (readonly) NSString * affiliation;
@property (readonly) XMPPJID  * realJID; // Only available in non-anonymous rooms

@end
