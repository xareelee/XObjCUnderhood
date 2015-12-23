//
//  AppDelegate.m
//  XObjCUnderhoodDev
//
//  Created by Xaree on 12/18/15.
//  Copyright © 2015 Xaree Lee. All rights reserved.
//

#import "AppDelegate.h"
#import <XObjCUnderhood/XObjCUnderhood.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  xobjc_underhood_setup();
  return YES;
}

@end
