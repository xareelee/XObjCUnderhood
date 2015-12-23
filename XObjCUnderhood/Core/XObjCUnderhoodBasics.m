//
//  XObjCUnderhood.m
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import "XObjCUnderhoodBasics.h"
#import <objc/runtime.h>
#import <CoreGraphics/CoreGraphics.h>


// -----------------------------------------------------------------------------
// Flags
// -----------------------------------------------------------------------------
#define Use_Pretty_Property_Description
#define Use_Pretty_Method_Signature_Description
#define XOBJC_Use_Common_Type
//#define XOBJC_Use_Detailed_Type_Annotation


// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
NSString const *kXObjCUnderhoodRootClassKey = @"$root_classes";
NSString const *kXObjCUnderhoodRootProtocolKey = @"$root_protocols";

static NSString const *kClassMethodListKey    = @"Class method list";
static NSString const *kInstanceMethodListKey = @"Instance method list";


// -----------------------------------------------------------------------------
// Private functions
// -----------------------------------------------------------------------------
static NSSet *_adoptedProtocolsForProtocol(Protocol *protocol);
static NSArray *_protocolsForClass(Class klass);

static NSSet *_subProtocolSet(XOrderedDict *lookup, NSString *protocolName);
static NSSet *_superProtocolSet(XOrderedDict *lookup, NSString *protocolName);

static NSString *_prettyDescriptionForTypeEncoding(NSString *typeEncoding);

// -----------------------------------------------------------------------------
#pragma mark Helper functions
// -----------------------------------------------------------------------------

static NSSet *_adoptedProtocolsForProtocol(Protocol *protocol)
{
  unsigned int adoptedProtocolsCount;
  Protocol * __unsafe_unretained * adoptedProtocols = protocol_copyProtocolList(protocol, &adoptedProtocolsCount);
  
  if (adoptedProtocolsCount == 0) {
    return [NSSet set];
  }
  
  NSMutableSet *adoptedProtocolSet = [NSMutableSet setWithCapacity:adoptedProtocolsCount];
  for (unsigned i = 0; i < adoptedProtocolsCount; i++) {
    [adoptedProtocolSet addObject:NSStringFromProtocol(adoptedProtocols[i])];
  }
  
  if (adoptedProtocols) {
    free(adoptedProtocols);
  }
  return adoptedProtocolSet;
}

static NSArray *_protocolsForClass(Class klass)
{
  unsigned int outCount;
  Protocol * __unsafe_unretained *protocols = class_copyProtocolList(klass, &outCount);
  
  NSMutableArray *protocolList = [NSMutableArray array];
  for (int i = 0; i < outCount; i++) {
    NSString *protocolName = [NSString stringWithUTF8String:protocol_getName(protocols[i])];
    [protocolList addObject:protocolName];
  }
  if (protocols) {
    free(protocols);
  }
  return protocolList;
}


// -----------------------------------------------------------------------------
#pragma Build up
// -----------------------------------------------------------------------------

static XOrderedDict *__classHierarchyLookup__;
static XOrderedDict *__subProtocolSetLookup__;
static XOrderedDict *__superProtocolSetLookup__;
static XOrderedDict *__classesForProtocolSetLookup__;

XOrderedDict *xobjc_classHierarchyLookUp() { return __classHierarchyLookup__; }
XOrderedDict *xobjc_subProtocolsLookup() { return __subProtocolSetLookup__; }
XOrderedDict *xobjc_superProtocolsLookup() { return __superProtocolSetLookup__; }
XOrderedDict *xobjc_classesForProtocolsLookup() { return __classesForProtocolSetLookup__; }

