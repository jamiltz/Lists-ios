//
//  DBPickerCell.m
//  Lists
//
//  Created by Leah Culver on 8/4/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBPickerCell.h"

#import <Dropbox/Dropbox.h>

@interface DBPickerCell()

@property (weak, nonatomic) IBOutlet UIPickerView *picker;

@end

@implementation DBPickerCell

- (void)updateRole:(NSInteger)role effectiveRole:(NSInteger)effectiveRole
{
    [self.picker selectRow:role inComponent:0 animated:NO];
    
    BOOL isEnabled = (DBRole)effectiveRole >= DBRoleEditor;
    [self.picker setUserInteractionEnabled:isEnabled];
    [self.picker setAlpha:isEnabled ? 1.0 : 0.6];
}

@end
