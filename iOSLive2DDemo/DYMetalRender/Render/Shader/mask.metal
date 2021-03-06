//
//  mask.metal
//  iOSLive2DDemo
//
//  Created by VanJay on 2020/12/19.
//

#include <metal_stdlib>
#import "L2DShaderType.h"

using namespace metal;

// Combine color with mask.
fragment float4 mask_fragment(VertexOut fragment_in [[stage_in]],
                              texture2d<float> texture [[texture(L2DTextureIndexUniform)]],
                              texture2d<float> mask [[texture(L2DTextureIndexMask)]]) {
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear);

    constexpr sampler maskSampler(coord::pixel);

    float4 texture_color = texture.sample(textureSampler, fragment_in.uv);

    float4 mask_color = mask.sample(maskSampler, fragment_in.position.xy);

    texture_color.w *= fragment_in.opacity;
    texture_color.w *= mask_color.w;
    texture_color.xyz *= texture_color.w;

    return texture_color;
}