void xobjc_underhood_setup()
{
  // Get all classes and Protocols
  unsigned int numberOfClasses;
  Class *classes  =objc_copyClassList(&numberOfClasses);
  
  unsigned int numberOfProtocols;
  Protocol * __unsafe_unretained *protocols = objc_copyProtocolList(&numberOfProtocols);
  
  NSLog(@"[XObjCUnderhood] Start building class and protocol lookup\n");
  NSLog(@"[XObjCUnderhood] Total classes in runtime: %d", numberOfClasses);
  NSLog(@"[XObjCUnderhood] Total protocols in runtime: %d", numberOfProtocols);
  
  // -------------------------------------------
  // Prepare for collections for building lookup
  // -------------------------------------------
  NSMutableSet *protocolSet = [NSMutableSet setWithCapacity:(NSUInteger)numberOfProtocols];
  NSMutableDictionary *classSetForProtocolLookup = [NSMutableDictionary dictionaryWithCapacity:numberOfProtocols];
  NSMutableDictionary *superProtocolDict         = [NSMutableDictionary dictionaryWithCapacity:numberOfProtocols];
  NSMutableDictionary *subProtocolDict           = [NSMutableDictionary dictionaryWithCapacity:numberOfProtocols + 1];

  // Prepare collection for class hierarchy
  NSMutableSet *classSet    = [NSMutableSet setWithCapacity:numberOfClasses];
  NSMutableDictionary *subclassDict = [NSMutableDictionary dictionaryWithCapacity:numberOfClasses / 5];
  
  // -----------------
  // Iterate protocols
  // -----------------
  for (unsigned int i = 0; i < numberOfProtocols; i++) {
    
    // Get the protocol name
    Protocol *protocol = protocols[i];
    NSString *protocolName = NSStringFromProtocol(protocol);
    
    // Build protocolSet
    if (![protocolSet containsObject:protocolName]) {
      [protocolSet addObject:protocolName];
    } else {
      NSLog(@"[XObjCUnderhood] Find a duplicated protocol: %@", protocolName);
      continue;
    }
    
    //
    classSetForProtocolLookup[protocolName] = [NSMutableSet set];
    
    // Get super protocols
    NSSet *superProtocolsForProtocol = _adoptedProtocolsForProtocol(protocol);
    
    // Build super protocol dict
    superProtocolDict[protocolName] = superProtocolsForProtocol;
    
    // Build sub protocol dict
    NSSet *superProtocols = (superProtocolsForProtocol.count) ? superProtocolsForProtocol : [NSSet setWithObject:kXObjCUnderhoodRootProtocolKey];
    for (NSString *superProtocol in superProtocols) {
      NSMutableSet *subProtocolSet = subProtocolDict[superProtocol];
      if (subProtocolSet) {
        [subProtocolSet addObject:protocolName];
      } else {
        subProtocolDict[superProtocol] = [NSMutableSet setWithObject:protocolName];
      }
    }

  }
  if (protocols) {
    free(protocols);
  }
  
  
  // ---------------
  // Iterate classes
  // ---------------
  for (unsigned int i = 0; i < numberOfClasses; i++) {
    // If the class is a root class, we will use `kXObjCUnderhoodRootClassKey`
    // as its superclass in the build.
    Class cls                = classes[i];
    NSString *className      = NSStringFromClass(cls);
    NSString *superclassName = NSStringFromClass(class_getSuperclass(cls)) ?: kXObjCUnderhoodRootClassKey;
    
    // Build classSet
    if (![classSet containsObject:className]) {
      [classSet addObject:className];
    } else {
      NSLog(@"[XObjCUnderhood] Find a duplicated class: %@ (superclass: %@)", className, superclassName);
    }
    
    // Build subclassDict
    NSMutableSet *subclassSet = subclassDict[superclassName];
    if (subclassSet) {
      [subclassSet addObject:className];
    } else {
      subclassDict[superclassName] = [NSMutableSet setWithObject:className];
    }
    
    // Protocols for class
    NSArray *adoptingProtocols = _protocolsForClass(cls);
    for (NSString *protocolName in adoptingProtocols) {
      [(NSMutableSet *)classSetForProtocolLookup[protocolName] addObject:className];
    }
  }
  if (classes) free(classes);
  
  
  // -------------------------------------
  // Sort the protocols and classes (Keys)
  // -------------------------------------
  NSArray *protocolNamesWithoutRootKey = [protocolSet xobjc_sortedAllObjects];
  NSArray *uniqueProtocolNames         = [protocolNamesWithoutRootKey arrayByAddingObject:kXObjCUnderhoodRootProtocolKey];
  NSArray *uniqueClassNames            = [[classSet xobjc_sortedAllObjects] arrayByAddingObject:kXObjCUnderhoodRootClassKey];
  
  
  // --------------------------------------------
  // Sort the protocol set and class set (Values)
  // --------------------------------------------
  NSArray *emptyArray = [NSArray array];
  NSMutableArray<XOrderedList *> *subclassSets           = [NSMutableArray arrayWithCapacity:uniqueClassNames.count];
  NSMutableArray<XOrderedList *> *subProtocolSets        = [NSMutableArray arrayWithCapacity:uniqueProtocolNames.count];
  NSMutableArray<XOrderedList *> *superProtocolSets      = [NSMutableArray arrayWithCapacity:uniqueProtocolNames.count];
  NSMutableArray<XOrderedList *> *classesForProtocolSets = [NSMutableArray arrayWithCapacity:uniqueClassNames.count];
  
  for (NSString *className in uniqueClassNames) {
    NSArray *subclassArray = [(NSSet *)subclassDict[className] xobjc_sortedAllObjects];
    [subclassSets addObject:(subclassArray ?: emptyArray)];
  }

  for (NSString *protocolName in protocolNamesWithoutRootKey) {
    // sub protocols
    NSArray *subProtocolArray = [(NSSet *)subProtocolDict[protocolName] xobjc_sortedAllObjects];
    [subProtocolSets addObject:(subProtocolArray ?: emptyArray)];
    // seper protocols
    NSArray *superProtocolArray = [(NSSet *)superProtocolDict[protocolName] xobjc_sortedAllObjects];
    [superProtocolSets addObject:(superProtocolArray ?: emptyArray)];
    // classes for protocol
    NSArray *classesForProtocolArray = [(NSSet *)classSetForProtocolLookup[protocolName] xobjc_sortedAllObjects];
    [classesForProtocolSets addObject:(classesForProtocolArray ?: emptyArray)];
  }
  
  // sub protocols for the root protocol key
  NSArray *subProtocolArray = [(NSSet *)subProtocolDict[kXObjCUnderhoodRootProtocolKey] xobjc_sortedAllObjects];
  [subProtocolSets addObject:(subProtocolArray ?: emptyArray)];

  
  // ------------------------
  // Build ordered dictionary
  // ------------------------
  __classHierarchyLookup__        = [XOrderedDict orderedDictionaryWithObjects:subclassSets forKeys:uniqueClassNames];
  __subProtocolSetLookup__        = [XOrderedDict orderedDictionaryWithObjects:subProtocolSets forKeys:uniqueProtocolNames];
  __superProtocolSetLookup__      = [XOrderedDict orderedDictionaryWithObjects:superProtocolSets forKeys:protocolNamesWithoutRootKey];
  __classesForProtocolSetLookup__ = [XOrderedDict orderedDictionaryWithObjects:classesForProtocolSets forKeys:protocolNamesWithoutRootKey];
  
  NSLog(@"[XObjCUnderhood] Classes count: %d/%u (containing the additional key `$root_classes` (kXObjCUnderhoodRootClassKey) for root classes)\n", (int)(uniqueClassNames.count -1), numberOfClasses);
  NSLog(@"[XObjCUnderhood] Protocol count: %d/%u (containing the additional key `$root_protocols` (kXObjCUnderhoodRootProtocolKey) for root protocols)\n", (int)(uniqueProtocolNames.count -1), numberOfProtocols);
}



// -----------------------------------------------------------------------------
#pragma mark Class Hierarchy
// -----------------------------------------------------------------------------

