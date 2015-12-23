//
//  XObjCUnderhood.h
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XObjCUnderhoodDefinitions.h"


extern NSString const *kXObjCUnderhoodRootClassKey;
extern NSString const *kXObjCUnderhoodRootProtocolKey;


// =============================================================================
// C functions
// =============================================================================

#pragma mark Setup
/// Before using other functions in this file, you should invoke this funciton
/// first to build up the class/protocol lookup.
void xobjc_underhood_setup();


#pragma mark Classes/Protocols Lookup
/// Get all classes (keys) and their subclasses (values), respectively.
XOrderedDict *xobjc_classHierarchyLookUp();
/// Get all protocols and their sub-protocols (containing a root key `$root_protocols`).
XOrderedDict *xobjc_subProtocolsLookup();
/// Get all protocols and their super-protocols.
XOrderedDict *xobjc_superProtocolsLookup();
/// Get all prtocols (keys) and the classes (values) which conform them, respectively.
XOrderedDict *xobjc_classesForProtocolsLookup();


#pragma mark Class Hierarchy

XOBJC_OVERLOADABLE NSArray *xobjc_superclassesOfClass(const char *className) ;
XOBJC_OVERLOADABLE XOrderedDict *xobjc_subclassesOfClass(const char *className);


#pragma mark Protocol Hierarchy
XOBJC_OVERLOADABLE NSSet *xobjc_superProtocolSet(const char *protocolName);
XOBJC_OVERLOADABLE NSSet *xobjc_subProtocolSet(const char *protocolName);


#pragma mark Class –> Protocols
XOBJC_OVERLOADABLE NSArray *xobjc_protocolsForClass(const char *className);
XOBJC_OVERLOADABLE XOrderedDict *xobjc_protocolsForClassInHierarchy(const char *className);


#pragma mark Protocol –> Classes
XOBJC_OVERLOADABLE NSArray *xobjc_classesJustAdoptingProtocol(const char *protocolName);
XOBJC_OVERLOADABLE NSArray *xobjc_classesForProtocol(const char *protocolName);
XOBJC_OVERLOADABLE NSArray *xobjc_commonClassesForProtocol(const char *protocolName);
XOBJC_OVERLOADABLE XOrderedDict *xobjc_allClassesForProtocol(const char *protocolName);


#pragma mark Class interface

/// Return a dictionary containing all implemented interfaces for the class:
/// class methods, instance methods, and properties.
///
/// The collections of implementations contain the selector names (keys) and
/// their signatures (values).
///
/// The method signatures are described as this format:
///
///     [##return_type##](##param_types##, ...)
///
/// The property signatures are described as this format:
///
///     [##property_type##  ##synthesized_variable_name##](##property_attributes##, ...)
///
/// @note the results only containing the implementations in this class. The
/// implementations in superclass are not list in the results.
XOBJC_OVERLOADABLE NSDictionary *xobjc_implementedInterfaceForClass(const char *className);



#pragma mark Protocol interface

/// Return a dictionary containing all interfaces for the protocol.
///
/// The signature description are described in `xobjc_implementedInterfaceForClass`.
XOBJC_OVERLOADABLE NSDictionary *xobjc_interfaceForProtocol(const char *protocolName);


