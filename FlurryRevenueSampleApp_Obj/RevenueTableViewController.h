//
//  RevenueTableViewController.h
//  FlurryRevenueSampleApp_Obj
//
//  Created by Yilun Xu on 10/3/18.
//  Copyright © 2018 Flurry. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RevenueTableViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UISwitch *autoLogSwitch;
- (IBAction)updateAutoLogSwitch:(UISwitch *)sender;

@end
