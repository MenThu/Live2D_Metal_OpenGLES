//
//  MetalListController.m
//  iOSLive2DDemo
//
//  Created by menthu on 2021/7/2.
//

#import "MetalListController.h"
#import "DYMetalController.h"

@interface MetalListController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray <NSString *> *modelArray;

@property (nonatomic, weak) UITableView *tableView;

@end

@implementation MetalListController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSMutableArray <NSString *> *modelArray = [NSMutableArray array];
    [modelArray addObject:@"Shanbao"];
    [modelArray addObject:@"Mark"];
    [modelArray addObject:@"nainiu"];
    [modelArray addObject:@"Hiyori"];
    //[modelArray addObject:@"Rice"];
    self.modelArray = modelArray;
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:(_tableView = tableView)];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    
    self.tableView.frame = self.view.bounds;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.modelArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString * const reuseIdentifier = @"UITableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.textColor = UIColor.blackColor;
        cell.backgroundColor = [UIColor whiteColor];
    }
    cell.textLabel.text = self.modelArray[indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 45;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DYMetalController *controller = [[DYMetalController alloc] initWithModel:self.modelArray[indexPath.row]
                                                                    inBundle:@"Live2DResource"];
    [self.navigationController pushViewController:controller animated:YES];
}


@end