XOBJC_OVERLOADABLE NSArray *xobjc_superclassesOfClass(const char *className)
{
  NSMutableArray *superclasses = [NSMutableArray array];
  Class cls = objc_getClass(className);
  while (cls) {
    [superclasses addObject:@(class_getName(cls))];
    cls = class_getSuperclass(cls);
  }
  return [superclasses copy];
}

static XOrderedDict *_subclassesLookupForClass(XOrderedDict *lookup, NSString *className)
{
  XOrderedList *subclasses = lookup[className];
  NSUInteger count = subclasses.count;
  
  if (count == 0) {
    return [XOrderedDict orderedDictionary];
  }
  
  NSMutableArray *subsubclasses = [NSMutableArray arrayWithCapacity:count];
  for (NSString *subclassName in subclasses) {
    [subsubclasses addObject:_subclassesLookupForClass(lookup, subclassName)];
  }
  
  XOrderedDict *orderedDict = [XOrderedDict orderedDictionaryWithObjects:subsubclasses forKeys:subclasses];
  return orderedDict;
}

XOBJC_OVERLOADABLE XOrderedDict *xobjc_subclassesOfClass(const char *className)
{
  Class cls = objc_getClass(className);
  if (!cls) {
    printf("Class name `%s` does not exist.\n", className);
    return nil;
  }
  return _subclassesLookupForClass(xobjc_classHierarchyLookUp(), @(className));
}


// -----------------------------------------------------------------------------
#pragma mark Protocols
// -----------------------------------------------------------------------------

XOBJC_OVERLOADABLE XOrderedDict *xobjc_protocolsForClassInHierarchy(const char *className)
{
  XOrderedDict *lookup          = xobjc_superProtocolsLookup();
  NSArray *classHierarchy       = xobjc_superclassesOfClass(className);
  NSMutableArray *protocolInfos = [NSMutableArray arrayWithCapacity:classHierarchy.count];
  for (NSString *classNameInHierarchy in classHierarchy) {
    NSArray *protocols = [_protocolsForClass(NSClassFromString(classNameInHierarchy)) xobjc_sortedByCompare];
    NSMutableArray *superProtocols = [NSMutableArray arrayWithCapacity:protocols.count];
    for (NSString *protocolName in protocols) {
      NSArray *superProtocol = [_superProtocolSet(lookup, protocolName) xobjc_sortedAllObjects];
      [superProtocols addObject:superProtocol];
    }
    XOrderedDict *protocolInfo = [XOrderedDict orderedDictionaryWithObjects:superProtocols forKeys:protocols];
    [protocolInfos addObject:protocolInfo];
  }
  XOrderedDict *protocolsForClass = [XOrderedDict orderedDictionaryWithObjects:protocolInfos forKeys:classHierarchy];
  return protocolsForClass;
}

XOBJC_OVERLOADABLE NSArray *xobjc_protocolsForClass(const char *className)
{
  XOrderedDict *protocolsForClassInHierarchy = xobjc_protocolsForClassInHierarchy(className);
  NSMutableSet *protocols = [NSMutableSet set];
  
  for (NSString *className in protocolsForClassInHierarchy) {
    XOrderedDict *protocolsForClass = protocolsForClassInHierarchy[className];
    NSArray *allKeys    = protocolsForClass.allKeys;
    NSArray *allObjects = [protocolsForClass.allObjects valueForKeyPath: @"@unionOfArrays.self"];
    [protocols addObjectsFromArray:allKeys];
    [protocols addObjectsFromArray:allObjects];
  }
  
  return [protocols xobjc_sortedAllObjects];
}


// -----------------------------------------------------------------------------
#pragma mark Protocol-Class
// -----------------------------------------------------------------------------

static NSSet *_subProtocolSet(XOrderedDict *lookup, NSString *protocolName)
{
  NSArray *subProtocols = lookup[protocolName];
  NSMutableSet *protocolSet = [NSMutableSet setWithArray:subProtocols];
  for (NSString *subProtocolName in subProtocols) {
    [protocolSet unionSet:_subProtocolSet(lookup, subProtocolName)];
  }
  return protocolSet;
}

XOBJC_OVERLOADABLE NSSet *xobjc_subProtocolSet(const char *protocolName)
{
  XOrderedDict *lookup = xobjc_subProtocolsLookup();
  return _subProtocolSet(lookup, @(protocolName));
}

static NSSet *_superProtocolSet(XOrderedDict *lookup, NSString *protocolName)
{
  NSArray *subProtocols = lookup[protocolName];
  NSMutableSet *protocolSet = [NSMutableSet setWithArray:subProtocols];
  for (NSString *subProtocolName in subProtocols) {
    [protocolSet unionSet:_subProtocolSet(lookup, subProtocolName)];
  }
  return protocolSet;
}

XOBJC_OVERLOADABLE NSSet *xobjc_superProtocolSet(const char *protocolName)
{
  XOrderedDict *lookup = xobjc_superProtocolsLookup();
  return _superProtocolSet(lookup, @(protocolName));
}

XOBJC_OVERLOADABLE NSArray *xobjc_classesJustAdoptingProtocol(const char *protocolName)
{
  if (!objc_getProtocol(protocolName)) {
    // Protocol is not found.
    return nil;
  }
  
  XOrderedDict *classesForProtocolsLookup = xobjc_classesForProtocolsLookup();
  NSArray *classesForProtocol = classesForProtocolsLookup[@(protocolName)];

  return classesForProtocol;
}

