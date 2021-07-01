//
//  DYLive2DModel.m
//  iOSLive2DDemo
//
//  Created by menthu on 2021/7/1.
//

#import "DYLive2DModel.h"
#import "NSBundle+Live2DModel.h"
#import "CubismBasicType.hpp"
#import "CubismModelSettingJson.hpp"
#import "CubismUserModel.hpp"
#import "CubismIdManager.hpp"
#import "CubismRenderer.hpp"
#import "L2DAppDefine.h"
#import <Utils/CubismString.hpp>
#import <Motion/CubismMotion.hpp>
#import <CubismDefaultParameterId.hpp>

using namespace ::L2DAppDefine;
using namespace Live2D::Cubism;
using namespace Live2D::Cubism::Core;
using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::Rendering;
using namespace Live2D::Cubism::Framework::DefaultParameterId;

@interface DYLive2DModel ()
{
    const Csm::CubismId *_idParamAngleX;                             ///< 参数ID: ParamAngleX
    const Csm::CubismId *_idParamAngleY;                             ///< 参数ID: ParamAngleX
    const Csm::CubismId *_idParamAngleZ;                             ///< 参数ID: ParamAngleX
    const Csm::CubismId *_idParamBodyAngleX;                         ///< 参数ID: ParamBodyAngleX
    const Csm::CubismId *_idParamEyeBallX;                           ///< 参数ID: ParamEyeBallX
    const Csm::CubismId *_idParamEyeBallY;                           ///< 参数ID: ParamEyeBallXY
}

@property (nonatomic, strong) NSString *assetName;
@property(nonatomic, assign) CubismModelSettingJson *modelSetting;
@property(nonatomic, assign) CubismUserModel *model;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *expressionMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *motionMap;
@property (nonatomic, strong) NSBundle *live2DResourceBundle;
@property (nonatomic, assign) Csm::csmVector<Csm::CubismIdHandle> eyeBlinkIds; ///< 模型中设置的眨眼功能的参数ID
@property (nonatomic, assign) Csm::csmVector<Csm::CubismIdHandle> lipSyncIds;  ///< 模型中设置的口型同步功能的参数ID
@property (nonatomic, assign) Csm::csmFloat32 userTimeSeconds; ///<  增量时间的积分值[秒]

@end

@implementation DYLive2DModel

- (instancetype)initWithBundleName:(NSString *)bundleName jsonFileName:(NSString *)modelJsonName{
    if (self = [super init]) {
        _assetName = modelJsonName;
        _modelSetting = NULL;
        _expressionMap = [[NSMutableDictionary alloc] init];
        _motionMap = [[NSMutableDictionary alloc] init];
        _live2DResourceBundle = [NSBundle modelResourceForBundleName:bundleName modelName:modelJsonName];
        
        //read model3.json config file
        NSString *model3FilePath = _live2DResourceBundle.model3FilePath;
        if (model3FilePath == nil) {
            return nil;
        }
        NSData *jsonFile = [[NSData alloc] initWithContentsOfFile:model3FilePath];
        _modelSetting = new Csm::CubismModelSettingJson((const Csm::csmByte *)jsonFile.bytes,
                                                        (Csm::csmSizeInt)jsonFile.length);
        [self loadModel];
        [self loadExpression];
        [self loadPhysics];
        [self loadPose];
        [self loadEyeBlink];
        [self loadBreath];
        [self loadUserData];
        [self loadLipSyncIds];
        [self loadMotion];
    }
    return self;
}

- (void)loadEyeBlink{
    Csm::csmInt32 eyeBlinkCount = _modelSetting->GetEyeBlinkParameterCount();
    if (eyeBlinkCount > 0) {//eyeBlinkCount = 2
        _model->_eyeBlink = Csm::CubismEyeBlink::Create(_modelSetting);
    }
}

- (void)loadBreath{
    _model->_breath = Csm::CubismBreath::Create();

    Csm::csmVector<Csm::CubismBreath::BreathParameterData> breathParameters;

    breathParameters.PushBack(Csm::CubismBreath::BreathParameterData(_idParamAngleX, 0.0f, 15.0f, 6.5345f, 0.5f));
    breathParameters.PushBack(Csm::CubismBreath::BreathParameterData(_idParamAngleY, 0.0f, 8.0f, 3.5345f, 0.5f));
    breathParameters.PushBack(Csm::CubismBreath::BreathParameterData(_idParamAngleZ, 0.0f, 10.0f, 5.5345f, 0.5f));
    breathParameters.PushBack(Csm::CubismBreath::BreathParameterData(_idParamBodyAngleX, 0.0f, 4.0f, 15.5345f, 0.5f));
    breathParameters.PushBack(Csm::CubismBreath::BreathParameterData(
        Csm::CubismFramework::GetIdManager()->GetId(Csm::DefaultParameterId::ParamBreath), 0.5f, 0.5f, 3.2345f, 0.5f));

    _model->_breath->SetParameters(breathParameters);
}

