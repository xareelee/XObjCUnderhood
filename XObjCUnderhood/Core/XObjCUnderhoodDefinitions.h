//
//  XObjCUnderhood.h
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import "M13OrderedDictionary.h"


#define XOBJC_OVERLOADABLE __attribute__((overloadable))

@compatibility_alias XOrderedList NSArray;
@compatibility_alias XOrderedDict M13OrderedDictionary;
@compatibility_alias XMutableOrderedDict M13MutableOrderedDictionary;


@interface XOrderedDict (Creation)
+ (instancetype)orderedDictionaryWithObjects:(NSArray *)objects forKeys:(NSArray *)keys;
- (BOOL)containsKey:(id)key;
@end

@interface NSArray (Sorted)
- (NSArray *)xobjc_sortedByCompare;
@end

@interface NSSet (SortedArray)
- (NSArray *)xobjc_sortedAllObjects;
@end