XOBJC_OVERLOADABLE NSArray *xobjc_classesForProtocol(const char *protocolName)
{
  if (!objc_getProtocol(protocolName)) {
    // Protocol is not found.
    return nil;
  }
  
  // Find all classes which adopt the protocol and all its sub-protocols.
  NSSet *classesAdoptingProtocol = [NSSet set];
  NSSet *totalProtocols = [xobjc_subProtocolSet(protocolName) setByAddingObject:@(protocolName)];
  XOrderedDict *classesForProtocolsLookup = xobjc_classesForProtocolsLookup();
  for (NSString *protocolName in totalProtocols) {
    NSArray *classesForProtocol = classesForProtocolsLookup[protocolName];
    classesAdoptingProtocol = [classesAdoptingProtocol setByAddingObjectsFromArray:classesForProtocol];
  }
  return [classesAdoptingProtocol xobjc_sortedAllObjects];
}

XOBJC_OVERLOADABLE NSArray *xobjc_commonClassesForProtocol(const char *protocolName)
{
  NSArray *classesForProtocol = xobjc_classesForProtocol(protocolName);
  if (!classesForProtocol) {
    return nil;
  }
  
  // Find the common classes.
  NSMutableSet *commonClasses = [NSMutableSet setWithCapacity:classesForProtocol.count];
  for (NSString *className in classesForProtocol) {
    NSArray *classHierarchy = xobjc_superclassesOfClass(className.UTF8String);
    NSString *commonClass = nil;
    // Search from the class to the root class.
    for (NSString *possibleCommonClassName in classHierarchy) {
      if ([classesForProtocol containsObject:possibleCommonClassName]) {
        commonClass = possibleCommonClassName;
      }
    }
    if (commonClass) {
      [commonClasses addObject:commonClass];
    }
  }
  
  NSArray *commonClassesForProtocol = [commonClasses xobjc_sortedAllObjects];
  return commonClassesForProtocol;
}

XOBJC_OVERLOADABLE XOrderedDict *xobjc_allClassesForProtocol(const char *protocolName)
{
  NSArray *commonClassesForProtocol = xobjc_commonClassesForProtocol(protocolName);
  if (!commonClassesForProtocol) {
    return nil;
  }
  
  NSMutableArray *subclassesForCommonClasses = [NSMutableArray arrayWithCapacity:commonClassesForProtocol.count];
  for (NSString *className in commonClassesForProtocol) {
    XOrderedDict *subclassesForClass = xobjc_subclassesOfClass(className.UTF8String);
    [subclassesForCommonClasses addObject:subclassesForClass];
  }
  
  XOrderedDict *allClassesForProtocol = [XOrderedDict orderedDictionaryWithObjects:subclassesForCommonClasses forKeys:commonClassesForProtocol];
  return allClassesForProtocol;
}


// -----------------------------------------------------------------------------
#pragma mark Type Encoding
// -----------------------------------------------------------------------------

static NSString *_removeTypeOffsetFromSignature(NSString *signature)
{
  NSInteger offset = [signature integerValue];
  if (offset == 0 && ![signature hasPrefix:@"0"]) {
    // Failed to remove the offset
    return signature;
  }
  return [signature substringFromIndex:[@(offset) stringValue].length];
}

static void _parseTypsFormMethodSignature(NSString *signature, NSMutableArray *parsedElements)
{
  if (signature.length == 0) {
    return;
  }
  
#define XOBJC_PARSE_SIGNATURE_FOR_TYPE(PARSED_ELEMENTS, SIGNATURE, TYPE, ...) \
  XOBJC_PARSE_SIGNATURE_FOR_TYPE_(PARSED_ELEMENTS, SIGNATURE, TYPE, ## __VA_ARGS__, #TYPE)

#define XOBJC_PARSE_SIGNATURE_FOR_TYPE_(PARSED_ELEMENTS, SIGNATURE, TYPE, REPRESENTATIVE, ...) \
  do { \
    NSString *type = @(@encode(TYPE)); \
    if ([SIGNATURE hasPrefix:type]) { \
      [PARSED_ELEMENTS addObject:@REPRESENTATIVE]; \
      NSString *residueSignature = _removeTypeOffsetFromSignature([SIGNATURE substringFromIndex:type.length]); \
      return _parseTypsFormMethodSignature(residueSignature, PARSED_ELEMENTS); \
    } \
  } while (0)
  
  // Try to find the matched type encoding.
  /*`B`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, BOOL);
  /*`B`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, bool, "BOOL");
  /*`:`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, SEL);
  /*`#`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, Class);
  /*`@?`*/  XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, void(^)(void), "{BlockObject}");
  /*`@`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, id);
  
#ifdef XOBJC_Use_Common_Type
  XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, NSInteger, "NSInteger?");
  XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, NSUInteger, "NSUInteger?");
#endif
  
  // Simple C types
  /*`d`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, double);
  /*`f`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, float);
  // `long` and `unsigned long` may be `q` and `Q` in 64-bit runtime
  /*`l`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, long);
  /*`L`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, unsigned long);
  /*`i`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, int);
  /*`I`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, unsigned int);
  /*`c`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, char);
  /*`C`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, unsigned char);
  /*`s`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, short);
  /*`S`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, unsigned short);
  /*`q`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, long long);
  /*`Q`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, unsigned long long);
  /*`*`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, char *);
  /*`v`*/   XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, void);
  /*`^?`*/  XOBJC_PARSE_SIGNATURE_FOR_TYPE(parsedElements, signature, void(*)(void), "{FunctionPointer?}");

  
  // No matched type encoding was found. Add the residue signature to array.
  [parsedElements addObject:signature];
}

static NSString *_prettyDescriptionForSignature(NSString *signature, NSString *selectorName)
{
  NSUInteger paramCount = [selectorName componentsSeparatedByString:@":"].count - 1;
  NSMutableArray *types = [NSMutableArray arrayWithCapacity:paramCount + 3];
  _parseTypsFormMethodSignature(signature, types);
  
  NSString *signatureDescription;
  if (types.count < 2) {
    signatureDescription = [NSString stringWithFormat:@"<?:%@>", signature];
  } else if (types.count >= 3 && [types[2] isEqualToString:@"SEL"]) {
    // A Objective-C method signatrue.
    NSArray *params = [types subarrayWithRange:NSMakeRange(3, types.count - 3)];
    signatureDescription = [NSString stringWithFormat:@"[%@](%@)", types[0], [params componentsJoinedByString:@","]];
  } else {
    // A block siganture
    NSArray *params = [types subarrayWithRange:NSMakeRange(2, types.count - 2)];
    signatureDescription = [NSString stringWithFormat:@"[%@](%@)", types[0], [params componentsJoinedByString:@","]];
  }
  //NSLog(@"signatureDescription (param count: %ld): %@", paramCount, signatureDescription);
  return signatureDescription;
}


