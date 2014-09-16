//
//  DBPickerCell.h
//  Lists
//
//  Created by Leah Culver on 8/4/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

@interface DBPickerCell : UITableViewCell

@property (strong, nonatomic) NSString *principal;

- (void)updateRole:(NSInteger)role effectiveRole:(NSInteger)effectiveRole;

@end
