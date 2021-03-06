//
//  CALeftWeatherView.m
//  CamelliaApp
//
//  Created by kys-20 on 2017/11/3.
//  Copyright © 2017年 kys-20. All rights reserved.
//
#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height


#define widthPix kScreenWidth/320
#define heightPix kScreenHeight/568

#import "CALeftWeatherView.h"
#import <CoreLocation/CoreLocation.h>
#import <AddressBook/AddressBook.h>
#import "AFNetworking.h"
#import "WeatherModel.h"
@interface CALeftWeatherView() <CLLocationManagerDelegate>
@property(nonatomic, strong)  CLLocation *currLocation;
@property(strong,nonatomic)CLLocationManager *locationManager;
@property (nonatomic, strong) AFHTTPSessionManager *manager;
//多云动画
@property (nonatomic, strong) NSMutableArray *imageArr;//鸟图片数组
@property (nonatomic, strong) UIImageView *birdImage;//鸟本体
@property (nonatomic, strong) UIImageView *birdRefImage;//鸟倒影
@property (nonatomic, strong) UIImageView *cloudImageViewF;//云
@property (nonatomic, strong) UIImageView *cloudImageViewS;//云
//晴天动画
@property (nonatomic, strong) UIImageView *sunImage;//太阳
@property (nonatomic, strong) UIImageView *sunshineImage;//太阳光
@property (nonatomic, strong) UIImageView *sunCloudImage;//晴天云
//雨天动画
@property (nonatomic, strong) UIImageView *rainCloudImage;//乌云
@property (nonatomic, strong) NSArray *jsonArray;

@end

@implementation CALeftWeatherView

