#import "VMLockListDataSource.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../patch/VMRVAManagerCell.h"
#import "../pointer/VMPointerLockCell.h"
#import "../pointer/VMSignatureLockCell.h"
#import "VMItemCardCell.h"
#import "VMScriptViewController.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import "include/VMRVAPatch.h"
#import "include/VMSignatureModel.h"

#define TR(key) ([[VMLocalization shared] localizedString:key])

@implementation VMLockListDataSource

- (instancetype)initWithDataProvider:(id<VMLockListDataProvider>)provider
                            delegate:(id)delegate {
  if (self = [super init]) {
    _dataProvider = provider;
    _delegate = delegate;
  }
  return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if ([self.dataProvider isFolderMode] && [self.dataProvider currentTab] >= 2) {
    return [self.dataProvider folderList].count;
  }
  return [self.dataProvider currentDisplayData].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSInteger currentTab = [self.dataProvider currentTab];
  BOOL isFolderMode = [self.dataProvider isFolderMode];

  if (currentTab >= 2 && isFolderMode) {
    static NSString *cid = @"folder";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:cid];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *bid = [self.dataProvider folderList][indexPath.row];
    NSDictionary *meta = [self.dataProvider folderMetadata][bid];
    NSString *name = meta[@"name"];
    NSString *ver = meta[@"ver"];
    NSUInteger count = [meta[@"count"] unsignedIntegerValue];
    if (ver.length > 0)
      cell.textLabel.text = [NSString stringWithFormat:@"%@ - v%@", name, ver];
    else
      cell.textLabel.text = name;
    cell.detailTextLabel.text =
        [NSString stringWithFormat:@"%@ (%lu)", bid, (unsigned long)count];
    cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
    cell.imageView.tintColor = [VMUIHelper accentColor];
    cell.textLabel.font = [VMUIHelper scaledFontOfSize:17 weight:UIFontWeightSemibold];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  }

  NSArray *dataSrc = [self.dataProvider currentDisplayData];
  if (indexPath.row >= dataSrc.count)
    return [UITableViewCell new];

  if (currentTab == 0) {
    static NSString *cid = @"VMItemCardCell_Lock";
    VMItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[VMItemCardCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:cid];
      cell.delegate = self.delegate;
    }
    NSMutableDictionary *item = [dataSrc[indexPath.row] mutableCopy];
    if (![item[@"enabled"] boolValue]) {
      uint64_t addr = [item[@"addr"] unsignedLongLongValue];
      VMDataType type = (VMDataType)[item[@"type"] intValue];
      NSString *realVal = [[VMMemoryEngine shared] readAddress:addr type:type];
      item[@"val"] = realVal ?: @"-";
    }
    [cell configureWithDict:item isFavorite:NO];
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 1) {
    static NSString *cid = @"VMItemCardCell_Fav";
    VMItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[VMItemCardCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:cid];
      cell.delegate = self.delegate;
    }
    NSMutableDictionary *item = [dataSrc[indexPath.row] mutableCopy];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    VMDataType type =
        item[@"type"] ? (VMDataType)[item[@"type"] intValue] : VMDataTypeInt32;
    NSString *realVal = [[VMMemoryEngine shared] readAddress:addr type:type];
    item[@"val"] = realVal ?: @"-";
    [cell configureWithDict:item isFavorite:YES];
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 2) {
    VMPointerLockCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"VMPointerLockCell"
                                        forIndexPath:indexPath];
    cell.delegate = self.delegate;
    VMPointerChain *chain = dataSrc[indexPath.row];
    NSString *addrStr = TR(@"Placeholder_None");
    NSString *valStr = TR(@"Placeholder_None");
    BOOL isConnected = ([VMMemoryEngine shared].targetTask != MACH_PORT_NULL);
    if (isConnected) {
      uint64_t finalAddr = [self.dataProvider forceResolveChain:chain];
      if (finalAddr > 0) {
        addrStr = [NSString stringWithFormat:@"0x%llX", finalAddr];
        VMDataType t = (VMDataType)chain.lockType;
        valStr = [[VMMemoryEngine shared] readAddress:finalAddr type:t];
      } else {
        addrStr = TR(@"Text_Null");
      }
    } else {
      valStr = TR(@"Status_Disconnected");
    }
    VMDataType type =
        (VMDataType)chain.lockType;
    NSString *typeStr = [self.dataProvider typeNameForType:type];
    [cell configureWithChain:chain address:addrStr val:valStr type:typeStr];
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 3) {
    static NSString *rvaCellID = @"VMRVAManagerCell";
    VMRVAManagerCell *cell =
        [tableView dequeueReusableCellWithIdentifier:rvaCellID];
    if (!cell) {
      cell = [[VMRVAManagerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:rvaCellID];
      cell.delegate = self.delegate;
    }
    VMRVAPatch *patch = dataSrc[indexPath.row];
    [cell configureWithPatch:patch];
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 4) {
    VMSignatureLockCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"VMSignatureLockCell"
                                        forIndexPath:indexPath];
    cell.delegate = self.delegate;
    id rawSig = dataSrc[indexPath.row];
    if ([rawSig isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
      [cell configureWithSignature:(VMSignatureModel *)rawSig];
    } else {
      
    }
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 5) {
    static NSString *cid = @"verifyFileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:cid];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *fileName = dataSrc[indexPath.row];
    cell.textLabel.text = fileName;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.imageView.image =
        [UIImage systemImageNamed:@"doc.text.magnifyingglass"];

    NSString *fullPath = [[[self.dataProvider getDirectoryForCurrentTab]
        stringByAppendingPathComponent:[self.dataProvider targetBundleID]]
        stringByAppendingPathComponent:fileName];
    NSDictionary *attr =
        [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath
                                                         error:nil];
    if (attr) {
      NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
      [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
      cell.detailTextLabel.text =
          [fmt stringFromDate:attr.fileModificationDate];
      cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
      cell.detailTextLabel.text = @"-";
    }

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  } else if (currentTab == 6) {
    static NSString *scID = @"scriptCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:scID];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:scID];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    VMScriptModel *model = dataSrc[indexPath.row];
    cell.textLabel.text = model.note ?: model.fileName;
    cell.detailTextLabel.text = [NSString
        stringWithFormat:@"@%@  •  %@", model.author ?: @"?", model.fileName];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = [UIImage systemImageNamed:@"scroll"];
    cell.imageView.tintColor = model.isImported ? [UIColor systemOrangeColor]
                                                : [UIColor systemBlueColor];
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  }

  return [UITableViewCell new];
}
@end
