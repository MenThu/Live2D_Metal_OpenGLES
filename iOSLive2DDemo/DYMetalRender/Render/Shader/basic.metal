//
//  basic.metal
//  iOSLive2DDemo
//
//  Created by VanJay on 2020/12/19.
//

#include <metal_stdlib>
#import "L2DShaderType.h"
#import "DYShaderTypes.h"

using namespace metal;

vertex VertexOut basic_vertex(constant float4x4 &transform [[buffer(L2DBufferIndexTransform)]],
                              VertexIn vertex_in [[stage_in]]) {
    return VertexOut(transform * float4(vertex_in.position, 0.0, 1),
                     float2(vertex_in.uv.x, -vertex_in.uv.y),
                     vertex_in.opacity);
}

fragment float4 basic_fragment(VertexOut fragment_in [[stage_in]],
                               texture2d<float> texture [[texture(L2DTextureIndexUniform)]]) {
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear);
    float4 color = texture.sample(textureSampler, fragment_in.uv);
    color.w *= fragment_in.opacity;
    color.xyz *= color.w;
    return color;
}


//上传纹理的shader
// Vertex shader outputs and fragment shader inputs for texturing pipeline.
struct TexturePipelineRasterizerData {
    float4 position [[position]];
    float2 texcoord;
};

// Vertex shader which adjusts positions by an aspect ratio and passes texture
// coordinates through to the rasterizer.
vertex TexturePipelineRasterizerData textureVertexShader(const uint vertexID [[vertex_id]],
                                                 const device DYTextureVertex *vertices
                                                 [[buffer(DYVertexInputIndexVertices)]]) {
    TexturePipelineRasterizerData out;
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.x = vertices[vertexID].position.x;
    out.position.y = vertices[vertexID].position.y;
    out.texcoord = vertices[vertexID].texcoord;
    return out;
}

// Fragment shader that samples a texture and outputs the sampled color.
fragment float4 textureFragmentShader(TexturePipelineRasterizerData in [[stage_in]],
                                      texture2d<float> texture [[texture(DYTextureInputIndexColor)]]) {
    constexpr sampler simpleSampler;
    // Sample data from the texture.
    float4 colorSample = texture.sample(simpleSampler, in.texcoord);
    // Return the color sample as the final color.
    return colorSample;
}

