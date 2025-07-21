#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_passthrough(uint vid [[vertex_id]],
                                    const device float *vertexArray [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertexArray[vid * 6 + 0], vertexArray[vid * 6 + 1], 0, 1);
    out.texCoord = float2(vertexArray[vid * 6 + 4], vertexArray[vid * 6 + 5]);
    return out;
}
