//
//  XObjCUnderhood.m
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import "XObjCUnderhoodOverloadables.h"
#import "XObjCUnderhoodBasics.h"
#import "XObjCUnderhoodLogger.h"

// =============================================================================
// Overload for XObjCUnderhoodBasics
// =============================================================================

XOBJC_OVERLOADABLE NSArray *xobjc_superclassesOfClass(Class cls){
  return xobjc_superclassesOfClass(class_getName(cls));
}
XOBJC_OVERLOADABLE XOrderedDict *xobjc_subclassesOfClass(Class cls){
  return xobjc_subclassesOfClass(class_getName(cls));
}


#pragma mark Protocol Hierarchy
XOBJC_OVERLOADABLE NSSet *xobjc_superProtocolSet(Protocol *protocol){
  return xobjc_superProtocolSet(protocol_getName(protocol));
}
XOBJC_OVERLOADABLE NSSet *xobjc_subProtocolSet(Protocol *protocol){
  return xobjc_subProtocolSet(protocol_getName(protocol));
}


#pragma mark Class –> Protocols
XOBJC_OVERLOADABLE NSArray *xobjc_protocolsForClass(Class cls){
  return xobjc_protocolsForClass(class_getName(cls));
}
XOBJC_OVERLOADABLE XOrderedDict *xobjc_protocolsForClassInHierarchy(Class cls){
  return xobjc_protocolsForClassInHierarchy(class_getName(cls));
}


#pragma mark Protocol –> Classes
XOBJC_OVERLOADABLE NSArray *xobjc_classesJustAdoptingProtocol(Protocol *protocol){
  return xobjc_classesJustAdoptingProtocol(protocol_getName(protocol));
}
XOBJC_OVERLOADABLE NSArray *xobjc_classesForProtocol(Protocol *protocol){
  return xobjc_classesForProtocol(protocol_getName(protocol));
}
XOBJC_OVERLOADABLE NSArray *xobjc_commonClassesForProtocol(Protocol *protocol){
  return xobjc_commonClassesForProtocol(protocol_getName(protocol));
}
XOBJC_OVERLOADABLE XOrderedDict *xobjc_allClassesForProtocol(Protocol *protocol){
  return xobjc_allClassesForProtocol(protocol_getName(protocol));
}


#pragma mark Class interface
XOBJC_OVERLOADABLE NSDictionary *xobjc_implementedInterfaceForClass(Class cls){
  return xobjc_implementedInterfaceForClass(class_getName(cls));
}


#pragma mark Protocol interface
XOBJC_OVERLOADABLE NSDictionary *xobjc_interfaceForProtocol(Protocol *protocol){
  return xobjc_interfaceForProtocol(protocol_getName(protocol));
}


// =============================================================================
// Overload for XObjCUnderhoodLogger
// =============================================================================

XOBJC_OVERLOADABLE void xobjc_logHierarchyForClass(Class cls){
  return xobjc_logHierarchyForClass(class_getName(cls));
}
XOBJC_OVERLOADABLE void xobjc_logSubclassesForClass(Class cls){
  return xobjc_logSubclassesForClass(class_getName(cls));
}
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(Class cls){
  xobjc_logMethodListForClassHierarchy(class_getName(cls));
}
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(Class cls, Class superclass){
  xobjc_logMethodListForClassHierarchy(class_getName(cls), class_getName(superclass));
}
XOBJC_OVERLOADABLE void xobjc_logAllClassesForProtocol(Protocol *protocol){
  xobjc_logAllClassesForProtocol(protocol_getName(protocol));
}

