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

@end
