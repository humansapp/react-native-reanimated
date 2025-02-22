#import "REAAnimationsManager.h"
#import <React/RCTComponentData.h>
#import <React/UIView+React.h>
#import <React/UIView+Private.h>
#import "REAUIManager.h"
#import <React/RCTTextView.h>

@interface REAAnimationsManager ()

@property (atomic, nullable) void(^startAnimationForTag)(NSNumber *, NSString *, NSDictionary *, NSNumber*);
@property (atomic, nullable) void(^removeConfigForTag)(NSNumber *);

- (void)removeLeftovers;
- (void)scheduleCleaning;

@end

@implementation REAAnimationsManager {
  RCTUIManager* _uiManager;
  REAUIManager* _reaUiManager;
  NSMutableDictionary<NSNumber*, NSNumber *>* _states;
  NSMutableDictionary<NSNumber*, UIView *>* _viewForTag;
  NSMutableSet<NSNumber*>* _toRemove;
  BOOL _cleaningScheduled;
}

+ (NSArray *)layoutKeys
{
    static NSArray *_array;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _array = @[@"originX", @"originY", @"width", @"height"];
    });
    return _array;
}

- (instancetype)initWithUIManager:(RCTUIManager *)uiManager
{
  if (self = [super init]) {
    _uiManager = uiManager;
    _reaUiManager = (REAUIManager*)uiManager;
    _states = [NSMutableDictionary new];
    _viewForTag = [NSMutableDictionary new];
    _toRemove = [NSMutableSet new];
    _cleaningScheduled = false;
  }
  return self;
}

- (void)invalidate
{
  _startAnimationForTag = nil;
  _removeConfigForTag = nil;
  _uiManager = nil;
  _states = nil;
  _viewForTag = nil;
  _toRemove = nil;
  _cleaningScheduled = false;
}

- (void)setAnimationStartingBlock:(void (^)(NSNumber * tag, NSString * type, NSDictionary* yogaValues, NSNumber* depth))startAnimation
{
  _startAnimationForTag = startAnimation;
}

- (void)setRemovingConfigBlock:(void (^)(NSNumber *tag))block
{
  _removeConfigForTag = block;
}

- (void)scheduleCleaning
{
  if(_cleaningScheduled) {
    return;
  }
  _cleaningScheduled = true;
  
  __weak REAAnimationsManager *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_cleaningScheduled = false;
    if (weakSelf == nil) {
      return;
    }
    [self removeLeftovers];
  });
}

- (void) findRoot:(UIView*)view roots:(NSMutableSet<NSNumber*>*)roots
{
  UIView* currentView = view;
  NSNumber* lastToRemoveTag = nil;
  while (currentView != nil) {
    ViewState state = [_states[currentView.reactTag] intValue];
    if(state == Disappearing) {
      return;
    }
    if(state == ToRemove) {
      lastToRemoveTag = currentView.reactTag;
    }
    currentView = currentView.superview;
  }
  if(lastToRemoveTag != nil) {
    [roots addObject:lastToRemoveTag];
  }
}

- (BOOL) dfs:(UIView*)root view:(UIView*)view cands:(NSMutableSet<NSNumber*>*)cands
{
  NSNumber* tag = view.reactTag;
  if (tag == nil) {
    return true;
  }
  if(![cands containsObject:tag] && _states[tag] != nil) {
    return true;
  }
  BOOL cannotStripe = false;
  NSArray<UIView*>* toRemoveCopy = [view.reactSubviews copy];
  for (UIView* child in toRemoveCopy) {
    if (![view isKindOfClass:[RCTTextView class]]) {
      cannotStripe |= [self dfs:root view:child cands:cands];
    }
  }
  if(!cannotStripe) {
    if(view.reactSuperview != nil) {
      [_reaUiManager unregisterView: view];
    }
    [_states removeObjectForKey:tag];
    [_viewForTag removeObjectForKey:tag];
    [_toRemove removeObject:tag];
  }
  return cannotStripe;
}

- (void)removeLeftovers
{
  NSMutableSet<NSNumber*>* roots = [NSMutableSet new];
  for(NSNumber* viewTag in _toRemove) {
    UIView* view = _viewForTag[viewTag];
    [self findRoot:view roots:roots];
  }
  for(NSNumber* viewTag in roots) {
    UIView* view = _viewForTag[viewTag];
    [self dfs:view view:view cands:_toRemove];
  }
}

- (void)notifyAboutEnd:(NSNumber*)tag cancelled:(BOOL)cancelled
{
  if (!cancelled) {
    ViewState state = [_states[tag] intValue];
    if (state == Appearing) {
      _states[tag] = [NSNumber numberWithInt:Layout];
    }
    if (state == Disappearing) {
      _states[tag] = [NSNumber numberWithInt:ToRemove];
      if(tag != nil) {
        [_toRemove addObject:tag];
      }
      [self scheduleCleaning];
    }
  }
}

- (void)notifyAboutProgress:(NSDictionary *)newStyle tag:(NSNumber*)tag
{
  if (_states[tag] == nil) {
    return;
  }
  ViewState state = [_states[tag] intValue];
  if (state == Inactive) {
    _states[tag] = [NSNumber numberWithInt:Appearing];
  }
  
  NSMutableDictionary* dataComponenetsByName = [_uiManager valueForKey:@"_componentDataByName"];
  RCTComponentData *componentData = dataComponenetsByName[@"RCTView"];
  [self setNewProps:[newStyle mutableCopy] forView:_viewForTag[tag] withComponentData:componentData];
}

