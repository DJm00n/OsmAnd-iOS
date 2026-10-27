//
//  OACarPlayManeuverFactory.h
//  OsmAnd Maps
//
//  Builds the pieces of CPManeuver (images, texts, turn-state helpers) from routing data.
//

#import <CarPlay/CarPlay.h>

@class OANextDirectionInfo, OASTurnType, OAAnnounceTimeDistances, OALanesDrawable, OASKotlinIntArray;

NS_ASSUME_NONNULL_BEGIN

@interface OACarPlayManeuverFactory : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

// MARK: Images

/// Renders a turn arrow. Pass `fixedSize` > 0 for a square image of that size, or 0 to fit the arrow path bounds.
+ (nullable UIImage *)turnImageForType:(OASTurnType *)turnType
                              imminent:(int)imminent
                     deviatedFromRoute:(BOOL)deviatedFromRoute
                    userInterfaceStyle:(UIUserInterfaceStyle)style
                             fixedSize:(CGFloat)fixedSize;

/// Renders a lanes strip using the (reusable) drawable.
+ (nullable UIImage *)lanesImageForLanes:(OASKotlinIntArray *)lanes
                                imminent:(BOOL)imminent
                                drawable:(OALanesDrawable *)drawable;

// MARK: Texts

+ (NSString *)streetNameForDirectionInfo:(nullable OANextDirectionInfo *)info;
+ (NSString *)currentStreetName;
+ (NSString *)nextTurnDescriptionForInfo:(nullable OANextDirectionInfo *)info
                                turnType:(nullable OASTurnType *)turnType
                            nextTurnType:(nullable OASTurnType *)nextTurnType;
+ (NSString *)secondNextTurnDescriptionForInfo:(nullable OANextDirectionInfo *)info
                                      turnType:(nullable OASTurnType *)turnType
                                  nextTurnType:(nullable OASTurnType *)nextTurnType;

// MARK: Turn state

/// Returns the next turn type if the turn at `distance` is about to be announced and the turn after it is imminent.
+ (nullable OASTurnType *)followingTurnTypeWithTimeDistances:(OAAnnounceTimeDistances *)atd
                                                        info:(nullable OANextDirectionInfo *)info
                                                       speed:(float)speed
                                                    distance:(int)distance;

// MARK: Navigation metadata (instrument cluster / HUD)

/// Fills maneuverType, junctionType, trafficSide (and the exit angle for roundabouts) of the maneuver.
+ (void)applyMetadataToManeuver:(CPManeuver *)maneuver
                       turnType:(nullable OASTurnType *)turnType
                       leftSide:(BOOL)leftSide
                         isLast:(BOOL)isLast API_AVAILABLE(ios(17.4));

/// Builds lane guidance for the vehicle. Returns nil if there are no lanes.
+ (nullable CPLaneGuidance *)laneGuidanceForLanes:(nullable OASKotlinIntArray *)lanes
                                      instruction:(nullable NSString *)instruction API_AVAILABLE(ios(17.4));

/// Maneuver state by distance to the turn: continue -> initial -> prepare -> execute.
+ (CPManeuverState)maneuverStateForDistance:(int)distance
                                      speed:(float)speed
                              timeDistances:(OAAnnounceTimeDistances *)atd API_AVAILABLE(ios(17.4));

/// Builds maneuvers (with metadata) for the next route directions, to be passed to CPNavigationSession addManeuvers:.
+ (NSArray<CPManeuver *> *)routeManeuversWithLeftSide:(BOOL)leftSide
                                   userInterfaceStyle:(UIUserInterfaceStyle)style
                                                limit:(NSUInteger)limit API_AVAILABLE(ios(17.4));

@end

NS_ASSUME_NONNULL_END
