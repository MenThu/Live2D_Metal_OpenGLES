//
//  DYShaderTypes.h
//  Live2DIntegration
//
//  Created by menthu on 2021/6/28.
//

#ifndef DYShaderTypes_h
#define DYShaderTypes_h

typedef enum DYVertexInputIndex{
    DYVertexInputIndexVertices      = 0,
    DYVertexInputIndexAspectRatio   = 1,
} DYVertexInputIndex;

typedef enum DYTextureInputIndex{
    DYTextureInputIndexColor = 0,
} DYTextureInputIndex;

typedef struct{
    vector_float2 position;
    vector_float2 texcoord;
} DYTextureVertex;

#endif /* DYShaderTypes_h */
