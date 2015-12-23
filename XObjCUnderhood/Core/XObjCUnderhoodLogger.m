//
//  XObjCUnderhood.m
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import "XObjCUnderhoodLogger.h"
#import "XObjCUnderhood.h"
#import <objc/runtime.h>


typedef NS_OPTIONS(NSInteger, XObjcClassType) {
  XObjcClassTypeUndetermined  = 0,
  XObjcClassTypeClass         = 1 << 0,
  XObjcClassTypeMetaclass     = 1 << 1,
};

typedef NS_OPTIONS(NSInteger, XObjcMethodLogOption) {
  XObjcMethodLogOptionNone                      = 0,
  XObjcMethodLogWithSignature                   = 1 << 0,
  XObjcMethodLogWithWithImplementationHierarchy = 1 << 1,
  XObjcMethodLogWithWithProtocol                = 1 << 2,
};


// -----------------------------------------------------------------------------
#pragma mark Indentation
// -----------------------------------------------------------------------------

// Indentation for levels
static NSString *_indentationForLevels(NSUInteger level)
{
  // We use a tab for a identation level. You can change the identation if you want.
#define INDT @"  "
  
  switch (level) {
    case  0: return @"";
    case  1: return INDT;
    case  2: return INDT INDT;
    case  3: return INDT INDT INDT;
    case  4: return INDT INDT INDT INDT;
    case  5: return INDT INDT INDT INDT INDT;
    case  6: return INDT INDT INDT INDT INDT INDT;
    case  7: return INDT INDT INDT INDT INDT INDT INDT;
    case  8: return INDT INDT INDT INDT INDT INDT INDT INDT;
    case  9: return INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 10: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 11: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 12: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 13: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 14: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 15: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 16: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 17: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 18: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 19: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    case 20: return INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT INDT;
    default:
      return [_indentationForLevels(20) stringByAppendingString:_indentationForLevels(level-20)];
  }
}

// -----------------------------------------------------------------------------
// Private functions
// -----------------------------------------------------------------------------

extern NSDictionary *_methodListForClass(Class klass);


// -----------------------------------------------------------------------------
#pragma mark Private functions
// -----------------------------------------------------------------------------

static void _logSubclassesForClass(NSString *className, XOrderedDict *subclasses, NSUInteger logLevel)
{
  // Print
  NSString *identationString = _indentationForLevels(logLevel);
  NSString *logString = [identationString stringByAppendingFormat:@"* %@", className];
  printf("%s\n", logString.UTF8String);
  
  // Recursively call
  NSUInteger nextLogLevel = ++logLevel;
  for (NSString *className in subclasses) {
    _logSubclassesForClass(className, subclasses[className], nextLogLevel);
  }
}

static void _printInterfaceThroughHierarchy(XOrderedDict *interfaceLookup, NSString *key, const char *methodSymbol, BOOL needsToShowImpClass)
{
  NSMutableSet *methods                      = [NSMutableSet set];
  NSMutableDictionary *classesForMethodImp   = [NSMutableDictionary dictionary];
  NSMutableDictionary *signatureForMethodImp = [NSMutableDictionary dictionary];
  
  for (NSString *className in interfaceLookup) {
    NSDictionary *methodList = interfaceLookup[className][key];
    for (NSString *methodName in methodList) {
      NSMutableArray *impClassForMethod = classesForMethodImp[methodName];
      if (impClassForMethod) {
        [impClassForMethod addObject:className];
      } else {
        // First registration
        classesForMethodImp[methodName] = [NSMutableArray arrayWithObject:className];
        // Addtional jobs
        [methods addObject:methodName];
        signatureForMethodImp[methodName] = methodList[methodName];
      }
    }
  }
  
  if (needsToShowImpClass) {
    [[methods xobjc_sortedAllObjects] enumerateObjectsUsingBlock:^(NSString *methodInfo, NSUInteger idx, BOOL *stop) {
      printf("\t(%lu) %s%s\t\t{%s}\t@(%s)\n", (unsigned long)idx, methodSymbol, methodInfo.UTF8String, [signatureForMethodImp[methodInfo] UTF8String], [(NSArray *)classesForMethodImp[methodInfo] componentsJoinedByString:@", "].UTF8String);
    }];
    
  } else {
    [[methods xobjc_sortedAllObjects] enumerateObjectsUsingBlock:^(NSString *methodInfo, NSUInteger idx, BOOL *stop) {
      printf("\t(%lu) %s%s\t\t{%s}\n", (unsigned long)idx, methodSymbol, methodInfo.UTF8String, [signatureForMethodImp[methodInfo] UTF8String]);
    }];
    
  }
}

