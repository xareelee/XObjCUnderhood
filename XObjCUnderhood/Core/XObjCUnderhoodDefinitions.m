//
//  XObjCUnderhood.h
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//


#import "XObjCUnderhoodDefinitions.h"

@implementation XOrderedDict (Creation)

+ (instancetype)orderedDictionaryWithObjects:(NSArray *)objects forKeys:(NSArray *)keys;
{
  return [[XOrderedDict alloc] initWithObjects:objects pairedWithKeys:keys];
}

- (BOOL)containsKey:(id)key;
{
  return [keys containsObject:key];
}

@end

// -----------------------------------------------------------------------------
@implementation NSArray (Sorted)

- (NSArray *)xobjc_sortedByCompare;
{
  return [self sortedArrayUsingSelector:@selector(compare:)];
}

@end

// -----------------------------------------------------------------------------

@implementation NSSet (SortedArray)

- (NSArray *)xobjc_sortedAllObjects;
{
  return [[self allObjects] xobjc_sortedByCompare];
}

@end