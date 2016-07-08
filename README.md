# XObjCUnderhood

**XObjCUnderhood** is a library which utilizes the Obj-C runtime to understand the Obj-C class hierarchy, methods, and protocols at runtime. It's useful to study a framework or a third-party library.

For example, you could discover all subclasses of `UIButton` by using the `xobjc_log` function:

```objc
// .m file
xobjc_logSubclassesForClass("UIButton");
```

```objc
// Xcode debug console
* UIButton
  * CNPropertyLabelButton
  * CNQuickActionButton
  * CNTransportButton
    * ABTransportButton
    * CNStarkKnobTransportButton
  * MKButtonWithTargetArgument
  * UIAlertButton
  ...
```

or print out the objects (`po` command) of the results at runtime: 

```objc
// Xcode debug console
(lldb) po xobjc_subclassesOfClass("UIButton")
{
	"UIAlertButton": {
		"UIAlertLabeledButton": {},
		"UIAlertMediaButton": {}
	},
	"UICalloutBarButton": {},
	"UIDictationMeterView": {},
	"UIKeyboardButton": {},
    ...
}
```


For more information, please refer to the section "Very useful XObjCUnderhood functions".


# How to use

## (1) Installation via CocoaPods

> XObjCUnderhood is designed for studying Obj-C classes in development, not in production. You should only include XObjCUnderhood in the **Debug** mode.

You could install XObjCUnderhood by CocoaPods:

```ruby
pod 'XObjCUnderhood', '~> 1.0', :configurations => ['Debug']
```

If you need to install XObjCUnderhood manually, you should include all files in the XObjCUnderhood directory and also [M13OrderedDictionary](https://github.com/Marxon13/M13OrderedDictionary) library.

It's also **highly recommended** to install my another library — [ObjCJSONLikeDescription](https://github.com/xareelee/ObjCJSONLikeDescription) and its subspec for *M13OrderedDictionary* to make the descriptions of collection objects be more JSON-like.

```ruby
pod 'ObjCJSONLikeDescription', :configurations => ['Debug']
pod 'ObjCJSONLikeDescription/M13OrderedDictionary', :configurations => ['Debug']
```

## (2) XObjCUnderhood setup

You should set up XObjCUnderhood library in either `application:didFinishLaunchingWithOptions:` or **lldb/gdb** before using any XObjCUnderhood functions:

```objc
// .m file
#import <XObjCUnderhood/XObjCUnderhood.h>
xobjc_underhood_setup();
// or in lldb/gdb
(lldb) po xobjc_underhood_setup()
```

This setup will analyze and build up the inheritance hierarchy for all Objective-C classes and protocols at the runtime.


## (3) Start using XObjCUnderhood

For the sake of convenience, it's recommended to use XObjCUnderhood library in the lldb/gdb by a runtime break.

```
// print all classes (keys) and their subclasses (values), respectively.
(lldb) po xobjc_classHierarchyLookUp()
```

You could find many useful functions in the *XObjCUnderhoodBasics.h* or *XObjCUnderhoodOverloadables.h*. XObjCUnderhood use C11 overloadable to make those functions take either a class/protocol type or a class/protocol name.

```objc
// .m file
// pass a protocol object
xobjc_logAllClassesForProtocol(@protocol(UITableViewDataSource));
// or a protocol name
xobjc_logAllClassesForProtocol("UITableViewDataSource");
```



In lldb/gdb, it's recommended to pass a string value as the parameter to XObjCUnderhood functions, because Objective-C directives like `@protocol` may not be resolved correctly in the lldb/gdb.


# Very useful XObjCUnderhood functions

> **Hint**: you could use shortcut `⌘ + k` to clear Xcode console whenever you want.
> 
> **Note**: you should set up XObjCUnderhood library first by calling `xobjc_underhood_setup()`.


## ** print all classes and their subclasses

```objc
(lldb) po xobjc_classHierarchyLookUp()
```

You can use this function to get the whole class list in the runtime. Try to search a class name in the Xcode console, you should get two search results — one for their subclasses and one for its superclass.

> **Note**: The objects for the key `$root_classes` are the Objective-C root classes. 


## ** print all subclasses for a class

```objc
(lldb) po xobjc_subclassesOfClass("UIButton")
// or
(lldb) po xobjc_subclassesOfClass([UIButton class])
```

This is very useful if you want to know all subclasses (concrete classes) for a class. It makes you learn how to use a library quickly due to *Liskov substitution principle (LSP)*.

> Liskov substitution principle: *“objects in a program should be replaceable with instances of their subtypes without altering the correctness of that program.”* -- Wikipedia


## ** print all classes conforming a protocol

```objc
(lldb) po xobjc_allClassesForProtocol("UITableViewDataSource")
```

This function is very using if you encounter a method like this:

```objc
- (void)bindDataSource:(id<UITableViewDataSource>)dataSource;
```

You could pass any instance object conforming the protocol to the method.


## ** print all implemented interfaces in a class

```objc
(lldb) po xobjc_implementedInterfaceForClass("UIView")
```

Disclose the implemented interfaces in a class, including private methods/properties.


## ** print all implemented interfaces through the class hierarchy

```objc
(lldb) po xobjc_logMethodListForClass("UIView")  // to the root class
(lldb) po xobjc_logMethodListForClass("UIView", "UIResponder")
```

Print all interfaces through the class hierarchy.



## About

### Author
* Xaree Lee (李岡諭, Kang-Yu Lee), an iOS developer from Taiwan.
    - <xareelee@gmail.com>

### License
XObjCUnderhood is available under the MIT license. See the [LICENSE](LICENSE.md) file for more info.


