/**
 *  @file JSONObjectExtractor.h
 *  DB_Lookup
 *
 *  Copyright 2014 David Hoerl
 *
 * @section LICENSE
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http: //www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 * @section DESCRIPTION
 *
 * The time class represents a moment of time.
 */

#import "JSONObjectExtractorProtocol.h"

@interface JSONObjectExtractor : NSObject
@property (nonatomic, assign, readonly) NSUInteger count;			///< Total count of objects regardless of how the delegate messages are used
@property (nonatomic, strong, readonly) NSMutableArray *objects;	///< Empty or could have objects after the 'addData:nil' message, depending on what delegate messages defined
@property (nonatomic, weak) id identifier;							///< if you have multiple processes going at once, you can use this to unique which
@property (nonatomic, assign) NSUInteger totalReceiveSize;			///< Set the complete download size—for progress reporting. If unset
																	///< the progress dictionary will only contain \c currentReceiveSize\c.

@property (nonatomic, assign) NSUInteger currentReceiveSize;		///< You update this before every addData: message (long reason why this class does not do it)

- (instancetype)initWithDelegate:(id <JSONObjectExtractorProtocol>)delegate; ///< Required delegate, weakly referenced

+ (BOOL)isArray:(NSData *)data;										///< Verify you have an array before creating and using this class

- (void)addData:(NSData *)data;										///< Data will be a valid object followed by a final message with nil to finalize the processing.

@end