- (void)loadUserData{
    // UserData
    const Csm::csmChar *path = _modelSetting->GetUserDataFile();
    NSString *userDataFileName = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
    if (userDataFileName != NULL && userDataFileName.length > 0) {
        userDataFileName = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:userDataFileName];
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:userDataFileName];
        _model->LoadUserData((const Csm::csmByte *)fileData.bytes, (Csm::csmSizeInt)fileData.length);
    }
}

- (void)loadLipSyncIds{
    Csm::csmInt32 lipSyncIdCount = _modelSetting->GetLipSyncParameterCount();
    for (Csm::csmInt32 i = 0; i < lipSyncIdCount; ++i) {//lipSyncIdCount=1
        _lipSyncIds.PushBack(_modelSetting->GetLipSyncParameterId(i));
    }
}

- (void)loadModel{
    NSString *modelFileName = [NSString stringWithCString:self.modelSetting->GetModelFileName()
                                                 encoding:NSUTF8StringEncoding];
    if (modelFileName && modelFileName.length > 0) {
        CubismUserModel *model = CSM_NEW CubismUserModel();
        NSString *filePath = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:modelFileName];
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
        model->LoadModel((const Csm::csmByte *)fileData.bytes, (Csm::csmSizeInt)fileData.length);//size=368960
        
        Csm::csmMap<Csm::csmString, Csm::csmFloat32> layout;
        self.modelSetting->GetLayoutMap(layout);
        model->GetModelMatrix()->SetupFromLayout(layout);
        
        self.model = model;
    }
}

- (void)loadPose {
    NSString *poseFileName = [NSString stringWithCString:self.modelSetting->GetPoseFileName()
                                                encoding:NSUTF8StringEncoding];
    if (poseFileName && poseFileName.length > 0) {//poseFileName=nil
        NSString *filePath = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:poseFileName];
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
        self.model->LoadPose((const Csm::csmByte *)fileData.bytes, (Csm::csmSizeInt)fileData.length);
    }
}

- (void)loadExpression {
    Csm::csmInt32 expressionCount = self.modelSetting->GetExpressionCount();//expressionCount=0
    for (Csm::csmInt32 i = 0; i < expressionCount; ++i) {
        Csm::csmString expressionNameString = Csm::csmString(self.modelSetting->GetExpressionName(i));
        NSString *expressionName = [NSString stringWithCString:expressionNameString.GetRawString()
                                                      encoding:NSUTF8StringEncoding];
        NSValue *v = [self.expressionMap objectForKey:expressionName];
        if (v != nil) {
            Csm::ACubismMotion *expression = (Csm::ACubismMotion *)v.pointerValue;
            if (expression) {
                Csm::ACubismMotion::Delete(expression);
            }
            [self.expressionMap removeObjectForKey:expressionName];
        }
        
        NSString *expressionFileName =
        [NSString stringWithCString:self.modelSetting->GetExpressionFileName(i)
                           encoding:NSUTF8StringEncoding];
        NSString *expressionFilePath = [_live2DResourceBundle.bundlePath
                                        stringByAppendingPathComponent:expressionFileName];
        
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:expressionFilePath];
        Csm::ACubismMotion *expression = self.model->LoadExpression((const Csm::csmByte *)fileData.bytes,
                                                                    (Csm::csmSizeInt)fileData.length,
                                                                    [expressionName cStringUsingEncoding:
                                                                     NSUTF8StringEncoding]);
        if (expression) {
            [self.expressionMap setObject:[NSValue valueWithPointer:expression] forKey:expressionName];
        }
    }
}

- (void)loadPhysics {
    NSString *fileName = [NSString stringWithCString:self.modelSetting->GetPhysicsFileName()
                                            encoding:NSUTF8StringEncoding];
    NSString *filePath = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:fileName];
    NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
    if (fileData && fileData.length > 0) {//size = 7857
        self.model->LoadPhysics((const Csm::csmByte *)fileData.bytes, (Csm::csmSizeInt)fileData.length);
    }
}

