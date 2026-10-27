//
//  OACarPlayManeuverFactory.mm
//  OsmAnd Maps
//

#import "OACarPlayManeuverFactory.h"
#import "OARoutingHelper.h"
#import "Localization.h"
#import "OAOsmAndFormatter.h"
#import "OALanesDrawable.h"
#import "OATurnDrawable.h"
#import "OATurnDrawable+TurnType.h"
#import "OACurrentStreetName.h"
#import "OARouteDirectionInfo.h"
#import "OAAnnounceTimeDistances.h"
#import "OsmAndSharedWrapper.h"

@implementation OACarPlayManeuverFactory

// MARK: Images

+ (UIImage *)turnImageForType:(OASTurnType *)turnType
                     imminent:(int)imminent
            deviatedFromRoute:(BOOL)deviatedFromRoute
           userInterfaceStyle:(UIUserInterfaceStyle)style
                    fixedSize:(CGFloat)fixedSize
{
    EOATurnDrawableThemeColor themeColor = style == UIUserInterfaceStyleDark
        ? EOATurnDrawableThemeColorDark
        : EOATurnDrawableThemeColorLight;
    OATurnDrawable *drawable = [[OATurnDrawable alloc] initWithMini:NO themeColor:themeColor];
    [drawable setTurnType:turnType];
    [drawable setTurnImminent:imminent deviatedFromRoute:deviatedFromRoute];
    drawable.textFont = [UIFont scaledSystemFontOfSize:16 weight:UIFontWeightSemibold];
    CGFloat size = fixedSize;
    if (size <= 0)
    {
        size = MAX(drawable.pathForTurn.bounds.origin.x + drawable.pathForTurn.bounds.size.width,
                   drawable.pathForTurn.bounds.origin.y + drawable.pathForTurn.bounds.size.height);
    }
    drawable.frame = CGRectMake(0, 0, size, size);
    [drawable setNeedsDisplay];
    return [drawable toUIImage];
}

+ (UIImage *)lanesImageForLanes:(OASKotlinIntArray *)lanes imminent:(BOOL)imminent drawable:(OALanesDrawable *)drawable
{
    [drawable setTurnLanes:lanes];
    drawable.imminent = imminent;
    [drawable updateBounds];
    drawable.frame = CGRectMake(0, 0, drawable.width, drawable.height);
    [drawable setNeedsDisplay];
    return [drawable toUIImage];
}

// MARK: Texts

+ (NSString *)currentStreetName
{
    OANextDirectionInfo *directionInfo = [[OARoutingHelper sharedInstance] getNextRouteDirectionInfo:[[OANextDirectionInfo alloc] init] toSpeak:YES];
    return [self streetNameForDirectionInfo:directionInfo];
}

+ (NSString *)streetNameForDirectionInfo:(OANextDirectionInfo *)nextDirInfo
{
    if (nextDirInfo)
    {
        OACurrentStreetName *currentStreetName = [[OACurrentStreetName alloc] initWithStreetName:nextDirInfo];
        NSString *streetName = currentStreetName.text;
        if (streetName.length > 0)
        {
            NSString *exitRef = currentStreetName.exitRef;
            return exitRef.length == 0
                ? streetName
                : [NSString stringWithFormat:OALocalizedString(@"ltr_or_rtl_combine_via_comma"), exitRef, streetName];
        }
    }
    return @"";
}

+ (NSString *)turnDescriptionForInfo:(OANextDirectionInfo *)info
{
    NSString *name = [self streetNameForDirectionInfo:info];
    NSString *ref = info && info.directionInfo ? info.directionInfo.ref : @"";
    return name.length > 0 ? name : ref;
}

+ (NSString *)nextTurnDescriptionForInfo:(OANextDirectionInfo *)info turnType:(OASTurnType *)turnType nextTurnType:(OASTurnType *)nextTurnType
{
    NSString *description = [self turnDescriptionForInfo:info];
    NSString *turnName = turnType ? [self nextTurnsToString:turnType nextTurnType:nextTurnType] : @"";

    if (turnType && [turnType isRoundAbout] && description.length > 0)
        return [NSString stringWithFormat:OALocalizedString(@"ltr_or_rtl_combine_via_comma"), turnName, description];

    return description.length > 0 ? description : turnName;
}

