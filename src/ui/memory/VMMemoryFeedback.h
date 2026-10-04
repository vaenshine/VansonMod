#import <UIKit/UIKit.h>

// A transient status banner keeps editing, scrolling, and action-sheet transitions available.
static inline void VMMemoryShowFeedback(UIViewController *controller, NSString *message) {
    if (!controller.isViewLoaded || message.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *host = controller.view;
        [[host viewWithTag:918204] removeFromSuperview];
        UIView *banner = [UIView new];
        banner.tag = 918204;
        banner.translatesAutoresizingMaskIntoConstraints = NO;
        banner.backgroundColor = UIColor.opaqueSeparatorColor;
        banner.layer.cornerRadius = 14;
        banner.layer.cornerCurve = kCACornerCurveContinuous;
        banner.layer.shadowColor = UIColor.blackColor.CGColor;
        banner.layer.shadowOpacity = 0.12;
        banner.layer.shadowRadius = 12;
        banner.layer.shadowOffset = CGSizeMake(0, 3);
        banner.userInteractionEnabled = NO;
        // A dynamic-color outline keeps the banner distinct above dark cards.
        UIView *surface = [UIView new];
        surface.translatesAutoresizingMaskIntoConstraints = NO;
        surface.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        surface.layer.cornerRadius = 13.5;
        surface.layer.cornerCurve = kCACornerCurveContinuous;
        [banner addSubview:surface];
        UILabel *label = [UILabel new];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.numberOfLines = 0;
        label.text = message;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        label.adjustsFontForContentSizeCategory = YES;
        label.textColor = UIColor.labelColor;
        label.textAlignment = NSTextAlignmentCenter;
        [surface addSubview:label];
        [host addSubview:banner];
        [NSLayoutConstraint activateConstraints:@[
            [banner.leadingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.leadingAnchor constant:16],
            [banner.trailingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.trailingAnchor constant:-16],
            [banner.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:8],
            [surface.topAnchor constraintEqualToAnchor:banner.topAnchor constant:0.5],
            [surface.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-0.5],
            [surface.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:0.5],
            [surface.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-0.5],
            [label.topAnchor constraintEqualToAnchor:banner.topAnchor constant:14],
            [label.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-14],
            [label.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:16],
            [label.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-16]
        ]];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.2 animations:^{ banner.alpha = 0; } completion:^(BOOL finished) { [banner removeFromSuperview]; }];
        });
    });
}
