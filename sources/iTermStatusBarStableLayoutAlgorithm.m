//
//  iTermStatusBarStableLayoutAlgorithm.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 1/20/19.
//

#import "iTermStatusBarStableLayoutAlgorithm.h"

#import "DebugLogging.h"
#import "iTermStatusBarComponent.h"
#import "iTermStatusBarContainerView.h"
#import "iTermStatusBarFixedSpacerComponent.h"
#import "iTermStatusBarSpringComponent.h"
#import "NSArray+iTerm.h"

@implementation iTermStatusBarStableLayoutAlgorithm

- (iTermStatusBarContainerView *)containerViewWithLargestMinimumWidthFromViews:(NSArray<iTermStatusBarContainerView *> *)views {
    return [views maxWithBlock:^NSComparisonResult(iTermStatusBarContainerView *obj1, iTermStatusBarContainerView *obj2) {
        return [@(obj1.component.statusBarComponentMinimumWidth) compare:@(obj2.component.statusBarComponentMinimumWidth)];
    }];
}

- (NSArray<iTermStatusBarContainerView *> *)allPossibleCandidateViews {
    return [self unhiddenContainerViews];
}

- (BOOL)componentIsSpacer:(id<iTermStatusBarComponent>)component {
    return ([component isKindOfClass:[iTermStatusBarSpringComponent class]] ||
            [component isKindOfClass:[iTermStatusBarFixedSpacerComponent class]]);
}

- (BOOL)views:(NSArray<iTermStatusBarContainerView *> *)views
haveSpacersOnBothSidesOfIndex:(NSInteger)index
         left:(out id<iTermStatusBarComponent>*)leftOut
        right:(out id<iTermStatusBarComponent>*)rightOut {
    if (index == 0) {
        return NO;
    }
    if (index + 1 == views.count) {
        return NO;
    }
    id<iTermStatusBarComponent> left = views[index - 1].component;
    id<iTermStatusBarComponent> right = views[index + 1].component;
    if (![self componentIsSpacer:left] || ![self componentIsSpacer:right]) {
        return NO;
    }
    *leftOut = left;
    *rightOut = right;
    return YES;
}

- (CGFloat)minimumWidthOfContainerViews:(NSArray<iTermStatusBarContainerView *> *)views {
    iTermStatusBarContainerView *viewWithLargestMinimumWidth = [self containerViewWithLargestMinimumWidthFromViews:views];
    const CGFloat largestMinimumSize = viewWithLargestMinimumWidth.component.statusBarComponentMinimumWidth;
    NSArray<iTermStatusBarContainerView *> *viewsExFixedSpacers = [self viewsExcludingFixedSpacers:views];
    const CGFloat widthOfAllFixedSpacers = [self widthOfFixedSpacersAmongViews:views];
    return largestMinimumSize * viewsExFixedSpacers.count + widthOfAllFixedSpacers;
}

- (NSArray<iTermStatusBarContainerView *> *)visibleContainerViewsAllowingEqualSpacingFromViews:(NSArray<iTermStatusBarContainerView *> *)visibleContainerViews {
    NSArray<iTermStatusBarContainerView *> *sortedViews = [self containerViewsSortedByPriority:visibleContainerViews];
    return [self visibleContainerViewsAllowingEqualSpacingFromSortedViews:sortedViews
                                                             orderedViews:visibleContainerViews];
}

- (NSArray<iTermStatusBarContainerView *> *)visibleContainerViewsAllowingEqualSpacingFromSortedViews:(NSArray<iTermStatusBarContainerView *> *)sortedViews
                                                                                        orderedViews:(NSArray<iTermStatusBarContainerView *> *)orderedViews {
    if (_statusBarWidth >= [self minimumWidthOfContainerViews:orderedViews]) {
        return orderedViews;
    }
    if (orderedViews.count == 0) {
        return @[];
    }
    
    // Find the views with equal priority to the first. Note the views are sorted by priority.
    const double priority = sortedViews.firstObject.component.statusBarComponentPriority;
    const NSInteger index = [sortedViews indexOfObjectPassingTest:^BOOL(iTermStatusBarContainerView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.component.statusBarComponentPriority > priority;
    }];
    const NSRange range = (index == NSNotFound) ? NSMakeRange(0, sortedViews.count) : NSMakeRange(0, index);
    NSArray<iTermStatusBarContainerView *> *removalCandidates = [sortedViews subarrayWithRange:range];
    
    // Of those, remove the one with the largest minimum width.
    iTermStatusBarContainerView *viewWithLargestMinimumWidth = [self bestViewToRemoveFrom:removalCandidates];
    iTermStatusBarContainerView *adjacentViewToRemove = [self viewToRemoveAdjacentToViewBeingRemoved:viewWithLargestMinimumWidth
                                                                                           fromViews:orderedViews];
    if (adjacentViewToRemove) {
        sortedViews = [sortedViews arrayByRemovingObject:adjacentViewToRemove];
        orderedViews = [orderedViews arrayByRemovingObject:adjacentViewToRemove];
    }
    sortedViews = [sortedViews arrayByRemovingObject:viewWithLargestMinimumWidth];
    orderedViews = [orderedViews arrayByRemovingObject:viewWithLargestMinimumWidth];
    return [self visibleContainerViewsAllowingEqualSpacingFromSortedViews:sortedViews
                                                             orderedViews:orderedViews];
}

