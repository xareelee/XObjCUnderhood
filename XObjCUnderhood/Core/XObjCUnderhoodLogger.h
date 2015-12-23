//
//  XObjCUnderhood.h
//  XObjCUnderhood
//
//  Created by Xaree on 7/11/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XObjCUnderhoodDefinitions.h"
#import "XObjCUnderhoodBasics.h"

// =============================================================================
// C functions
// =============================================================================
XOBJC_OVERLOADABLE void xobjc_logHierarchyForClass(const char *className);
XOBJC_OVERLOADABLE void xobjc_logSubclassesForClass(const char *className);
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(const char *className);
XOBJC_OVERLOADABLE void xobjc_logMethodListForClassHierarchy(const char *className, const char *superclassName);
// Print all classes and their subclasses which adopt the protocol.
XOBJC_OVERLOADABLE void xobjc_logAllClassesForProtocol(const char *protocolName);

