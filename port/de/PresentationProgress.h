#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
// Progress means observed composition, not GPU completion or game acknowledgement.
@interface DEPresentationProgress : NSObject
@property(nonatomic) uint64_t serial;
@end
@implementation DEPresentationProgress @end
static char DEPresentationProgressKey;
static uint64_t DEObservedPresentationSerial(id layer) {
 if(!layer)return 0;
 @synchronized(layer) {return ((DEPresentationProgress *)objc_getAssociatedObject(layer,&DEPresentationProgressKey)).serial;}
}
static void DERecordObservedPresentation(id layer) {
 if(!layer)return;
 @synchronized(layer) {
  DEPresentationProgress *progress=objc_getAssociatedObject(layer,&DEPresentationProgressKey);
  if(!progress){progress=[DEPresentationProgress new];objc_setAssociatedObject(layer,&DEPresentationProgressKey,progress,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
  progress.serial++;
 }
}