- (instancetype) init
{
    if (self = [super init])
    {
        [self createLocationManager];
    }
    return self;
}
#pragma mark =====地理位置初始化 =====
//初始化
- (void)createLocationManager
{
    self.locationManager = [[CLLocationManager alloc]init];
    
    self.locationManager.delegate=self;
    //  定位频率,每隔多少米定位一次
    // 距离过滤器，移动了几米之后，才会触发定位的代理函数
    self.locationManager.distanceFilter = 10;
    
    // 定位的精度，越精确，耗电量越高
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;//导航
    
    //请求允许在前台获取用户位置的授权
    [self.locationManager requestWhenInUseAuthorization];
    //求允许在前后台都能获取用户位置的授权
    //    [self.locationManager requestAlwaysAuthorization ];
    //允许后台定位更新,进入后台后有蓝条闪动
//    self.locationManager.allowsBackgroundLocationUpdates = YES;
    
    //判断定位设备是否能用和能否获得导航数据
    if ([CLLocationManager locationServicesEnabled]&&[CLLocationManager headingAvailable]){
        
        [self.locationManager startUpdatingLocation];//开启定位服务
        [self.locationManager startUpdatingHeading];//开始获得航向数据
        
        //        这个方法已被执行，就会回调下面的方法
        //        -(void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
    }
    else{
//        NSLog(@"不能获得航向数据");
    }

}
//获取位置 代理方法
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    self.currLocation = [locations lastObject];
    //基于CLGeocoder - 反地理编码
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    [geocoder reverseGeocodeLocation:self.currLocation
                   completionHandler:^(NSArray *placemarks, NSError *error) {
                       
                       if ([placemarks count] > 0) {
                           
                           CLPlacemark *placemark = placemarks[0];
                           
                           NSDictionary *addressDictionary =  placemark.addressDictionary;
                           
                           NSString *street = [addressDictionary
                                               objectForKey:(NSString *)kABPersonAddressStreetKey];
                           street = street == nil ? @"": street;
                           
                           NSString *country = placemark.country;
                           
                           NSString * subLocality = placemark.subLocality;
                           
                           NSString *city = [addressDictionary
                                             objectForKey:(NSString *)kABPersonAddressCityKey];
                           city = city == nil ? @"": city;
                           [self sendRequestToServer:city];
                           NSLog(@"%@",[NSString stringWithFormat:@"%@ \n%@ \n%@  %@ ",country, city,subLocality ,street]);
                       }
                   }];
}
//发送请求
- (void)sendRequestToServer:(NSString *)cityName {
    NSLog(@"%@",cityName);
    _manager = [AFHTTPSessionManager manager];
    
    NSString *url = [NSString stringWithFormat:@"https://api.thinkpage.cn/v3/weather/daily.json?key=osoydf7ademn8ybv&location=%@&language=zh-Hans&start=0&days=3",cityName];
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    
    [_manager GET:url parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"response=%@",responseObject);
        
        NSArray *resultArray = responseObject[@"results"];
        for (NSDictionary *dic in resultArray) {
            
            WeatherModel *model = [[WeatherModel alloc]init];
            model.cityName = dic[@"location"][@"name"];
            model.todayDic = (NSDictionary *)[dic[@"daily"] objectAtIndex:0];
            model.tomorrowDic = (NSDictionary *)[dic[@"daily"] objectAtIndex:1];
            model.afterTomorrowDic = (NSDictionary *)[dic[@"daily"] objectAtIndex:2];
            
            self.weatherView.model = model;
            [self addSubview:self.weatherView];
            //执行动画
             [self addAnimationWithType:[dic[@"daily"] objectAtIndex:0][@"code_day"]];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
}
#pragma mark =====创建VIew =====
//自定义的视图
- (CALeftWeatherViewVIew *)weatherView
{
    if (!_weatherView)
    {
        _weatherView = [[CALeftWeatherViewVIew alloc]initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
    }
    return _weatherView;
}

//添加动画
- (void)addAnimationWithType:(NSString *)weatherType{
    
    //先将所有的动画移除
    [self removeAnimationView];
    
    NSInteger type = [weatherType integerValue];
    //根返回的添加code判断天气然后对应的添加动画
    if (type >= 0 && type < 4) { //晴天
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_sunny_day.jpg"]];
        [self sun];//动画
    }
    else if (type >= 4 && type < 10) { //多云
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_normal.jpg"]];
//        [self wind];//动画
    }
    else if (type >= 10 && type < 20) { //雨
        //        [self changeImageAnimated:[UIImage imageNamed:@"bg_rain_day.jpg"]];
        //        [self rain];
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_snow_night.jpg"]];
        [self snow];
    }
    else if (type >= 20 && type < 26) { //雪
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_snow_night.jpg"]];
        [self snow];
    }
    else if (type >= 26 && type < 30) { //沙尘暴
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_sunny_day.jpg"]];
        
    }
    else if (type >= 30 && type < 32) { //雾霾
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_haze.jpg"]];
        
    }
    else if (type >= 32 && type < 37) { //风
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_sunny_day.jpg"]];
        
    }
    else if (type == 37) { //冷
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_fog_day.jpg"]];
        
    }
    else if (type == 38) { //热
//        [self changeImageAnimated:[UIImage imageNamed:@"bg_sunny_day.jpg"]];
        
    }
    else if (type == 99) { //未知
        
        
    }
    
//    [self.view bringSubviewToFront:self.weatherV];
//    [self.view bringSubviewToFront:self.changeCityBtn];//懒加载，将切换城市按钮拿到最上层
    
}
- (void)removeAnimationView {
    //先将所有的动画移除
    [self.birdImage removeFromSuperview];
    [self.birdRefImage removeFromSuperview];
    [self.cloudImageViewF removeFromSuperview];
    [self.cloudImageViewS removeFromSuperview];
    [self.sunImage removeFromSuperview];
    [self.sunshineImage removeFromSuperview];
    [self.sunCloudImage removeFromSuperview];
    [self.rainCloudImage removeFromSuperview];
    
    for (NSInteger i = 0; i < _jsonArray.count; i++) {
        UIImageView *rainLineView = (UIImageView *)[self viewWithTag:100+i];
        [rainLineView removeFromSuperview];//移除下雨
        
        UIImageView *snowView = (UIImageView *)[self viewWithTag:1000+i];
        [snowView removeFromSuperview];//移除雪
    }
    
}
//晴天动画
- (void)sun {
    //太阳
    _sunImage = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"ele_sunnySun"]];
    CGRect frameSun = _sunImage.frame;
    frameSun.size = CGSizeMake(200, 200*579/612.0);
    _sunImage.frame = frameSun;
    _sunImage.center = CGPointMake(kScreenHeight * 0.1, kScreenHeight * 0.1);
    [self addSubview:_sunImage];
    [_sunImage.layer addAnimation:[self sunshineAnimationWithDuration:40] forKey:nil];
    
    //    太阳光
    _sunshineImage = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"ele_sunnySunshine"]];
    CGRect _sunImageFrame = _sunshineImage.frame;
    _sunImageFrame.size = CGSizeMake(400, 400);
    _sunshineImage.frame = _sunImageFrame;
    _sunshineImage.center = CGPointMake(kScreenHeight * 0.1, kScreenHeight * 0.1);
    [self addSubview:_sunshineImage];
    [_sunshineImage.layer addAnimation:[self sunshineAnimationWithDuration:40] forKey:nil];
    
    
    //晴天云
    _sunCloudImage = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"ele_sunnyCloud2"]];
    CGRect frame = _sunCloudImage.frame;
    frame.size = CGSizeMake(kScreenHeight *0.7, kScreenWidth*0.5);
    _sunCloudImage.frame = frame;
    _sunCloudImage.center = CGPointMake(kScreenWidth * 0.25, kScreenHeight*0.5);
    [_sunCloudImage.layer addAnimation:[self birdFlyAnimationWithToValue:@(kScreenWidth+30) duration:50] forKey:nil];
    [self addSubview:_sunCloudImage];
    
}
//下雪
- (void)snow {
    
    //加载JSON文件
    NSString *path = [[NSBundle mainBundle] pathForResource:@"rainData.json" ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:path];
    //将JSON数据转为NSArray或NSDictionary
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    _jsonArray = dict[@"weather"][@"image"];
    for (NSInteger i = 0; i < _jsonArray.count; i++) {
        
        NSDictionary *dic = [_jsonArray objectAtIndex:i];
        UIImageView *snowView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"snow"]];
        snowView.tag = 1000+i;
        NSArray *originArr = [dic[@"-origin"] componentsSeparatedByString:@","];
        snowView.frame = CGRectMake([originArr[0] integerValue]*widthPix , [originArr[1] integerValue], arc4random()%7+3, arc4random()%7+3);
        [self addSubview:snowView];
        [snowView.layer addAnimation:[self rainAlphaWithDuration:5+i%5] forKey:nil];
        [snowView.layer addAnimation:[self rainAlphaWithDuration:5+i%5] forKey:nil];
        [snowView.layer addAnimation:[self sunshineAnimationWithDuration:5] forKey:nil];//雪花旋转
    }
    
}
//动画横向移动方法
- (CABasicAnimation *)birdFlyAnimationWithToValue:(NSNumber *)toValue duration:(NSInteger)duration{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    animation.toValue = toValue;
    animation.duration = duration;
    animation.removedOnCompletion = NO;
    animation.repeatCount = MAXFLOAT;
    animation.fillMode = kCAFillModeForwards;
    return animation;
}

//动画旋转方法
- (CABasicAnimation *)sunshineAnimationWithDuration:(NSInteger)duration{
    //旋转动画
    CABasicAnimation* rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 ];
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    rotationAnimation.duration = duration;
    rotationAnimation.repeatCount = MAXFLOAT;//你可以设置到最大的整数值
    rotationAnimation.cumulative = NO;
    rotationAnimation.removedOnCompletion = NO;
    rotationAnimation.fillMode = kCAFillModeForwards;
    return rotationAnimation;
}
//透明度动画
- (CABasicAnimation *)rainAlphaWithDuration:(NSInteger)duration {
    
    CABasicAnimation *showViewAnn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    showViewAnn.fromValue = [NSNumber numberWithFloat:1.0];
    showViewAnn.toValue = [NSNumber numberWithFloat:0.1];
    showViewAnn.duration = duration;
    showViewAnn.repeatCount = MAXFLOAT;
    showViewAnn.fillMode = kCAFillModeForwards;
    showViewAnn.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    showViewAnn.removedOnCompletion = NO;
    
    return showViewAnn;
}

@end
