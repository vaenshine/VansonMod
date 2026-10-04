#import "VMUIHelper.h"
#import "include/VMIconHelper.h"
#import <objc/message.h>
#import <math.h>

@implementation VMUIHelper

+ (NSCache *)applicationIconCache {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 64; });
    return cache;
}
+ (void)cacheApplicationIcon:(UIImage *)icon forBundleID:(NSString *)bundleID {
    if (icon && !icon.isSymbolImage && bundleID.length)
        [[self applicationIconCache] setObject:icon forKey:bundleID];
}
+ (UIImage *)applicationIconForBundleID:(NSString *)bundleID {
    UIImage *icon = bundleID.length ? [[self applicationIconCache] objectForKey:bundleID] : nil;
    SEL selector = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (!icon && bundleID.length && [UIImage respondsToSelector:selector]) {
        icon = ((UIImage *(*)(id, SEL, NSString *, NSInteger, CGFloat))objc_msgSend)
            (UIImage.class, selector, bundleID, 0, UIScreen.mainScreen.scale);
    }
    [self cacheApplicationIcon:icon forBundleID:bundleID];
    return icon ?: [VMIconHelper compatibleSystemImageNamed:@"app"];
}
+ (UIView *)processHeaderWithName:(NSString *)name bundleID:(NSString *)bundleID pid:(int)pid {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 48)];
    view.insetsLayoutMarginsFromSafeArea = NO;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[self applicationIconForBundleID:bundleID]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = self.accentColor;
    icon.layer.cornerRadius = 8;
    icon.clipsToBounds = YES;
    icon.isAccessibilityElement = NO;
    UILabel *title = [UILabel new];
    title.text = name;
    title.font = [self scaledFontOfSize:15 weight:UIFontWeightSemibold];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = UIColor.labelColor;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    UILabel *detail = [UILabel new];
    detail.text = pid > 0 ? [NSString stringWithFormat:@"PID %d", pid] : nil;
    detail.font = [self scaledFontOfSize:12 weight:UIFontWeightRegular];
    detail.adjustsFontForContentSizeCategory = YES;
    detail.textColor = UIColor.secondaryLabelColor;
    detail.hidden = pid <= 0;
    [detail setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [detail setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, detail]];
    heading.alignment = UIStackViewAlignmentFirstBaseline;
    heading.spacing = 8;
    UILabel *identifier = [UILabel new];
    identifier.text = bundleID;
    identifier.font = [self scaledFontOfSize:12 weight:UIFontWeightRegular];
    identifier.adjustsFontForContentSizeCategory = YES;
    identifier.textColor = UIColor.secondaryLabelColor;
    identifier.numberOfLines = 0;
    identifier.lineBreakMode = NSLineBreakByCharWrapping;
    identifier.hidden = bundleID.length == 0;
    identifier.accessibilityIdentifier = @"processBundleID";
    identifier.accessibilityLabel = bundleID.length ? [@"Bundle ID: " stringByAppendingString:bundleID] : nil;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[heading, identifier]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:32], [icon.heightAnchor constraintEqualToConstant:32],
        [row.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:4],
        [row.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-4],
        [row.topAnchor constraintEqualToAnchor:view.topAnchor constant:6],
        [row.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-6]
    ]];
    return view;
}