- (void)setNewProps:(NSMutableDictionary *)newProps forView:(UIView*)view withComponentData:(RCTComponentData*)componentData
{
  if (newProps[@"height"]) {
    double height = [newProps[@"height"] doubleValue];
    double oldHeight = view.bounds.size.height;
    view.bounds = CGRectMake(0, 0, view.bounds.size.width, height);
    view.center = CGPointMake(view.center.x, view.center.y - oldHeight/2.0 + view.bounds.size.height/2.0);
    [newProps removeObjectForKey:@"height"];
  }
  if (newProps[@"width"]) {
    double width = [newProps[@"width"] doubleValue];
    double oldWidth = view.bounds.size.width;
    view.bounds = CGRectMake(0, 0, width, view.bounds.size.height);
    view.center = CGPointMake(view.center.x + view.bounds.size.width/2.0 - oldWidth/2.0, view.center.y);
    [newProps removeObjectForKey:@"width"];
  }
  if (newProps[@"originX"]) {
    double originX = [newProps[@"originX"] doubleValue];
    view.center = CGPointMake(originX + view.bounds.size.width/2.0, view.center.y);
    [newProps removeObjectForKey:@"originX"];
  }
  if (newProps[@"originY"]) {
    double originY = [newProps[@"originY"] doubleValue];
    view.center = CGPointMake(view.center.x, originY + view.bounds.size.height/2.0);
    [newProps removeObjectForKey:@"originY"];
  }
  [componentData setProps:newProps forView:view];
}

- (NSDictionary*) prepareDataForAnimatingWorklet:(NSMutableDictionary*)values
{
  UIView *windowView = UIApplication.sharedApplication.keyWindow;
  NSDictionary* preparedData = @{
    @"width": values[@"width"],
    @"height": values[@"height"],
    @"originX": values[@"originX"],
    @"originY": values[@"originY"],
    @"globalOriginX": values[@"globalOriginX"],
    @"globalOriginY": values[@"globalOriginY"],
    @"windowWidth": [NSNumber numberWithDouble:windowView.bounds.size.width],
    @"windowHeight": [NSNumber numberWithDouble:windowView.bounds.size.height]
  };
  return preparedData;
}

- (void) onViewRemoval:(UIView*) view before:(REASnapshot*) before
{
  NSNumber* tag = view.reactTag;
  ViewState state = [_states[tag] intValue];
  if(state == Disappearing || state == ToRemove || tag == nil) {
    return;
  }
  NSMutableDictionary<NSString*, NSObject*>* startValues = before.values;
  if(state == Inactive) {
    if(startValues != nil) {
      _states[tag] = [NSNumber numberWithInt:ToRemove];
      [_toRemove addObject:tag];
      [self scheduleCleaning];
    }
    return;
  }
  _states[tag] = [NSNumber numberWithInt:Disappearing];
  NSDictionary* preparedValues = [self prepareDataForAnimatingWorklet:startValues];
  _startAnimationForTag(tag, @"exiting", preparedValues, @(0));
}

- (void) onViewCreate:(UIView*) view after:(REASnapshot*) after
{
  NSNumber* tag = view.reactTag;
  if(_states[tag] == nil) {
    _states[tag] = [NSNumber numberWithInt:Inactive];
    _viewForTag[tag] = view;
  }
  NSMutableDictionary* targetValues = after.values;
  ViewState state = [_states[tag] intValue];
  if(state == Inactive) {
    if(targetValues != nil) {
      NSDictionary* preparedValues = [self prepareDataForAnimatingWorklet:targetValues];
      _startAnimationForTag(tag, @"entering", preparedValues, @(0));
    }
    return;
  }
}

- (void) onViewUpdate: (UIView*) view before:(REASnapshot*) before after:(REASnapshot*) after
{
  NSNumber* tag = view.reactTag;
  NSMutableDictionary* targetValues = after.values;
  NSMutableDictionary* startValues = before.values;
  if (_states[tag] == nil) {
    return;
  }
  ViewState state = [_states[tag] intValue];
  if(state == Disappearing || state == ToRemove || state == Inactive) {
    return;
  }
  if(state == Appearing) {
    BOOL doNotStartLayout = true;
    for (NSString * key in [[self class] layoutKeys]) {
        if ([((NSNumber *)startValues[key]) doubleValue] !=  [((NSNumber *)targetValues[key]) doubleValue]) {
          doNotStartLayout = false;
        }
    }
    if (doNotStartLayout) {
      return;
    }
  }
  _states[view.reactTag] = [NSNumber numberWithInt: Layout];
  NSDictionary* preparedStartValues = [self prepareDataForAnimatingWorklet:startValues];
  NSDictionary* preparedTargetValues = [self prepareDataForAnimatingWorklet:targetValues];
  NSMutableDictionary * preparedValues = [NSMutableDictionary new];
  [preparedValues addEntriesFromDictionary:preparedTargetValues];
  for (NSString* key in preparedStartValues.allKeys) {
    preparedValues[[NSString stringWithFormat:@"%@%@", @"b", key]] = preparedStartValues[key];
  }
  _startAnimationForTag(view.reactTag, @"layout", preparedValues, @(0));
}

@end
