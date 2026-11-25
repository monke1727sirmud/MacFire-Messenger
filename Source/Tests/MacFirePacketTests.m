#import <XCTest/XCTest.h>

#import "XfirePacket.h"
#import "XfirePacketGenerator.h"
#import "XfirePacketAttributeMap.h"
#import "XfirePacketAttributeValue.h"
#import "XfirePacketScanner.h"

@interface MacFirePacketTests : XCTestCase
- (XfirePacket *)packetByDecoding:(NSData *)raw;
@end

@implementation MacFirePacketTests

- (XfirePacket *)packetByDecoding:(NSData *)raw
{
	XfirePacket *packet = [XfirePacket decodedPacketByScanningBuffer:raw];
	XCTAssertNotNil(packet);
	return packet;
}

- (void)testGeneratedPacketRoundTripsThroughScanner
{
	XfirePacketAttributeMap *attrs = [XfirePacketAttributeMap map];
	[attrs setObject:[XfirePacketAttributeValue attributeValueWithString:@"alice"] forKey:@"name"];
	[attrs setObject:[XfirePacketAttributeValue attributeValueWithInt:0x01020304] forKey:@"userid"];

	NSData *raw = [[XfirePacketGenerator generatorWithID:2 attributes:attrs] generate];
	XCTAssertNotNil(raw);

	XfirePacket *packet = [self packetByDecoding:raw];
	XCTAssertEqual([packet packetID], (XfirePacketID)2);

	XfirePacketAttributeValue *name = [packet attributeForKey:@"name"];
	XCTAssertEqualObjects([name value], @"alice");

	XfirePacketAttributeValue *userid = [packet attributeForKey:@"userid"];
	XCTAssertEqual([[userid value] unsignedIntValue], (unsigned int)0x01020304);
}

- (void)testUUIDAndArrayAttributesRoundTrip
{
	unsigned char uuidBytes[16];
	for( NSUInteger i = 0; i < sizeof(uuidBytes); i++ )
	{
		uuidBytes[i] = (unsigned char)i;
	}

	NSArray *values = [NSArray arrayWithObjects:
		[XfirePacketAttributeValue attributeValueWithString:@"one"],
		[XfirePacketAttributeValue attributeValueWithString:@"two"],
		nil];

	XfirePacketAttributeMap *attrs = [XfirePacketAttributeMap map];
	[attrs setObject:[XfirePacketAttributeValue attributeValueWithUUID:
		[NSData dataWithBytes:uuidBytes length:sizeof(uuidBytes)]] forKey:@"sid"];
	[attrs setObject:[XfirePacketAttributeValue attributeValueWithArray:values] forKey:@"friends"];

	NSData *raw = [[XfirePacketGenerator generatorWithID:2 attributes:attrs] generate];
	XfirePacket *packet = [self packetByDecoding:raw];

	XfirePacketAttributeValue *sid = [packet attributeForKey:@"sid"];
	XCTAssertEqualObjects([sid value], [NSData dataWithBytes:uuidBytes length:sizeof(uuidBytes)]);

	XfirePacketAttributeValue *friends = [packet attributeForKey:@"friends"];
	XCTAssertEqual([friends typeID], kXfirePacketAttributeArrayType);
	NSArray *decodedValues = [friends value];
	XCTAssertEqual([decodedValues count], (NSUInteger)2);
	XCTAssertEqualObjects([[decodedValues objectAtIndex:1] value], @"two");
}

- (void)testNestedAttributeMapRoundTrips
{
	XfirePacketAttributeMap *inner = [XfirePacketAttributeMap map];
	[inner setObject:[XfirePacketAttributeValue attributeValueWithString:@"inner"] forKey:@"k"];

	XfirePacketAttributeMap *attrs = [XfirePacketAttributeMap map];
	[attrs setObject:[XfirePacketAttributeValue attributeValueWithAttributeMap:inner] forKey:@"prefs"];

	NSData *raw = [[XfirePacketGenerator generatorWithID:2 attributes:attrs] generate];
	XfirePacket *packet = [self packetByDecoding:raw];

	XfirePacketAttributeValue *prefs = [packet attributeForKey:@"prefs"];
	XfirePacketAttributeMap *decodedInner = [prefs value];
	XfirePacketAttributeValue *innerValue = [decodedInner objectForKey:@"k"];
	XCTAssertEqualObjects([innerValue value], @"inner");
}

- (void)testIntegerKeyDomainPacketUsesHexKeys
{
	unsigned char raw[] = {
		11, 0,          // total length
		26, 0,          // packet ID in the integer key domain
		1,              // attribute count
		0x01,           // key 1
		0x02,           // uint32 value
		0xEF, 0xBE, 0xAD, 0xDE
	};

	XfirePacket *packet = [self packetByDecoding:[NSData dataWithBytes:raw length:sizeof(raw)]];
	XCTAssertEqual([packet packetID], (XfirePacketID)26);

	XfirePacketAttributeValue *attr = [packet attributeForKey:@"0x01"];
	XCTAssertNotNil(attr);
	XCTAssertEqual([[attr value] unsignedIntValue], (unsigned int)0xDEADBEEF);
}

- (void)testScannerReadsUInt64AndByteValues
{
	unsigned char raw[] = {
		22, 0,              // total length
		2, 0,               // packet ID 2
		2,                  // attribute count
		3, 'b', 'i', 'g',   // key "big"
		0x07,               // uint64 value
		0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11,
		1, 'b',             // key "b"
		0x08,               // byte value
		0x7F
	};

	XfirePacket *packet = [self packetByDecoding:[NSData dataWithBytes:raw length:sizeof(raw)]];

	XfirePacketAttributeValue *big = [packet attributeForKey:@"big"];
	XCTAssertEqual([[big value] unsignedLongLongValue], (unsigned long long)0x1122334455667788ULL);

	XfirePacketAttributeValue *byte = [packet attributeForKey:@"b"];
	XCTAssertEqual([[byte value] unsignedCharValue], (unsigned char)0x7F);
}

- (void)testTruncatedPacketIsRejected
{
	unsigned char raw[] = { 10, 0, 2, 0, 1 };
	XCTAssertNil([XfirePacket decodedPacketByScanningBuffer:
		[NSData dataWithBytes:raw length:sizeof(raw)]]);
}

@end