- (void)loadMotion {
    Csm::csmInt32 motionGroupCount = self.modelSetting->GetMotionGroupCount();//motionGroupCount=1
    for (Csm::csmInt32 i = 0; i < motionGroupCount; ++i) {//应该有值
        const Csm::csmChar *motionGroupName = self.modelSetting->GetMotionGroupName(i);
        Csm::csmInt32 motionCount = self.modelSetting->GetMotionCount(motionGroupName);//motionCount = 1
        for (Csm::csmInt32 j = 0; j < motionCount; ++j) {
            NSString *motionName =
            [NSString stringWithCString:self.modelSetting->GetMotionFileName(motionGroupName, j)
                               encoding:NSUTF8StringEncoding];
            NSString *filePath = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:motionName];
            NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
            if (fileData && fileData.length > 0) {
                CubismMotion *motion = static_cast<CubismMotion *>(_model->LoadMotion((const Csm::csmByte *)fileData.bytes,
                                                                                          (Csm::csmSizeInt)fileData.length,
                                                                                          [motionName
                                                                                           cStringUsingEncoding:NSUTF8StringEncoding]));
                if (motion) {
                    NSValue *v = [self.motionMap objectForKey:motionName];
                    if (v != nil) {
                        Csm::ACubismMotion *expression = (Csm::ACubismMotion *)v.pointerValue;
                        if (expression) {
                            Csm::ACubismMotion::Delete(expression);
                        }
                        [self.motionMap removeObjectForKey:motionName];
                    }
                    csmFloat32 fadeTime = _modelSetting->GetMotionFadeInTimeValue(motionGroupName, j);
                    if (fadeTime >= 0.0f) {//fadeTime=-1
                        motion->SetFadeInTime(fadeTime);
                    }

                    fadeTime = _modelSetting->GetMotionFadeOutTimeValue(motionGroupName, j);
                    if (fadeTime >= 0.0f) {//fadeTime=-1
                        motion->SetFadeOutTime(fadeTime);
                    }
                    motion->SetEffectIds(_eyeBlinkIds, _lipSyncIds);
                    [self.motionMap setObject:[NSValue valueWithPointer:motion] forKey:motionName];
                }
            }
        }
    }
}

- (void)dealloc {
    NSLog(@"[%s:%d] [%@:%p] dealloc", __func__, __LINE__, NSStringFromClass(self.class), self);
    
    if (_motionMap) {
        [[_motionMap allValues] enumerateObjectsUsingBlock:^(NSValue *_Nonnull obj,
                                                             NSUInteger idx,
                                                             BOOL *_Nonnull stop) {
            ACubismMotion *motion = (ACubismMotion *)[obj pointerValue];
            if (motion) {
                ACubismMotion::Delete(motion);
            }
        }];
    }
    
    if (_expressionMap) {
      [[_expressionMap allValues] enumerateObjectsUsingBlock:^(NSValue *_Nonnull obj,
                                                               NSUInteger idx,
                                                               BOOL *_Nonnull stop) {
            ACubismMotion *motion = (ACubismMotion *)[obj pointerValue];
            if (motion) {
              ACubismMotion::Delete(motion);
            }
          }];
    }
    
    if (_model != NULL) {
        _model->DeleteRenderer();
        CSM_DELETE_SELF(CubismUserModel, _model);
    }

    if (_modelSetting != NULL) {
        CSM_DELETE_SELF(CubismModelSettingJson, _modelSetting);
    }
}

- (int)drawableCount{
    return _model->GetModel()->GetDrawableCount();
}

- (RawIntArray *)renderOrders{
    return [[RawIntArray alloc] initWithCArray:_model->GetModel()->GetDrawableRenderOrders()
                                         count:[self drawableCount]];
}

- (bool)isRenderOrderDidChangedForDrawable:(int)index{
    return _model->GetModel()->GetDrawableDynamicFlagRenderOrderDidChange(index);
}

- (RawFloatArray *)vertexPositionsForDrawable:(int)index{
    int vertexCount = _model->GetModel()->GetDrawableVertexCount(index);
    const float *positions = _model->GetModel()->GetDrawableVertices(index);
    return [[RawFloatArray alloc] initWithCArray:positions count:vertexCount];
}

- (RawFloatArray *)vertexTextureCoordinateForDrawable:(int)index{
    int vertexCount = _model->GetModel()->GetDrawableVertexCount(index);
    const Core::csmVector2 *uvs = _model->GetModel()->GetDrawableVertexUvs(index);
    return [[RawFloatArray alloc] initWithCArray:reinterpret_cast<const csmFloat32 *>(uvs) count:vertexCount];
}