- (iTermStatusBarContainerView *)bestViewToRemoveFrom:(NSArray<iTermStatusBarContainerView *> *)views {
    NSInteger (^score)(iTermStatusBarContainerView *) = ^NSInteger(iTermStatusBarContainerView *view) {
        if ([view.component isKindOfClass:[iTermStatusBarSpringComponent class]]) {
            return 2;
        }
        if ([view.component isKindOfClass:[iTermStatusBarFixedSpacerComponent class]]) {
            return 1;
        }
        return 0;
    };
    return [views maxWithComparator:^NSComparisonResult(iTermStatusBarContainerView *a, iTermStatusBarContainerView *b) {
        NSInteger aScore = score(a);
        NSInteger bScore = score(b);
        if (aScore == 0 && bScore == 0) {
            // Tiebreak nonspacers by minimum width
            aScore = a.component.statusBarComponentMinimumWidth;
            bScore = b.component.statusBarComponentMinimumWidth;
        }
        return [@(aScore) compare:@(bScore)];
    }];
}

- (NSArray<iTermStatusBarContainerView *> *)visibleContainerViewsAllowingEqualSpacing {
    if (_statusBarWidth <= 0) {
        return @[];
    }
    return [self visibleContainerViewsAllowingEqualSpacingFromViews:[self allPossibleCandidateViews]];
}

- (iTermStatusBarContainerView *)viewToRemoveAdjacentToViewBeingRemoved:(iTermStatusBarContainerView *)viewBeingRemoved
                                                              fromViews:(NSArray<iTermStatusBarContainerView *> *)views {
    NSInteger index = [views indexOfObject:viewBeingRemoved];
    assert(index != NSNotFound);
    id<iTermStatusBarComponent> left;
    id<iTermStatusBarComponent> right;
    if (![self views:views haveSpacersOnBothSidesOfIndex:[views indexOfObject:viewBeingRemoved] left:&left right:&right]) {
        return nil;
    }
    if (left.statusBarComponentSpringConstant > right.statusBarComponentSpringConstant) {
        return views[index - 1];
    } else if (left.statusBarComponentSpringConstant < right.statusBarComponentSpringConstant) {
        return views[index + 1];
    } else if (index < views.count / 2) {
        return views[index + 1];
    } else {
        return views[index - 1];
    }
}

- (NSArray<iTermStatusBarContainerView *> *)viewsExcludingFixedSpacers:(NSArray<iTermStatusBarContainerView *> *)views {
    return [views filteredArrayUsingBlock:^BOOL(iTermStatusBarContainerView *view) {
        return ![view.component isKindOfClass:[iTermStatusBarFixedSpacerComponent class]];
    }];
}

- (CGFloat)widthOfFixedSpacersAmongViews:(NSArray<iTermStatusBarContainerView *> *)views {
    return [[views reduceWithFirstValue:@0 block:^id(NSNumber *partialSum, iTermStatusBarContainerView *view) {
        if (![view.component isKindOfClass:[iTermStatusBarFixedSpacerComponent class]]) {
            return partialSum;
        }
        return @(partialSum.doubleValue + view.component.statusBarComponentMinimumWidth);
    }] doubleValue];
}

- (double)sumOfSpringConstantsInViews:(NSArray<iTermStatusBarContainerView *> *)views {
    return [[views reduceWithFirstValue:@0 block:^id(NSNumber *partialSum, iTermStatusBarContainerView *view) {
        return @(partialSum.doubleValue + view.component.statusBarComponentSpringConstant);
    }] doubleValue];
}

- (void)updateDesiredWidthsForViews:(NSArray<iTermStatusBarContainerView *> *)views {
    [self updateMargins:views];
    NSArray<iTermStatusBarContainerView *> *viewsExFixedSpacers = [self viewsExcludingFixedSpacers:views];
    const CGFloat widthOfAllFixedSpacers = [self widthOfFixedSpacersAmongViews:views];
    const CGFloat totalMarginWidth = [self totalMarginWidthForViews:views];
    const CGFloat availableWidth = _statusBarWidth - totalMarginWidth - widthOfAllFixedSpacers;
    const double sumOfSpringConstants = [self sumOfSpringConstantsInViews:viewsExFixedSpacers];
    const CGFloat apportionment = availableWidth / sumOfSpringConstants;
    DLog(@"updateDesiredWidthsForViews available=%@ apportionment=%@", @(availableWidth), @(apportionment));
    // Allocate minimum widths
    [views enumerateObjectsUsingBlock:^(iTermStatusBarContainerView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([view.component isKindOfClass:[iTermStatusBarFixedSpacerComponent class]]) {
            view.desiredWidth = view.component.statusBarComponentMinimumWidth;
            return;
        }
        view.desiredWidth = apportionment * view.component.statusBarComponentSpringConstant;
    }];
}

- (NSArray<iTermStatusBarContainerView *> *)visibleContainerViews {
    NSArray<iTermStatusBarContainerView *> *visibleContainerViews = [self visibleContainerViewsAllowingEqualSpacing];

    [self updateDesiredWidthsForViews:visibleContainerViews];
    return visibleContainerViews;
}

@end