static NSString *_prettyDescriptionForMethodEncoding(NSString *argType)
{
  // Encoding for type qualifiers
  // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-BABHAIFA
  
#define RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(TYPE_ENCODINE, QUALIFIER_ENCODING, QUALIFIER) \
  do { \
    if ([TYPE_ENCODINE hasPrefix:@QUALIFIER_ENCODING]) { \
      NSString *qualifierPrefix = (@ # QUALIFIER @" "); \
      NSString *convertedResidue = _prettyDescriptionForMethodEncoding([TYPE_ENCODINE substringFromIndex:(@QUALIFIER_ENCODING.length)]);\
      return [qualifierPrefix stringByAppendingString:convertedResidue]; \
    } \
  } while(0)
  
  // Find and replace the type qualifier encoding prefix.
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "r", const);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "n", in);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "N", inout);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "o", out);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "O", bycopy);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "R", byref);
  RETURN_AND_STRIP_TYPE_QUALIFIER_FOR_SIGNATURE(argType, "V", oneway);
  
  // No type qualifier found. Start to translate the type encoding.
  return _prettyDescriptionForTypeEncoding(argType);
}

static NSString *_signatureDescriptionForMethod(Method method)
{
#ifndef Use_Pretty_Method_Signature_Description
  return @(method_getTypeEncoding(method));
#else
  
  // Argument types
  NSString *argumentDescription;
  unsigned int numberOfArguments = method_getNumberOfArguments(method);
  
  if (numberOfArguments <= 2) {
    argumentDescription = @"";
  } else {
    NSMutableArray *argumentTypes = [NSMutableArray arrayWithCapacity:(NSUInteger)numberOfArguments];
    for (unsigned int i = 2; i < numberOfArguments; i++) {
      char *argumentType = method_copyArgumentType(method, i);
      [argumentTypes addObject:_prettyDescriptionForMethodEncoding(@(argumentType))];
      free(argumentType);
    }
    argumentDescription = [NSString stringWithFormat:@"(%@)", [argumentTypes componentsJoinedByString:@","]];
  }
  
  // Return type
  char *returnTypeEncode = method_copyReturnType(method);
  NSString *returnType = _prettyDescriptionForMethodEncoding(@(returnTypeEncode));
  free(returnTypeEncode);
  
  // Pretty method signature description
  NSString *methodSignatureDescription = [NSString stringWithFormat:@"[%@]%@", returnType, argumentDescription];;
  return methodSignatureDescription;
#endif
}

