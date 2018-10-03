//
//  RevenueTableViewController.m
//  FlurryRevenueSampleApp_Obj
//
//  Created by Yilun Xu on 10/3/18.
//  Copyright © 2018 Flurry. All rights reserved.
//

#import "RevenueTableViewController.h"
#import "Flurry.h"
#import <StoreKit/StoreKit.h>

@interface RevenueTableViewController () <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, strong) NSMutableArray<SKProduct *> *verifiedProducts;
@property (nonatomic, strong) NSSet<NSString *> *products;

@end

@implementation RevenueTableViewController

@synthesize autoLogSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // fetch products id from plist file
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"products"
                                         withExtension:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfURL:url];
    self.products = [NSSet setWithArray:productIdentifiers];
    
    //start request
    if (![SKPaymentQueue canMakePayments]) {
        return;
    }
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:self.products];
    request.delegate = self;
    [request start];
    
    // record toggle position
    NSUserDefaults *defaults =[NSUserDefaults standardUserDefaults];
    if(![[[defaults dictionaryRepresentation] allKeys] containsObject:@"iapReporting"]){
        NSLog(@"not found");
        [defaults setBool:YES forKey:@"iapReporting"];
        autoLogSwitch.on = YES;
    } else {
        autoLogSwitch.on = [defaults boolForKey:@"iapReporting"];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - StoreKit delegate + observer

// load all valid requests from app stroe into tableview
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    self.verifiedProducts = [NSMutableArray array];
    // invalid products
    for (NSString *identifier in response.invalidProductIdentifiers) {
        NSLog(@"invalid identifier:  %@", identifier);
    }
    // valid products
    for (SKProduct *product in response.products) {
        [self.verifiedProducts addObject:product];
    }
    [self.tableView reloadData];
}

// one or more transactions has been updated
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                if (!autoLogSwitch.isOn) {
                    [Flurry logPaymentTransaction:transaction statusCallback:^(FlurryTransactionRecordStatus status) {
                        [self displayAlertWithTitle:@"Success" message:[self stringForTransactionRecordStatus:status]];
                    }];
                } else {
                    [self displayAlertWithTitle:@"Success" message:@"Apyment went througth successfully"];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                if (!autoLogSwitch.isOn) {
                    [Flurry logPaymentTransaction:transaction statusCallback:^(FlurryTransactionRecordStatus status) {
                        [self displayAlertWithTitle:@"Failed" message:[self stringForTransactionRecordStatus:status]];
                    }];
                } else {
                    [self displayAlertWithTitle:@"Failed" message:@"Payment did not go througth"];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateDeferred:
                [self displayAlertWithTitle:@"Purchasing" message:nil];
                break;
            case SKPaymentTransactionStateRestored:
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
        }
    }
    
}

// alert display
-(void)displayAlertWithTitle:(NSString *)title message:(NSString *)message {

    // set alert controller
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    
    // present the alert
    [self presentViewController:controller animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [controller dismissViewControllerAnimated:YES completion:nil];
            });
    }];
}

- (NSString *)stringForTransactionRecordStatus:(FlurryTransactionRecordStatus)status {
    switch (status) {
        case FlurryTransactionRecorded:
            return @"Recorded";
        case FlurryTransactionRecordFailed:
            return @"Failed to Record";
        case FlurryTransactionRecordExceeded:
            return @"Record Exceeded";
        case FlurryTransactionRecodingDisabled:
            return @"Recording Disabled";
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.verifiedProducts.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return @"Products";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    SKProduct *product = self.verifiedProducts[indexPath.row];
    
    cell.textLabel.text = product.localizedTitle;
    if ([product.priceLocale respondsToSelector:@selector(countryCode)]) {
        if (@available(iOS 10.0, *)) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@%@", product.priceLocale.countryCode, product.priceLocale.currencySymbol, product.price];
        } else {
            // Fallback on earlier versions
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
            [numberFormatter setLocale:product.priceLocale];
            NSString *formattedString = [numberFormatter stringFromNumber:product.price];
            cell.detailTextLabel.text = formattedString;
            
        }
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Price :  %@", product.price];
    }
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"product id is : %@", self.verifiedProducts[indexPath.row].productIdentifier);
    if ([SKPaymentQueue canMakePayments]) {
        SKPayment *payment = [SKPayment paymentWithProduct:self.verifiedProducts[indexPath.row]];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    } else {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error" message:@"Purchases are disabled in your device" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [controller addAction:okAction];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (IBAction)updateAutoLogSwitch:(UISwitch *)sender {
    [Flurry setIAPReportingEnabled:sender.isOn];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSLog(@"change value");
    
    [defaults setBool:sender.isOn forKey:@"iapReporting"];
    [defaults synchronize];
}
@end
