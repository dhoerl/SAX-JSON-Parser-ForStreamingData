//
//  JSONObjectExtractor.h
//  DB_Lookup
//
//  Copyright 2014 David Hoerl
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "JSONObjectExtractor.h"

#ifdef MONGO_DB

// MongoDB specific: exact size needed so if we see a 'O', we can memcmp with "bjectId('"
// similar issue with date, that's why the default is to turn it into a fixed length iso8601 date
#define CUSHION		9

#else

#define CUSHION		0	// No Lookahead

#endif


@interface JSONObjectExtractor ()
@property (nonatomic, assign, readwrite) NSUInteger count;			// total count of objects
@property (nonatomic, strong, readwrite) NSMutableArray *objects;
@property (nonatomic, weak) id <JSONObjectExtractorProtocol> partialsDelegate;

@end

@implementation JSONObjectExtractor
{
	unsigned char		*buffer;
	size_t				bufLen;			// actual buffer length
	size_t				curBufSize;		// how much is in the buffer right now
	
	size_t				parseOffset;
	size_t				topLevelOffset;
	
	size_t				dictCount;
	size_t				arrayCount;
	BOOL				inString;
	BOOL				isQuoted;
	BOOL				eatNewDateEnding;
	BOOL				eatObjectIDEnding;
	BOOL				isDone;
}

+ (BOOL)isArray:(NSData *)data
{
	const uint8_t *p = [data bytes];
	NSUInteger len = [data length];
	
	for(NSUInteger i=0; i<len; ++i) {
		switch(*p++) {
		case ' ':
		case '\t':
		case '\r':
		case '\n':
			continue;
		case '[':
			return YES;
		default:
			return NO;
		}
	}
	return NO;
}

- (instancetype)initWithDelegate:(id <JSONObjectExtractorProtocol>)delegate
{
	if((self = [super init])) {
		_partialsDelegate = delegate;
		_objects = [NSMutableArray arrayWithCapacity:10];
	}
	return self;
}

- (void)dealloc
{
	free(buffer);
}