static NSString *_prettyDescriptionForTypeEncoding(NSString *typeEncoding)
{
  // type encoding:
  // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
  
  // ---------------------------------------------------------------------------
  // Complex types
  // ---------------------------------------------------------------------------
  // A specific Objective-C class type
  if ([typeEncoding hasPrefix:@"@\""]) {
    NSRange range = NSMakeRange(2, typeEncoding.length - 3);
    NSString *extractedObjectType = [typeEncoding substringWithRange:range];
    return ([extractedObjectType hasPrefix:@"<"]
            ? [@"id" stringByAppendingString:extractedObjectType]
            : [extractedObjectType stringByAppendingString:@" *"]);
  }
  
  // {}: C struct
  if ([typeEncoding hasPrefix:@"{"]) {
    NSRange equalSign = [typeEncoding rangeOfString:@"="];
    NSRange closeSign = [typeEncoding rangeOfString:@"}"];
    NSUInteger end = MIN(equalSign.location, closeSign.location);
    NSRange range = NSMakeRange(1, end-1);
    NSString *extractedObjectType = [typeEncoding substringWithRange:range];
    return extractedObjectType;
  }
  
  // `^`: point to type
  if ([typeEncoding hasPrefix:@"^"]) {
    return [_prettyDescriptionForTypeEncoding([typeEncoding substringFromIndex:1]) stringByAppendingString:@"*"];
  }

  // ---------------------------------------------------------------------------
  // Simple types
  // ---------------------------------------------------------------------------
  static const char * desc_NSInteger  = "NSInteger?";
  static const char * desc_NSUInteger = "NSUInteger?";
  
#ifdef XOBJC_Use_Detailed_Type_Annotation
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    
  #define BUILD_TYPE_MATCHES(MUTABLE_ARRAY, TYPE1, TYPE2) \
    do { \
      if ((strcmp( @encode(TYPE1), @encode(TYPE2)) == 0)) { \
        [MUTABLE_ARRAY addObject:@(#TYPE2)]; \
      } \
    } while (0)
    /* NSInteger type description */
    {
      NSMutableArray *array_NSInteger = [NSMutableArray arrayWithCapacity:1];
      BUILD_TYPE_MATCHES(array_NSInteger, NSInteger, int);
      BUILD_TYPE_MATCHES(array_NSInteger, NSInteger, long);
      BUILD_TYPE_MATCHES(array_NSInteger, NSInteger, long long);
      NSCAssert(array_NSInteger.count, @"No any type is matched for NSInteger.");
      NSString *desc = [NSString stringWithFormat:@"NSInteger?(%@)", [array_NSInteger componentsJoinedByString:@","]];
      desc_NSInteger = desc.UTF8String;
    }
    /* NSUInteger type description */
    {
      NSMutableArray *array_NSUInteger = [NSMutableArray arrayWithCapacity:1];
      BUILD_TYPE_MATCHES(array_NSUInteger, NSUInteger, unsigned int);
      BUILD_TYPE_MATCHES(array_NSUInteger, NSUInteger, unsigned long);
      BUILD_TYPE_MATCHES(array_NSUInteger, NSUInteger, unsigned long long);
      NSCAssert(array_NSUInteger.count, @"No any type is matched for NSInteger.");
      NSString *desc = [NSString stringWithFormat:@"NSUInteger?(%@)", [array_NSUInteger componentsJoinedByString:@","]];
      desc_NSUInteger = desc.UTF8String;
    }
  });
#endif
  
  
#define RETURN_IF_TYPE_ENCODE_MATCHES(ENCODED_VALUE, TYPE, ...) \
  RETURN_IF_TYPE_ENCODE_MATCHES_(ENCODED_VALUE, TYPE, ## __VA_ARGS__,  #TYPE)

#define RETURN_IF_TYPE_ENCODE_MATCHES_(ENCODED_VALUE, TYPE, RETURN_VALUE, ...) \
  do { \
    if ((strcmp(ENCODED_VALUE, @encode(TYPE)) == 0)) { \
      return @(RETURN_VALUE); \
    }\
  } while (0)

  
  const char *type = typeEncoding.UTF8String;
  
  // Simple Objective-C types
  // In the 64-bit runtime, BOOL is a C++ bool (or a C99 _Bool).
  // In the 32-bit runtime, BOOL is an unsign char.
  /*`B`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, BOOL);
  /*`B`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, bool, "BOOL");
  /*`@`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, id);
  /*`:`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, SEL);
  /*`#`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, Class);
  /*`@?`*/  RETURN_IF_TYPE_ENCODE_MATCHES(type, void(^)(void), "{BlockObject}");
  
#ifdef XOBJC_Use_Common_Type
  RETURN_IF_TYPE_ENCODE_MATCHES(type, NSInteger, desc_NSInteger);
  RETURN_IF_TYPE_ENCODE_MATCHES(type, NSUInteger, desc_NSUInteger);
#endif
  
  // Simple C types
  /*`d`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, double);
  /*`f`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, float);
  // `long` and `unsigned long` may be `q` and `Q` in 64-bit runtime
  /*`l`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, long);
  /*`L`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, unsigned long);
  /*`i`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, int);
  /*`I`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, unsigned int);
  /*`c`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, char);
  /*`C`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, unsigned char);
  /*`s`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, short);
  /*`S`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, unsigned short);
  /*`q`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, long long);
  /*`Q`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, unsigned long long);
  /*`*`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, char *);
  /*`v`*/   RETURN_IF_TYPE_ENCODE_MATCHES(type, void);
  /*`^?`*/  RETURN_IF_TYPE_ENCODE_MATCHES(type, void(*)(void), "{FunctionPointer?}");
  
  // `[]`: C array (NOTE: Objective-C property doesn't support C array)
  // `()`: C union (NOTE: We don't support C union)
  // `b(num)`: a bit field of num bits (NOTE: We don't support bit field)
  return [NSString stringWithFormat:@"<?:%@>", typeEncoding];
}


// -----------------------------------------------------------------------------
#pragma mark Property
// -----------------------------------------------------------------------------

static NSDictionary *_descriptionOfPropertyAttributes(NSString *propertyName, NSString *attr_desc)
{
  // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
  //
  // Property Type String:
  //
  // T<encoding>: Specifies the type using old-style encoding
  // N: (nonatomic)
  // R: (readonly)
  // C: (copy)
  // &: (retain/strong)
  // W: (__weak)
  // G<name>: (getter)
  // S<name>: (setter)
  // D: (@dynamic)
  // P: The property is eligible for garbage collection.
  // V: synthesized with the instance variable name
  
  NSArray *attributes = [attr_desc componentsSeparatedByString:@","];
  NSMutableDictionary *attrDict = [NSMutableDictionary dictionaryWithCapacity:attributes.count];
  for (NSString *attr in attributes) {
    if (attr.length > 0) {
      NSString *type  = [attr substringToIndex:1];
      NSString *value = [attr substringFromIndex:1];
      attrDict[type] = value;
    }
  }
  
  // Return Type
  NSString *returnType = _prettyDescriptionForTypeEncoding(attrDict[@"T"]);
  
  // Variable Name
  NSString *varaibleName = attrDict[@"V"] ?: attrDict[@"D"] ? @"(@dynamic)" : @"(no @synthesize)";
  
  // Memory Management Policy
  NSString *ownership = nil;
  if (attrDict[@"&"]) {
    ownership = @"strong"; // strong/retain
  } else if (attrDict[@"W"]) {
    ownership = @"weak"; // weak
  } else if (attrDict[@"C"]) {
    ownership = @"copy"; // copy
  } // others: unsafe_unretained/assign
  
  // Nonatomic
  NSString *nonatomic = (attrDict[@"N"]) ? @"nonatomic" : nil;
  
  // Readonly
  NSString *readonly = (attrDict[@"R"]) ? @"readonly" : nil;
  
  // getter/setter
  NSString *getter = attrDict[@"G"];
  NSString *setter = attrDict[@"S"];
  
  // New attribute description
  NSMutableArray *variable_and_type = [NSMutableArray arrayWithCapacity:2];
  if (returnType)   [variable_and_type addObject:returnType];
  if (varaibleName) [variable_and_type addObject:varaibleName];
  NSMutableArray *attr_elements = [NSMutableArray arrayWithCapacity:2];
  if (ownership)  [attr_elements addObject:ownership];
  if (nonatomic)  [attr_elements addObject:nonatomic];
  if (readonly)   [attr_elements addObject:readonly];
  if (getter)     [attr_elements addObject:[@"getter=" stringByAppendingString:getter]];
  if (setter)     [attr_elements addObject:[@"setter=" stringByAppendingString:setter]];
  NSString *newAttrDesc = [NSString stringWithFormat:@"[%@](%@)", [variable_and_type componentsJoinedByString:@" "], [attr_elements componentsJoinedByString:@", "]];
  
  // Build attr_info
  NSDictionary *attr_info = (readonly)
  ? @{@"ori_desc": attr_desc,
      @"new_desc": newAttrDesc,
      @"getter": getter ?: propertyName,
      }
  : @{@"ori_desc": attr_desc,
      @"new_desc": newAttrDesc,
      @"getter": getter ?: propertyName,
      @"setter": setter ?: [NSString stringWithFormat:@"set%@%@:", [[propertyName substringToIndex:1] capitalizedString], [propertyName substringFromIndex:1]]
      };
  
  return attr_info;
}

static NSDictionary *_propertyListForClass(Class klass)
{
  // Get properties
  unsigned int count;
  objc_property_t *properties = class_copyPropertyList(klass, &count);
  
  NSMutableDictionary *propertyList = [NSMutableDictionary dictionaryWithCapacity:count];
  for (unsigned int i = 0; i < count; i++) {
    objc_property_t property = properties[i];
    NSString *name = @(property_getName(property));
    NSString *attr = @(property_getAttributes(property));
    propertyList[name] = _descriptionOfPropertyAttributes(name, attr);
  }
  
  if (properties) {
    free(properties);
  }
  return propertyList;
}

// -----------------------------------------------------------------------------
#pragma mark Class interface
// -----------------------------------------------------------------------------

NSDictionary *_methodListForClass(Class klass)
{
  // Get methods
  unsigned int methodCount = 0;
  Method *methods = class_copyMethodList(klass, &methodCount);
  
  NSMutableDictionary *methodList = [NSMutableDictionary dictionaryWithCapacity:methodCount];
  
  for (unsigned int i = 0; i < methodCount; i++) {
    Method method = methods[i];
    NSString *selectorName = NSStringFromSelector(method_getName(method));
    if (selectorName) {
      NSString *signatureDescription = _signatureDescriptionForMethod(method);
      methodList[selectorName] = signatureDescription;
    }
  }
  
  // Clean up
  if (methods) {
    free(methods);
  }
  return methodList;
}

XOBJC_OVERLOADABLE NSDictionary *xobjc_implementedInterfaceForClass(const char *className)
{
  // Class methods
  Class cls = objc_getClass(className);
  Class metaclass = object_getClass(cls);
  NSDictionary *classMethodList = _methodListForClass(metaclass);
  
  // Instance methods
  NSDictionary *instanceMethodList = _methodListForClass(cls);
  NSDictionary *propertyList = _propertyListForClass(cls);
  
  // Extract gettes and settes
  NSMutableSet *getters = [NSMutableSet setWithCapacity:propertyList.count];
  NSMutableSet *setters = [NSMutableSet setWithCapacity:propertyList.count];
  for (NSString *propertyName in propertyList) {
    NSDictionary *propertyInfo = propertyList[propertyName];
    NSString *getter = propertyInfo[@"getter"];
    NSString *setter = propertyInfo[@"setter"];
    if (getter) [getters addObject:getter];
    if (setter) [setters addObject:setter];
  }
  
  // Filter out getter/setter methods from instance methods
  NSMutableSet *pureInstanceMethods = [NSMutableSet setWithArray:instanceMethodList.allKeys];
  [pureInstanceMethods minusSet:getters];
  [pureInstanceMethods minusSet:setters];
  
  // Sort class methods
  NSArray *sortedClassMethods = [[NSSet setWithArray:classMethodList.allKeys] xobjc_sortedAllObjects];
  NSArray *sortedInstanceMethods = [pureInstanceMethods xobjc_sortedAllObjects];
  NSArray *sortedProperties = [propertyList.allKeys xobjc_sortedByCompare];
  
  // Method descriptions
  NSMutableArray *classMethodDescriptions = [NSMutableArray arrayWithCapacity:sortedClassMethods.count];
  for (NSString *methodName in sortedClassMethods) {
    [classMethodDescriptions addObject:classMethodList[methodName]];
  }
  NSMutableArray *instanceMethodDescriptions = [NSMutableArray arrayWithCapacity:sortedInstanceMethods.count];
  for (NSString *methodName in sortedInstanceMethods) {
    [instanceMethodDescriptions addObject:instanceMethodList[methodName]];
  }
  NSMutableArray *propertyDescriptions = [NSMutableArray arrayWithCapacity:sortedProperties.count];
  for (NSString *propertyName in sortedProperties) {
#ifdef Use_Pretty_Property_Description
    [propertyDescriptions addObject:propertyList[propertyName][@"new_desc"]];
#else
    [propertyDescriptions addObject:propertyList[propertyName][@"ori_desc"]];
#endif
  }
  
  // Interface
  NSDictionary *interfaceForClass =
  @{
    @"class_methods": [XOrderedDict orderedDictionaryWithObjects:classMethodDescriptions forKeys:sortedClassMethods],
    @"instance_methods": [XOrderedDict orderedDictionaryWithObjects:instanceMethodDescriptions forKeys:sortedInstanceMethods],
    @"property": [XOrderedDict orderedDictionaryWithObjects:propertyDescriptions forKeys:sortedProperties]
    };
  
  return interfaceForClass;
}



// -----------------------------------------------------------------------------
#pragma mark Protocols Interface
// -----------------------------------------------------------------------------

XOrderedDict *_protocolInterfaceInfo(Protocol *protocol, BOOL isRequiredMethod, BOOL isInstanceMethod)
{
  typedef struct objc_method_description xobjc_method_description_t;
  unsigned int count;
  xobjc_method_description_t *methodDescptionList;
  methodDescptionList = protocol_copyMethodDescriptionList(protocol, isRequiredMethod, isInstanceMethod, &count);
  NSMutableDictionary *protocolInterface = [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)count];
  for (unsigned int i = 0; i < count; i++) {
    xobjc_method_description_t method_desc = methodDescptionList[i];
    NSString *selectorName = @(sel_getName(method_desc.name));
    protocolInterface[selectorName] =  _prettyDescriptionForSignature(@(method_desc.types), selectorName);
  }
  free(methodDescptionList);
  
  NSArray *sortedMethods = [protocolInterface.allKeys xobjc_sortedByCompare];
  NSMutableArray *methodDescriptions = [NSMutableArray arrayWithCapacity:sortedMethods.count];
  for (NSString *methodName in sortedMethods) {
    [methodDescriptions addObject:protocolInterface[methodName]];
  }
  
  return [XOrderedDict orderedDictionaryWithObjects:methodDescriptions forKeys:sortedMethods];
}

