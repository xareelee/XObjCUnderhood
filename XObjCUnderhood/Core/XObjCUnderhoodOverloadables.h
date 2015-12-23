//
//  XObjCUnderhood.h
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "XObjCUnderhoodDefinitions.h"


/*
 Use the overloadable attribute to let those functions be able to take either
 a class/protocol object or a name (C string) as the parameter.
 
 For example,
 
     xobjc_superclassesOfClass([UIView clas]);
 
 or
 
     xobjc_superclassesOfClass("UIView");
 
 both function calls are valid.
 */

// =============================================================================
// Overload for XObjCUnderhoodBasics
// =============================================================================

#pragma mark Class Hierarchy
XOBJC_OVERLOADABLE NSArray *xobjc_superclassesOfClass(Class cls) ;
XOBJC_OVERLOADABLE XOrderedDict *xobjc_subclassesOfClass(Class cls);


#pragma mark Protocol Hierarchy
XOBJC_OVERLOADABLE NSSet *xobjc_superProtocolSet(Protocol *protocol);
XOBJC_OVERLOADABLE NSSet *xobjc_subProtocolSet(Protocol *protocol);


#pragma mark Class –> Protocols
XOBJC_OVERLOADABLE NSArray *xobjc_protocolsForClass(Class cls);
XOBJC_OVERLOADABLE XOrderedDict *xobjc_protocolsForClassInHierarchy(Class cls);


#pragma mark Protocol –> Classes
XOBJC_OVERLOADABLE NSArray *xobjc_classesJustAdoptingProtocol(Protocol *protocol);
XOBJC_OVERLOADABLE NSArray *xobjc_classesForProtocol(Protocol *protocol);
XOBJC_OVERLOADABLE NSArray *xobjc_commonClassesForProtocol(Protocol *protocol);
XOBJC_OVERLOADABLE XOrderedDict *xobjc_allClassesForProtocol(Protocol *protocol);


#pragma mark Class interface
XOBJC_OVERLOADABLE NSDictionary *xobjc_implementedInterfaceForClass(Class cls);


#pragma mark Protocol interface
XOBJC_OVERLOADABLE NSDictionary *xobjc_interfaceForProtocol(Protocol *protocol);


// =============================================================================
// Overload for XObjCUnderhoodLogger
// =============================================================================

XOBJC_OVERLOADABLE void xobjc_logHierarchyForClass(Class cls);
XOBJC_OVERLOADABLE void xobjc_logSubclassesForClass(Class cls);
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(Class cls);
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(Class cls, Class superclass);
XOBJC_OVERLOADABLE void xobjc_logAllClassesForProtocol(Protocol *protocol);