- (void)addData:(NSData *)data
{
	if(isDone) return;

	if(data) {
		size_t oldBufSize = curBufSize;
		curBufSize += [data length];
		if(curBufSize > bufLen) {
			bufLen = curBufSize;
			buffer = (unsigned char *)realloc(buffer, bufLen);
		}
		// now have the last chunk of data prefixing the new data
		memcpy(buffer+oldBufSize, [data bytes], [data length]);
	}
	
	while(YES) {
		NSRange r = [self parse:data?NO:YES];
		if(isDone) {
			// NSLog(@"DONE: count = %d", _count);
			break;
		}

#if 0 // testing
		NSLog(@"R=%@", NSStringFromRange(r));
		if(r.length < 200) {
			NSString *foo = [[NSString alloc] initWithBytes:buffer + r.location length:r.length encoding:NSUTF8StringEncoding];
			NSLog(@"FOO: %@", foo);
		}
#endif
		if(r.location != NSNotFound) {
			assert(r.length);
			NSData *nData = [[NSData alloc] initWithBytesNoCopy:buffer+r.location length:r.length freeWhenDone:NO];
			__autoreleasing NSError *error;
			id obj = [NSJSONSerialization JSONObjectWithData:nData options:0 error:&error];
			if(!obj) {
				NSString *str = [[NSString alloc] initWithBytes:[nData bytes] length:[nData length] encoding:NSUTF8StringEncoding];
#if 0 // Somewhat useful to figure out where the problem is
				NSLog(@"YIKES! JSON ERROR %@", error);
				NSString *err = error.userInfo[@"NSDebugDescription"];
				assert(err);
				NSArray *array = [err componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ."]];
				NSInteger errStart = [array[4] integerValue] - 64;
				if(errStart < 0) errStart = 0;
				NSInteger errEnd	= errStart + 10000;
				if(errEnd > [str length]) errEnd = [str length];
				NSLog(@"ERR RANGE %d %d", errStart, errEnd);
				NSString *problem = [str substringWithRange:NSMakeRange(errStart, errEnd - errStart)];
//NSLog(@"DATA1: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//NSLog(@"DATA2: %@", [[NSString alloc] initWithData:nData encoding:NSUTF8StringEncoding]);
				NSLog(@"PROBLEM: %@", problem);
#endif
				NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
				dict[kHOErrorKey]			= @YES;
				dict[kHOErrorText]			= str;

				obj = dict;
			}
			[_objects addObject:obj], ++_count;
		} else {
			if(r.length == 0) {
				if(topLevelOffset > 0) {
//size_t foo = topLevelOffset;
//size_t goo = curBufSize;
//size_t hoo = parseOffset;
					size_t copyLen = curBufSize - topLevelOffset;
					memmove(buffer, buffer+topLevelOffset, copyLen);
					curBufSize = copyLen;
					parseOffset -= topLevelOffset;
					topLevelOffset = 0;
//NSLog(@"MOVER| OLD: (topLevel=%ld curBufSize=%ld parseOffset=%ld) NEW: (topLevel=%ld curBufSize=%ld parseOffset=%ld", 	foo, goo, hoo, 	topLevelOffset, curBufSize, parseOffset );
				}
			}
			break;
		}
	}
	if(!isDone && [_objects count]) {
		NSArray *array = [_objects copy];
		[_objects removeAllObjects];
		//NSLog(@"Send partial count: %d %u %u to %@", [array count], _currentReceiveSize, _totalReceiveSize, NSStringFromClass([_partialsDelegate class]));
		NSDictionary *prog = @{ kCurReceiveSize : @(_currentReceiveSize), kTotReceiveSize : @(_totalReceiveSize), kPercentComplete : @((float)_currentReceiveSize / (float)_totalReceiveSize) };
		[_partialsDelegate query:_identifier partialResults:array perCentDone:prog];
	}
	return;
}

- (NSRange)parse:(BOOL)finish
{
	size_t parseLimit;

	if(finish) {
		parseLimit = curBufSize;
	} else {
#ifdef MONGO_DB
		if(curBufSize < CUSHION) {
			return NSMakeRange(NSNotFound, 1);
		}
#endif
		parseLimit = curBufSize - CUSHION;
	}
	
	unsigned char *ptr		= buffer + parseOffset;
	unsigned char *ptrEnd	= buffer + parseLimit;
	for(; ptr < ptrEnd; ++ptr) {
		unsigned char c = *ptr;
		// NSLog(@"C=%c inString=%d isQuoted=%d", c, inString, isQuoted);
		if(isQuoted) {
			isQuoted = NO;
			continue;
		}
		if(inString) {
			switch(c) {
			case '"':
				if(!isQuoted) {
					inString = NO;
				}
				break;
			case '\\':
				isQuoted = YES;
				break;
#ifdef MONGO_DB
			case ')':
				if(eatObjectIDEnding && ptr[-1] == '\'') {
					ptr[-1] = '"';
					ptr[0] = ' ';
					eatObjectIDEnding = NO;
					inString = NO;
#if 0 //testing
					{
						unsigned char *start = ptr - 1;
						while(*--start != '"') ;
						++start;

						NSString *s = [[NSString alloc] initWithBytes:start length:ptr-start-1 encoding:NSASCIIStringEncoding];
						NSLog(@"OBJECTID[%u] = %@", [s length], s);
					}
#endif

				} else
				if(eatNewDateEnding && ptr[-1] == '\'') {
					unsigned char *start = ptr - 1;
					while(*--start != '"') ;
					++start;
					size_t len = ptr - start - 1;
					NSString *origDate = [[NSString alloc] initWithBytes:start length:len encoding:NSUTF8StringEncoding];
//assert(![dateStr isEqualToString:@"Wed Apr 20 2011 21:02:04 GMT-0400 (EDT)"]);

//NSLog(@"DateSTR: <%@>", dateStr);
					NSString *newDate = [_partialsDelegate dateForDate:origDate];
					const char *newDateCstr = [newDate cStringUsingEncoding:NSUTF8StringEncoding];
					size_t dateLen = strlen(newDateCstr);
					memcpy(start, newDateCstr, dateLen);
					
					unsigned char *midPtr = start+dateLen;
					*midPtr++ = '"';
					memset(midPtr, ' ', len - dateLen + 1);
#if 0 // testing
					{
					--start;
					NSString *str = [[NSString alloc] initWithBytes:start length:ptr - start + 1 encoding:NSASCIIStringEncoding];
					NSLog(@"NEW STRING: <%@>", str);
					}
#endif
					eatNewDateEnding = NO;
					inString = NO;
				}
				break;
#endif // MONGO_DB
			default:
				isQuoted = NO;
				break;
			}
			continue;
		}
		
		switch(c) {
		case '\\':
			isQuoted = YES;
			break;
		case '"':
			inString = YES;
			break;
		case '[':
			++arrayCount;
			// NSLog(@"++ARRAY=%ld", arrayCount);
			break;
		case ']':
			//NSLog(@"--ARRAY=%ld", arrayCount);
			if(!--arrayCount) {
				isDone = YES;
				return NSMakeRange(0, 0);
			}
			break;
		case '{':
			if(dictCount++ == 0) {
				topLevelOffset = ptr - buffer;
			}
			break;
		case '}':
			if(--dictCount == 0) {
				++ptr;
				parseOffset = ptr - buffer;
				NSRange r =  NSMakeRange(topLevelOffset, parseOffset - topLevelOffset);
				topLevelOffset = 0;
				return r;
			}
			break;
	
		// down to numbers, null, true, false, and the two things to fix
#ifdef MONGO_DB
		// need to fix "new Date\\('([^']+)')", so look for 'D'
		// need to fix "ObjectId\\('([^']+)')", so look for 'O'
		case 'D':
			if(!eatNewDateEnding) {
				if(!strncmp((char *)ptr-4, "new Date('", 10)) {
					memcpy(ptr-4, "         \"", 10);
					eatNewDateEnding = YES;
					ptr += 4;	// (10 - 4 - 2) for loops ++ptr gets us to the '''
				}
			} else {
				assert(!"Impossible");
			}
			break;
		case 'O':
			if(!eatObjectIDEnding) {
				if(!strncmp((char *)ptr, "ObjectId('", 10)) {
					memcpy(ptr, "         \"", 10);
					eatObjectIDEnding = YES;
					ptr += 8;	// (10 - 0 - 2) for loops ++ptr gets us to the '''
				}
			} else {
				assert(!"Impossible");
			}
			break;
#endif
		case ':':
			//NSLog(@" %02.2x : %02.2x %02.2x %02.2x %02.2x", ptr[-1], ptr[1], ptr[2], ptr[3], ptr[4]);
			if(ptr[2] == ',' && ptr[-1] == ' ' && ptr[1] == ' ' && !isQuoted && !inString) {
				//NSLog(@"GOTCHA!!!!");
				//memcpy(ptr-1, ":\"\"", 3);
				ptr[1] = '0';
				++ptr;
			}
			break;
		default:
			break;
		}
	}
	parseOffset = ptr - buffer;
	return NSMakeRange(NSNotFound, 0);
}

@end