XOrderedDict *_propertyListForProtocol(Protocol *protocol)
{
  // Get properties
  unsigned int count;
  objc_property_t *properties = protocol_copyPropertyList(protocol, &count);
  
  NSMutableDictionary *propertyList = [NSMutableDictionary dictionaryWithCapacity:count];
  for (unsigned int i = 0; i < count; i++) {
    objc_property_t property = properties[i];
    NSString *name = @(property_getName(property));
    NSString *attr = @(property_getAttributes(property));
    propertyList[name] = _descriptionOfPropertyAttributes(name, attr);
  }
  
  if (properties) {
    free(properties);
  }
  
  // Build ordered dictionary
  XOrderedDict *orderedPropertyList = [[XOrderedDict orderedDictionaryWithDictionary:propertyList] sortedByKeysUsingSelector:@selector(compare:)];
  return orderedPropertyList;
}

XOBJC_OVERLOADABLE NSDictionary *xobjc_interfaceForProtocol(const char *protocolName)
{
  Protocol *protocol = objc_getProtocol(protocolName);
  if (!protocol) {
    NSLog(@"protocol `%s` not found!", protocolName);
    return nil;
  }
  
  // Methods
  XOrderedDict *requiredClassMethods    = _protocolInterfaceInfo(protocol, YES, NO);
  XOrderedDict *optionalClassMethods    = _protocolInterfaceInfo(protocol, NO, NO);
  XOrderedDict *requiredInstanceMethods = _protocolInterfaceInfo(protocol, YES, YES);
  XOrderedDict *optionalInstanceMethods = _protocolInterfaceInfo(protocol, NO, YES);
  
  // Properties
  XOrderedDict *propertyList = _propertyListForProtocol(protocol);
  
  // Sort properties into the required group or the optional group.
  XMutableOrderedDict *filteredRequiredInstanceMethods = [requiredInstanceMethods mutableCopy];
  XMutableOrderedDict *filteredOptionalInstanceMethods = [optionalInstanceMethods mutableCopy];
  NSMutableArray *requiredProperties = [NSMutableArray array];
  NSMutableArray *optionalProperties = [NSMutableArray array];
  NSMutableArray *unsortedProperties = [NSMutableArray array];
  for (NSString *propertyName in propertyList) {
    NSString *getter = propertyList[propertyName][@"getter"];
    NSString *setter = propertyList[propertyName][@"setter"];
    if ([filteredRequiredInstanceMethods containsKey:getter]) {
      [filteredRequiredInstanceMethods removeObjectForKey:getter];
      [filteredRequiredInstanceMethods removeObjectForKey:setter];
      [requiredProperties addObject:propertyName];
    } else if ([filteredOptionalInstanceMethods containsKey:getter]) {
      [filteredOptionalInstanceMethods removeObjectForKey:getter];
      [filteredOptionalInstanceMethods removeObjectForKey:setter];
      [optionalProperties addObject:propertyName];
    } else {
      [unsortedProperties addObject:propertyName];
    }
  }
  requiredInstanceMethods = filteredRequiredInstanceMethods;
  optionalInstanceMethods = filteredOptionalInstanceMethods;
  
  // Build the property groups for keys with new property descriptions.
#define XOrderedDict_NEW_DESC_FOR_KEYS_IN_DICT(DICT, KEYS) \
  ({ \
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:KEYS.count]; \
    for (NSString *propertyName in KEYS) { \
      [values addObject:DICT[propertyName][@"new_desc"]]; \
    } \
    [XOrderedDict orderedDictionaryWithObjects:values forKeys:KEYS]; \
  });
  
  XOrderedDict *requiredPropertyList = XOrderedDict_NEW_DESC_FOR_KEYS_IN_DICT(propertyList, requiredProperties);
  XOrderedDict *optionalPropertyList = XOrderedDict_NEW_DESC_FOR_KEYS_IN_DICT(propertyList, optionalProperties);
  XOrderedDict *unsortedPropertyList = XOrderedDict_NEW_DESC_FOR_KEYS_IN_DICT(propertyList, unsortedProperties);
  
  // Build the results
  NSMutableDictionary *interfaceForProtocol = [NSMutableDictionary dictionaryWithCapacity:6];
  if (requiredClassMethods.count)    interfaceForProtocol[@"required_class_methods"]    = requiredClassMethods;
  if (optionalClassMethods.count)    interfaceForProtocol[@"optional_class_methods"]    = optionalClassMethods;
  if (requiredInstanceMethods.count) interfaceForProtocol[@"required_instance_methods"] = requiredInstanceMethods;
  if (optionalInstanceMethods.count) interfaceForProtocol[@"optional_instance_methods"] = optionalInstanceMethods;
  if (requiredPropertyList.count)    interfaceForProtocol[@"required_property_list"]    = requiredPropertyList;
  if (optionalPropertyList.count)    interfaceForProtocol[@"optional_property_list"]    = optionalPropertyList;
  if (unsortedPropertyList.count)    interfaceForProtocol[@"unsorted_property_list"]    = unsortedPropertyList;
  
  return interfaceForProtocol;
}


