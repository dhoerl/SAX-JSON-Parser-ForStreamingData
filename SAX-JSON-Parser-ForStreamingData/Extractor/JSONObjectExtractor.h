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

#import "JSONObjectExtractorProtocol.h"

@interface JSONObjectExtractor : NSObject
@property (nonatomic, assign, readonly) NSUInteger count;			// total count of objects
@property (nonatomic, strong, readonly) NSMutableArray *objects;	// empty or could have objects after the 'addData:nil' message
@property (nonatomic, weak) id identifier;							// if you have multiple processes going at once, you can use this to unique which
@property (nonatomic, assign) NSUInteger totalReceiveSize;			// you set this
@property (nonatomic, assign) NSUInteger currentReceiveSize;		// you set this (long reason why this class didn't update this itself)

- (instancetype)initWithDelegate:(id <JSONObjectExtractorProtocol>)delegate;


// Verify you have an array before creating and using this class
+ (BOOL)isArray:(NSData *)data;

// to finish, send this message with a nil parameter
- (void)addData:(NSData *)data;

@end