+ (UIColor *)accentColor { return UIColor.systemIndigoColor; }
+ (UIColor *)filledColorForTint:(UIColor *)tint {
    // System accent colors target icons; small white button titles need a darker fill.
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        UIColor *resolved = [tint resolvedColorWithTraitCollection:traits];
        CGFloat r = 0, g = 0, b = 0, a = 1;
        if (![resolved getRed:&r green:&g blue:&b alpha:&a]) return resolved;
        double (^linear)(double) = ^double(double component) {
            return component <= .04045 ? component / 12.92 : pow((component + .055) / 1.055, 2.4);
        };
        CGFloat scale = 1;
        while (scale > .1) {
            double luminance = .2126 * linear(r * scale) + .7152 * linear(g * scale) + .0722 * linear(b * scale);
            if (1.05 / (luminance + .05) >= 4.6) break;
            scale -= .01;
        }
        return [UIColor colorWithRed:r * scale green:g * scale blue:b * scale alpha:1];
    }];
}
+ (UIColor *)canvasColor { return UIColor.systemGroupedBackgroundColor; }
+ (UIColor *)cardColor { return UIColor.secondarySystemGroupedBackgroundColor; }
+ (UIFont *)scaledFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];
}
+ (void)styleCard:(UIView *)view {
    view.backgroundColor = self.cardColor;
    view.layer.cornerRadius = 16;
    view.layer.cornerCurve = kCACornerCurveContinuous;
}
+ (void)styleTextField:(UITextField *)field {
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = UIColor.tertiarySystemFillColor;
    field.textColor = UIColor.labelColor;
    field.tintColor = self.accentColor;
    field.layer.cornerRadius = 10;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.font = [self scaledFontOfSize:15 weight:UIFontWeightRegular];
    field.adjustsFontForContentSizeCategory = YES;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    if (!field.leftView) {
        field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
        field.leftViewMode = UITextFieldViewModeAlways;
    }
    if (!field.rightView) {
        field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
        field.rightViewMode = UITextFieldViewModeAlways;
    }
}
+ (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = self.canvasColor;
    tableView.tintColor = self.accentColor;
    tableView.separatorColor = UIColor.separatorColor;
    tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.estimatedRowHeight = 72;
    if (@available(iOS 15.0, *)) tableView.sectionHeaderTopPadding = 8;
}
+ (void)styleButton:(UIButton *)button primary:(BOOL)primary {
    UIColor *color = button.tintColor ?: self.accentColor;
    if ([color isEqual:UIColor.systemBlueColor]) color = self.accentColor;
    UIColor *background = primary ? [self filledColorForTint:color] : [color colorWithAlphaComponent:.10];
    button.layer.cornerRadius = 12;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [self scaledFontOfSize:14 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [button.configuration copy] ?: [UIButtonConfiguration filledButtonConfiguration];
        config.baseForegroundColor = primary ? UIColor.whiteColor : color;
        config.baseBackgroundColor = background;
        config.background.backgroundColor = background;
        button.backgroundColor = UIColor.clearColor;
        config.background.cornerRadius = 12;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10, 12, 10, 12);
        config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *incoming) {
            NSMutableDictionary *attributes = [incoming mutableCopy];
            attributes[NSFontAttributeName] = [self scaledFontOfSize:14 weight:UIFontWeightSemibold];
            return attributes;
        };
        button.configuration = config;
    } else {
        button.backgroundColor = background;
        [button setTitleColor:primary ? UIColor.whiteColor : color forState:UIControlStateNormal];
        [button setTitleColor:UIColor.tertiaryLabelColor forState:UIControlStateDisabled];
        button.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
    }
}
+ (void)styleConfirmationItem:(UIBarButtonItem *)item {
    if (@available(iOS 26.0, *)) {
        item.tintColor = [self filledColorForTint:self.accentColor];
        [item setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor}
                            forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor}
                            forState:UIControlStateHighlighted];
    } else {
        item.tintColor = self.accentColor;
    }
}
+ (UINavigationBarAppearance *)navigationAppearance {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.canvasColor;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName:UIColor.labelColor,
        NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName:UIColor.labelColor,
        NSFontAttributeName:[UIFont systemFontOfSize:32 weight:UIFontWeightBold]};
    return appearance;
}
+ (void)installAppearance {
    UINavigationBarAppearance *appearance = self.navigationAppearance;
    UINavigationBar *nav = UINavigationBar.appearance;
    nav.standardAppearance = appearance;
    nav.compactAppearance = appearance;
    nav.scrollEdgeAppearance = appearance;
    nav.tintColor = self.accentColor;
    UITabBarAppearance *tab = [UITabBarAppearance new];
    [tab configureWithOpaqueBackground];
    tab.backgroundColor = self.cardColor;
    for (UITabBarItemAppearance *item in @[tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance]) {
        item.selected.iconColor = self.accentColor;
        item.selected.titleTextAttributes = @{NSForegroundColorAttributeName:self.accentColor};
        item.normal.iconColor = UIColor.secondaryLabelColor;
        item.normal.titleTextAttributes = @{NSForegroundColorAttributeName:UIColor.secondaryLabelColor};
    }
    UITabBar.appearance.standardAppearance = tab;
    UITabBar.appearance.tintColor = self.accentColor;
    if (@available(iOS 15.0, *)) {
        UITabBar.appearance.scrollEdgeAppearance = tab;
        nav.compactScrollEdgeAppearance = appearance;
    }
}
+ (void)applyNavigationAppearance:(UINavigationController *)navigationController {
    UINavigationBarAppearance *appearance = self.navigationAppearance;
    navigationController.navigationBar.standardAppearance = appearance;
    navigationController.navigationBar.compactAppearance = appearance;
    navigationController.navigationBar.scrollEdgeAppearance = appearance;
    if (@available(iOS 15.0, *)) navigationController.navigationBar.compactScrollEdgeAppearance = appearance;
    navigationController.navigationBar.tintColor = self.accentColor;
    navigationController.view.tintColor = self.accentColor;
}
// Navigation owns the page title. Content headers carry only useful context.
+ (UIView *)contextHeaderWithText:(NSString *)text symbol:(NSString *)symbol {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 44)];
    view.layoutMargins = UIEdgeInsetsMake(8, 4, 8, 4);
    UIImageView *icon = [[UIImageView alloc] initWithImage:[VMIconHelper compatibleSystemImageNamed:symbol]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = self.accentColor;
    icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    icon.isAccessibilityElement = NO;
    UILabel *detail = [UILabel new];
    detail.text = text;
    detail.font = [self scaledFontOfSize:13 weight:UIFontWeightRegular];
    detail.adjustsFontForContentSizeCategory = YES;
    detail.textColor = UIColor.secondaryLabelColor;
    detail.numberOfLines = 0;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, detail]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:20], [icon.heightAnchor constraintEqualToConstant:20],
        [row.leadingAnchor constraintEqualToAnchor:view.layoutMarginsGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:view.layoutMarginsGuide.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:view.layoutMarginsGuide.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:view.layoutMarginsGuide.bottomAnchor]
    ]];
    return view;
}
+ (void)sizeHeaderToFitTableView:(UITableView *)tableView {
    UIView *header = tableView.tableHeaderView;
    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (!header || width <= 0) return;
    CGFloat height = [header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    if (height <= 0) return;
    if (fabs(header.frame.size.height - height) > .5 || fabs(header.frame.size.width - width) > .5) {
        header.frame = CGRectMake(0, 0, width, ceil(height));
        tableView.tableHeaderView = header;
    }
}
+ (void)sizeFooterToFitTableView:(UITableView *)tableView {
    UIView *footer = tableView.tableFooterView;
    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (!footer || width <= 0) return;
    CGFloat height = [footer systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    if (height <= 0) return;
    if (fabs(footer.frame.size.height - height) > .5 || fabs(footer.frame.size.width - width) > .5) {
        footer.frame = CGRectMake(0, 0, width, ceil(height));
        tableView.tableFooterView = footer;
    }
}
+ (UIView *)emptyStateWithTitle:(NSString *)title message:(NSString *)message symbol:(NSString *)symbol {
    UIView *view = [UIView new];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[VMIconHelper compatibleSystemImageNamed:symbol]];
    icon.tintColor = [self.accentColor colorWithAlphaComponent:.65];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:32 weight:UIImageSymbolWeightLight];
    icon.isAccessibilityElement = NO;
    UILabel *heading = [UILabel new];
    heading.text = title;
    heading.font = [self scaledFontOfSize:17 weight:UIFontWeightSemibold];
    heading.textColor = UIColor.labelColor;
    heading.numberOfLines = 0;
    heading.textAlignment = NSTextAlignmentCenter;
    heading.adjustsFontForContentSizeCategory = YES;
    UILabel *detail = [UILabel new];
    detail.text = message;
    detail.font = [self scaledFontOfSize:14 weight:UIFontWeightRegular];
    detail.textColor = UIColor.secondaryLabelColor;
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.adjustsFontForContentSizeCategory = YES;
    detail.hidden = message.length == 0;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, heading, detail]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [icon.heightAnchor constraintEqualToConstant:42], [icon.widthAnchor constraintEqualToConstant:48],
        [heading.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [detail.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-28],
        [stack.centerYAnchor constraintEqualToAnchor:view.centerYAnchor]
    ]];
    return view;
}
+ (UIButton *)createButtonWithTitle:(NSString *)title color:(UIColor *)color target:(id)target action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.tintColor = color;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [self styleButton:button primary:YES];
    return button;
}
+ (UIButton *)createIconButton:(NSString *)iconName color:(UIColor *)color target:(id)target action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[VMIconHelper compatibleSystemImageNamed:iconName] forState:UIControlStateNormal];
    button.tintColor = color;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [self styleButton:button primary:NO];
    return button;
}
+ (UIView *)createVansonFooterViewForWidth:(CGFloat)width {
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 28)];
    footer.backgroundColor = UIColor.clearColor;
    footer.userInteractionEnabled = NO;
    footer.accessibilityIdentifier = @"vansonBrandFooter";
    footer.isAccessibilityElement = YES;
    footer.accessibilityLabel = @"VansonMod";

    NSString *alternate = UIApplication.sharedApplication.alternateIconName;
    NSDictionary *icons = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *entry = alternate.length ? icons[@"CFBundleAlternateIcons"][alternate] : icons[@"CFBundlePrimaryIcon"];
    NSString *imageName = [entry[@"CFBundleIconFiles"] firstObject] ?: (alternate.length ? alternate : @"AppIcon60x60");
    UIImage *image = [UIImage imageNamed:imageName] ?: [UIImage imageNamed:[imageName stringByAppendingString:@"@2x"]];
    UIImageView *icon = [[UIImageView alloc] initWithImage:image ?: [UIImage imageNamed:@"AppIcon60x60@2x"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.layer.cornerRadius = 5;
    icon.layer.cornerCurve = kCACornerCurveContinuous;
    icon.clipsToBounds = YES;
    [icon.widthAnchor constraintEqualToConstant:20].active = YES;
    [icon.heightAnchor constraintEqualToConstant:20].active = YES;

    UILabel *label = [UILabel new];
    label.text = @"VansonMod";
    label.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold] maximumPointSize:15];
    label.textColor = UIColor.secondaryLabelColor;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = .8;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 6;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.centerXAnchor constraintEqualToAnchor:footer.centerXAnchor],
        [row.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [row.topAnchor constraintGreaterThanOrEqualToAnchor:footer.topAnchor constant:2],
        [row.bottomAnchor constraintLessThanOrEqualToAnchor:footer.bottomAnchor constant:-2],
        [row.leadingAnchor constraintGreaterThanOrEqualToAnchor:footer.leadingAnchor constant:8],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:footer.trailingAnchor constant:-8]
    ]];
    return footer;
}
+ (void)addFixedFooterTo:(UIViewController *)vc forTableView:(UITableView *)tableView {
    // VMRootViewController owns the fixed brand beside the bottom navigation.
    // Content footers remain available for connection actions and settings details.
    [[vc.view viewWithTag:999111] removeFromSuperview];
}

@end