- (RawUShortArray *)vertexIndicesForDrawable:(int)index{
    int indexCount = _model->GetModel()->GetDrawableVertexIndexCount(index);
    const unsigned short *indices = _model->GetModel()->GetDrawableVertexIndices(index);
    return [[RawUShortArray alloc] initWithCArray:indices count:indexCount];
}

- (int)textureIndexForDrawable:(int)index{
    return _model->GetModel()->GetDrawableTextureIndices(index);
}

- (RawIntArray *)masksForDrawable:(int)index{
    const int *maskCounts = _model->GetModel()->GetDrawableMaskCounts();
    const int **masks = _model->GetModel()->GetDrawableMasks();
    return [[RawIntArray alloc] initWithCArray:masks[index] count:maskCounts[index]];
}

- (L2DBlendMode)blendingModeForDrawable:(int)index{
    CubismModel *cubismModel = _model->GetModel();
    switch (cubismModel->GetDrawableBlendMode(index)) {
        case CubismRenderer::CubismBlendMode_Normal:
            return L2DBlendModeNormal;
        case CubismRenderer::CubismBlendMode_Additive:
            return L2DBlendModeAdditive;
        case CubismRenderer::CubismBlendMode_Multiplicative:
            return L2DBlendModeMultiplicative;
        default:
            return L2DBlendModeNormal;
    }
}

- (bool)cullingModeForDrawable:(int)index{
    return (_model->GetModel()->GetDrawableCulling(index) != 0);
}

- (float)opacityForDrawable:(int)index{
    return _model->GetModel()->GetDrawableOpacity(index);
}

- (bool)visibilityForDrawable:(int)index{
    return _model->GetModel()->GetDrawableDynamicFlagIsVisible(index);
}

- (NSArray<NSData *> *)textureDataArray{
    NSString *bundlePath = _live2DResourceBundle.bundlePath;
    NSMutableArray <NSData *> *textureDataArray = [NSMutableArray array];
    csmInt32 textureCount = _modelSetting->GetTextureCount();
    for (int i = 0; i < textureCount; ++i) {//textureCount = 1
        @autoreleasepool {
            NSString *name = [NSString stringWithCString:_modelSetting->GetTextureFileName(i)
                                                encoding:NSUTF8StringEncoding];
            NSData *textureData = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:name]];
            [textureDataArray addObject:textureData];
        }
    }
    return textureDataArray;
}

- (void)update{
    CubismModel *cubismModel = _model->GetModel();
    cubismModel->Update();
    CubismMotionManager *motionManager = _model->_expressionManager;
    if (motionManager != NULL) {
        motionManager->UpdateMotion(cubismModel, 5.0);// 使用面部表情进行参数更新（相对变化）
    }
}

- (bool)isOpacityDidChangedForDrawable:(int)index{
    return _model->GetModel()->GetDrawableDynamicFlagOpacityDidChange(index);
}

- (bool)isVertexPositionDidChangedForDrawable:(int)index{
    return _model->GetModel()->GetDrawableDynamicFlagVertexPositionsDidChange(index);
}