+ (NSString *)secondNextTurnDescriptionForInfo:(OANextDirectionInfo *)info turnType:(OASTurnType *)turnType nextTurnType:(OASTurnType *)nextTurnType
{
    NSString *description = [self turnDescriptionForInfo:info];
    NSString *distance = [OAOsmAndFormatter getFormattedDistance:info.distanceTo withParams:OsmAndFormatterParams.useLowerBounds];

    if (description.length == 0)
        description = turnType ? [self nextTurnsToString:turnType nextTurnType:nextTurnType] : nil;

    return description.length == 0 ? distance : [NSString stringWithFormat:OALocalizedString(@"ltr_or_rtl_combine_via_comma"), distance, description];
}

+ (BOOL)shouldKeepLeft:(OASTurnType *)type
{
    return type && [OASTurnType.companion isLeftTurnType:type.value];
}

+ (BOOL)shouldKeepRight:(OASTurnType *)type
{
    return type && [OASTurnType.companion isRightTurnType:type.value];
}

+ (NSString *)nextTurnsToString:(OASTurnType *)type nextTurnType:(OASTurnType *)nextTurnType
{
    if ([type isRoundAbout])
    {
        if ([self shouldKeepLeft:nextTurnType])
            return [NSString stringWithFormat:OALocalizedString(@"auto_25_chars_route_roundabout_kl"), type.exitOut];
        else if ([self shouldKeepRight:nextTurnType])
            return [NSString stringWithFormat:OALocalizedString(@"auto_25_chars_route_roundabout_kr"), type.exitOut];
        else
            return [NSString stringWithFormat:OALocalizedString(@"route_roundabout_exit"), type.exitOut];
    }
    else if (type.value == OASTurnType.companion.TU || type.value == OASTurnType.companion.TRU)
    {
        if ([self shouldKeepLeft:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tu_kl");
        else if ([self shouldKeepRight:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tu_kr");
        else
            return OALocalizedString(@"auto_25_chars_route_tu");
    }
    else if (type.value == OASTurnType.companion.C)
    {
        return OALocalizedString(@"route_head");
    }
    else if (type.value == OASTurnType.companion.TSLL)
    {
        return OALocalizedString(@"auto_25_chars_route_tsll");
    }
    else if (type.value == OASTurnType.companion.TL)
    {
        if ([self shouldKeepLeft:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tl_kl");
        else if ([self shouldKeepRight:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tl_kr");
        else
            return OALocalizedString(@"auto_25_chars_route_tl");
    }
    else if (type.value == OASTurnType.companion.TSHL)
    {
        return OALocalizedString(@"auto_25_chars_route_tshl");
    }
    else if (type.value == OASTurnType.companion.TSLR)
    {
        return OALocalizedString(@"auto_25_chars_route_tslr");
    }
    else if (type.value == OASTurnType.companion.TR)
    {
        if ([self shouldKeepLeft:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tr_kl");
        else if ([self shouldKeepRight:nextTurnType])
            return OALocalizedString(@"auto_25_chars_route_tr_kr");
        else
            return OALocalizedString(@"auto_25_chars_route_tr");
    }
    else if (type.value == OASTurnType.companion.TSHR)
    {
        return OALocalizedString(@"auto_25_chars_route_tshr");
    }
    else if (type.value == OASTurnType.companion.KL)
    {
        return OALocalizedString(@"auto_25_chars_route_kl");
    }
    else if (type.value == OASTurnType.companion.KR)
    {
        return OALocalizedString(@"auto_25_chars_route_kr");
    }
    return @"";
}

// MARK: Turn state

+ (OASTurnType *)followingTurnTypeWithTimeDistances:(OAAnnounceTimeDistances *)atd info:(OANextDirectionInfo *)info speed:(float)speed distance:(int)distance
{
    if ([atd isTurnStateActive:speed dist:distance turnType:kStateTurnIn])
    {
        if (info && info.directionInfo &&
            ([atd isTurnStateActive:speed dist:info.distanceTo turnType:kStateTurnNow]
             || ![atd isTurnStateNotPassed:speed dist:info.distanceTo turnType:kStateTurnIn]))
            return info.directionInfo.turnType;
    }
    return nullptr;
}

// MARK: Navigation metadata (instrument cluster / HUD)

+ (CPManeuverType)maneuverTypeForTurnType:(OASTurnType *)type isLast:(BOOL)isLast API_AVAILABLE(ios(17.4))
{
    if (!type)
        return isLast ? CPManeuverTypeArriveAtDestination : CPManeuverTypeNoTurn;

    if ([type isRoundAbout])
    {
        static const CPManeuverType exits[] = {
            CPManeuverTypeRoundaboutExit1, CPManeuverTypeRoundaboutExit2, CPManeuverTypeRoundaboutExit3,
            CPManeuverTypeRoundaboutExit4, CPManeuverTypeRoundaboutExit5, CPManeuverTypeRoundaboutExit6,
            CPManeuverTypeRoundaboutExit7, CPManeuverTypeRoundaboutExit8, CPManeuverTypeRoundaboutExit9,
            CPManeuverTypeRoundaboutExit10, CPManeuverTypeRoundaboutExit11, CPManeuverTypeRoundaboutExit12,
            CPManeuverTypeRoundaboutExit13, CPManeuverTypeRoundaboutExit14, CPManeuverTypeRoundaboutExit15,
            CPManeuverTypeRoundaboutExit16, CPManeuverTypeRoundaboutExit17, CPManeuverTypeRoundaboutExit18,
            CPManeuverTypeRoundaboutExit19
        };
        int exit = type.exitOut;
        if (exit >= 1 && exit <= 19)
            return exits[exit - 1];
        return CPManeuverTypeEnterRoundabout;
    }

    if (isLast)
        return CPManeuverTypeArriveAtDestination;

    int v = type.value;
    if (v == OASTurnType.companion.TL)
        return CPManeuverTypeLeftTurn;
    if (v == OASTurnType.companion.TSLL)
        return CPManeuverTypeSlightLeftTurn;
    if (v == OASTurnType.companion.TSHL)
        return CPManeuverTypeSharpLeftTurn;
    if (v == OASTurnType.companion.TR)
        return CPManeuverTypeRightTurn;
    if (v == OASTurnType.companion.TSLR)
        return CPManeuverTypeSlightRightTurn;
    if (v == OASTurnType.companion.TSHR)
        return CPManeuverTypeSharpRightTurn;
    if (v == OASTurnType.companion.KL)
        return CPManeuverTypeKeepLeft;
    if (v == OASTurnType.companion.KR)
        return CPManeuverTypeKeepRight;
    if (v == OASTurnType.companion.TU || v == OASTurnType.companion.TRU)
        return CPManeuverTypeUTurn;
    if (v == OASTurnType.companion.C)
        return CPManeuverTypeStraightAhead;
    return CPManeuverTypeNoTurn;
}

+ (void)applyMetadataToManeuver:(CPManeuver *)maneuver turnType:(OASTurnType *)turnType leftSide:(BOOL)leftSide isLast:(BOOL)isLast
{
    BOOL roundabout = turnType && [turnType isRoundAbout];
    maneuver.trafficSide = leftSide ? CPTrafficSideLeft : CPTrafficSideRight;
    maneuver.junctionType = roundabout ? CPJunctionTypeRoundabout : CPJunctionTypeIntersection;
    maneuver.maneuverType = [self maneuverTypeForTurnType:turnType isLast:isLast];

    if (roundabout && turnType.turnAngle != 0)
    {
        // OsmAnd roundabout angle is clockwise 0..360, CarPlay expects -180..180
        double angle = turnType.turnAngle;
        if (angle > 180)
            angle -= 360;
        maneuver.junctionExitAngle = [[NSMeasurement alloc] initWithDoubleValue:angle unit:NSUnitAngle.degrees];
    }
}

/// Approximate direction of a lane turn in degrees: left is negative, right is positive.
+ (double)angleForLaneTurnValue:(int)value
{
    if (value == OASTurnType.companion.TL)
        return -90;
    if (value == OASTurnType.companion.TSLL)
        return -45;
    if (value == OASTurnType.companion.TSHL)
        return -135;
    if (value == OASTurnType.companion.KL)
        return -20;
    if (value == OASTurnType.companion.TR)
        return 90;
    if (value == OASTurnType.companion.TSLR)
        return 45;
    if (value == OASTurnType.companion.TSHR)
        return 135;
    if (value == OASTurnType.companion.KR)
        return 20;
    if (value == OASTurnType.companion.TU)
        return -180;
    if (value == OASTurnType.companion.TRU)
        return 180;
    return 0;
}

+ (CPLaneGuidance *)laneGuidanceForLanes:(OASKotlinIntArray *)lanes instruction:(NSString *)instruction
{
    if (!lanes || lanes.size == 0)
        return nil;

    NSMutableArray<CPLane *> *result = [NSMutableArray array];
    for (int i = 0; i < lanes.size; i++)
    {
        int lane = [lanes getIndex:i];
        int turns[] = {
            [OASTurnType.companion getPrimaryTurnLaneValue:lane],
            [OASTurnType.companion getSecondaryTurnLaneValue:lane],
            [OASTurnType.companion getTertiaryTurnLaneValue:lane]
        };
        NSMutableArray<NSMeasurement<NSUnitAngle *> *> *angles = [NSMutableArray array];
        double primaryAngle = 0;
        for (int j = 0; j < 3; j++)
        {
            // 0 means "not set" for the secondary and tertiary slots
            if (j > 0 && turns[j] == 0)
                continue;
            double angle = [self angleForLaneTurnValue:turns[j]];
            if (angles.count == 0)
                primaryAngle = angle;
            [angles addObject:[[NSMeasurement alloc] initWithDoubleValue:angle unit:NSUnitAngle.degrees]];
        }

        CPLane *cpLane;
        if ((lane & 1) == 1)
        {
            NSMeasurement<NSUnitAngle *> *highlighted = [[NSMeasurement alloc] initWithDoubleValue:primaryAngle unit:NSUnitAngle.degrees];
            cpLane = [[CPLane alloc] initWithAngles:angles highlightedAngle:highlighted isPreferred:YES];
        }
        else
        {
            cpLane = [[CPLane alloc] initWithAngles:angles];
        }
        [result addObject:cpLane];
    }

    CPLaneGuidance *guidance = [[CPLaneGuidance alloc] init];
    guidance.lanes = result;
    guidance.instructionVariants = instruction.length > 0 ? @[instruction] : @[];
    return guidance;
}

+ (CPManeuverState)maneuverStateForDistance:(int)distance speed:(float)speed timeDistances:(OAAnnounceTimeDistances *)atd
{
    if ([atd isTurnStateActive:speed dist:distance turnType:kStateTurnNow])
        return CPManeuverStateExecute;
    if ([atd isTurnStateActive:speed dist:distance turnType:kStateTurnIn])
        return CPManeuverStatePrepare;
    if ([atd isTurnStateActive:speed dist:distance turnType:kStatePrepareTurn])
        return CPManeuverStateInitial;
    return CPManeuverStateContinue;
}

+ (NSArray<CPManeuver *> *)routeManeuversWithLeftSide:(BOOL)leftSide userInterfaceStyle:(UIUserInterfaceStyle)style limit:(NSUInteger)limit
{
    OARoutingHelper *routingHelper = OARoutingHelper.sharedInstance;
    NSMutableArray<CPManeuver *> *result = [NSMutableArray array];
    OANextDirectionInfo *info = [routingHelper getNextRouteDirectionInfo:[[OANextDirectionInfo alloc] init] toSpeak:NO];
    while (info && info.directionInfo && result.count < limit)
    {
        OANextDirectionInfo *next = [routingHelper getNextRouteDirectionInfoAfter:info to:[[OANextDirectionInfo alloc] init] toSpeak:NO];
        BOOL isLast = !next || !next.directionInfo;
        OASTurnType *turnType = info.directionInfo.turnType;

        CPManeuver *maneuver = [[CPManeuver alloc] init];
        if (turnType)
        {
            maneuver.symbolImage = [self turnImageForType:turnType
                                                 imminent:info.imminent
                                        deviatedFromRoute:NO
                                       userInterfaceStyle:style
                                                fixedSize:0];
        }
        maneuver.instructionVariants = @[
            [self nextTurnDescriptionForInfo:info turnType:turnType nextTurnType:isLast ? nil : next.directionInfo.turnType]
        ];
        [self applyMetadataToManeuver:maneuver turnType:turnType leftSide:leftSide isLast:isLast];
        maneuver.userInfo = @{ @"routeManeuverIndex": @(result.count) };
        [result addObject:maneuver];

        info = next;
    }
    return result;
}

@end