static void xobjc_logMethodListForClassHierarchyWithOptions(XObjcClassType type, const char *className, const char *toSuperclassName, XObjcMethodLogOption logOption)
{
  // Print info
  NSArray *classHierarchy = xobjc_superclassesOfClass(objc_getClass(className));
  NSString *toSuperclassNameString = toSuperclassName ? [NSString stringWithUTF8String:toSuperclassName] : nil;
  if (toSuperclassNameString) {
    NSUInteger index = [classHierarchy indexOfObject:toSuperclassNameString];
    if (index != NSNotFound) {
      classHierarchy = [classHierarchy subarrayWithRange:NSMakeRange(0, index + 1)];
    }
  }
  
  // Build up the interfaces through the class hierarchy.
  Class startClass = objc_getClass(className);
  Class endClass = objc_getClass(toSuperclassName);
  NSMutableArray *searchedClassName             = [NSMutableArray array];
  NSMutableArray *searchedImplementedInterfaces = [NSMutableArray array];
  
  Class searchClass = startClass;
  while (searchClass) {
    // Add the key-value pair to arrays
    NSDictionary *implementedInterfaceForClass = xobjc_implementedInterfaceForClass(searchClass);
    [searchedClassName addObject:@(class_getName(searchClass))];
    [searchedImplementedInterfaces addObject:implementedInterfaceForClass];
    // Continue search if needed
    if (searchClass == endClass) {
      break;
    } else {
      searchClass = class_getSuperclass(searchClass);
    }
  }
  
  XOrderedDict *interfaceLookup = [XOrderedDict orderedDictionaryWithObjects:searchedImplementedInterfaces forKeys:searchedClassName];
  BOOL needsToShowImpClass = (startClass != endClass);
  
  // Start print
  printf("<%s> method list: {\n", [classHierarchy componentsJoinedByString:@" : "].UTF8String);
  
  if (type & XObjcClassTypeMetaclass) {
    printf("  Implemented Class Methods:\n");
    _printInterfaceThroughHierarchy(interfaceLookup, @"class_methods", "+", needsToShowImpClass);
  }
  
  if (type & XObjcClassTypeClass) {
    printf("  Implemented Instance Methods:\n");
    _printInterfaceThroughHierarchy(interfaceLookup, @"instance_methods", "-", needsToShowImpClass);
    printf("  Implemented Properties:\n");
    _printInterfaceThroughHierarchy(interfaceLookup, @"property", "@", needsToShowImpClass);
  }
  
  printf("}\n");
}

static void xobjc_logOrderedDict(XOrderedDict *orderedDict)
{
  NSUInteger count = orderedDict.count;
  for (NSUInteger i = 0; i < count; i++) {
    NSString *key = [orderedDict keyAtIndex:i];
    id value = [orderedDict objectForKey:key];
    printf("* %s: %s\n", [key UTF8String], [[value description] UTF8String]);
  }
}

// -----------------------------------------------------------------------------
#pragma mark Log functions
// -----------------------------------------------------------------------------

XOBJC_OVERLOADABLE void xobjc_logHierarchyForClass(const char *className)
{
  NSArray *classHierarchy = xobjc_superclassesOfClass(className);
  NSString *classHierarchyDescription = [classHierarchy componentsJoinedByString:@" : "];
  printf("%s\n", classHierarchyDescription.UTF8String);
}

XOBJC_OVERLOADABLE void xobjc_logSubclassesForClass(const char *className)
{
  XOrderedDict *subclasses = xobjc_subclassesOfClass(className);
  if (subclasses) {
    _logSubclassesForClass(@(className), subclasses, 0);
  }
}

XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(const char *className)
{
  xobjc_logMethodListForClassHierarchy(className, nil);
}

XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(const char *className, const char *superclassName)
{
  XObjcClassType type = XObjcClassTypeClass | XObjcClassTypeMetaclass;
  XObjcMethodLogOption logOption = XObjcMethodLogWithSignature | XObjcMethodLogWithWithImplementationHierarchy | XObjcMethodLogWithWithProtocol;
  xobjc_logMethodListForClassHierarchyWithOptions(type, className, superclassName, logOption);
  return;
}

XOBJC_OVERLOADABLE void xobjc_logAllClassesForProtocol(const char *protocolName)
{
  XOrderedDict *allClasses = xobjc_allClassesForProtocol(protocolName);
  xobjc_logOrderedDict(allClasses);
}