- (void)updateWithDeltaTime:(NSTimeInterval)dt{
    
    const csmFloat32 deltaTimeSeconds = dt;
    _userTimeSeconds += deltaTimeSeconds;

    _model->_dragManager->Update(deltaTimeSeconds);
    _model->_dragX = _model->_dragManager->GetX();
    _model->_dragY = _model->_dragManager->GetY();

    // 是否存在通过运动进行参数更新
    csmBool motionUpdated = false;

    // -----------------------------------------------------------------
    CubismModel *cubismModel = _model->GetModel();
    cubismModel->LoadParameters();  // 加载先前保存的状态
    if (_model->_motionManager->IsFinished()) {
        // 如果没有动作播放，它将从待机动作中随机播放。
        [self startRandomMotion:MotionGroupIdle priority:PriorityIdle onFinishedMotionHandler:NULL];
    } else {
        motionUpdated = _model->_motionManager->UpdateMotion(cubismModel, deltaTimeSeconds);  // 更新动作
    }
    cubismModel->SaveParameters();  // 保存状态
    // -----------------------------------------------------------------

    // 闪烁
    if (!motionUpdated) {
        if (_model->_eyeBlink != NULL) {
            // メインモーションの更新がないとき
            _model->_eyeBlink->UpdateParameters(cubismModel, deltaTimeSeconds);  // 目パチ
        }
    }

    if (_model->_expressionManager != NULL) {
        _model->_expressionManager->UpdateMotion(cubismModel, deltaTimeSeconds);  // 表情でパラメータ更新（相対変化）
    }

    // 由于拖动而发生的变化
    // 通过拖动来调整脸部方向
    cubismModel->AddParameterValue(_idParamAngleX, _model->_dragX * 30);  // -30から30の値を
    cubismModel->AddParameterValue(_idParamAngleY, _model->_dragY * 30);
    cubismModel->AddParameterValue(_idParamAngleZ, _model->_dragX * _model->_dragY * -30);

    // 通过拖动来调整身体方向
    cubismModel->AddParameterValue(_idParamBodyAngleX, _model->_dragX * 10);  // -10から10の値を加える

    // 拖动以调整眼睛方向
    cubismModel->AddParameterValue(_idParamEyeBallX, _model->_dragX);  // -1から1の値を加える
    cubismModel->AddParameterValue(_idParamEyeBallY, _model->_dragY);

    // 呼吸等
    if (_model->_breath != NULL) {
        _model->_breath->UpdateParameters(cubismModel, deltaTimeSeconds);
    }

    // 物理设置
    if (_model->_physics != NULL) {
        _model->_physics->Evaluate(cubismModel, deltaTimeSeconds);
    }

    // 嘴唇同步设置
    if (_model->_lipSync) {
        csmFloat32 value = 0;  // リアルタイムでリップシンクを行う場合、システムから音量を取得して0〜1の範囲で値を入力します。

        for (csmUint32 i = 0; i < _lipSyncIds.GetSize(); ++i) {
            cubismModel->AddParameterValue(_lipSyncIds[i], value, 0.8f);
        }
    }

    // 姿势设定
    if (_model->_pose != NULL) {
        _model->_pose->UpdateParameters(cubismModel, deltaTimeSeconds);
    }

    if (_model->_physics != nil) {
        _model->_physics->Evaluate(cubismModel, dt);
    }
}

- (void *)startRandomMotion:(const csmChar *)group
                   priority:(csmInt32)priority
    onFinishedMotionHandler:(ACubismMotion::FinishedMotionCallback)onFinishedMotionHandler {
    if (_modelSetting->GetMotionCount(group) == 0) {
        return InvalidMotionQueueEntryHandleValue;
    }

    csmInt32 no = rand() % _modelSetting->GetMotionCount(group);
    return [self startMotion:group no:no priority:priority onFinishedMotionHandler:onFinishedMotionHandler];
}

- (void *)startMotion:(const csmChar *)group
                   no:(csmInt32)no
             priority:(csmInt32)priority
onFinishedMotionHandler:(ACubismMotion::FinishedMotionCallback)onFinishedMotionHandler {
    if (priority == PriorityForce) {
        _model->_motionManager->SetReservePriority(priority);
    } else if (!_model->_motionManager->ReserveMotion(priority)) {
        return InvalidMotionQueueEntryHandleValue;
    }

    csmString name = Utils::CubismString::GetFormatedString("%s_%d", group, no);
    NSString *ocName = [NSString stringWithCString:name.GetRawString() encoding:NSUTF8StringEncoding];
    CubismMotion *motion = (CubismMotion *)[self.motionMap[ocName] pointerValue];
    csmBool autoDelete = false;
    if (motion == NULL) {
        const csmString tempFileName = _modelSetting->GetMotionFileName(group, no);
        NSString *motionFileName = [NSString stringWithCString:tempFileName.GetRawString() encoding:NSUTF8StringEncoding];
        NSString *filePath = [_live2DResourceBundle.bundlePath stringByAppendingPathComponent:motionFileName];
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
        motion = static_cast<CubismMotion *>(_model->LoadMotion((const Csm::csmByte *)fileData.bytes,
                                                                (Csm::csmSizeInt)fileData.length,
                                                                NULL,
                                                                onFinishedMotionHandler));
        csmFloat32 fadeTime = _modelSetting->GetMotionFadeInTimeValue(group, no);
        if (fadeTime >= 0.0f) {
            motion->SetFadeInTime(fadeTime);
        }

        fadeTime = _modelSetting->GetMotionFadeOutTimeValue(group, no);
        if (fadeTime >= 0.0f) {
            motion->SetFadeOutTime(fadeTime);
        }
        motion->SetEffectIds(_eyeBlinkIds, _lipSyncIds);
        autoDelete = true;
    } else {
        motion->SetFinishedMotionHandler(onFinishedMotionHandler);
    }

    return _model->_motionManager->StartMotionPriority(motion, autoDelete, priority);
}

@end
