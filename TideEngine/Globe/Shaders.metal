#include <metal_stdlib>
using namespace metal;

kernel void tidalHeightField(
    device const float* heightField [[buffer(0)]],
    texture2d<float, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    const uint width = outTexture.get_width();   // 512
    const uint height = outTexture.get_height(); // 256

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    // Map output pixel to heightfield coordinates
    float hfX = float(gid.x) * 64.0 / 512.0; // [0, 64)
    float hfY = float(gid.y) * 32.0 / 256.0; // [0, 32)

    // Bilinear interpolation indices
    int ix0 = int(floor(hfX));
    int ix1 = (ix0 + 1) % 64;       // wrap longitude
    int iy0 = int(floor(hfY));
    int iy1 = min(iy0 + 1, 31);     // clamp latitude

    float fx = fract(hfX);
    float fy = fract(hfY);

    float v00 = heightField[iy0 * 64 + ix0];
    float v10 = heightField[iy0 * 64 + ix1];
    float v01 = heightField[iy1 * 64 + ix0];
    float v11 = heightField[iy1 * 64 + ix1];

    float val = mix(mix(v00, v10, fx), mix(v01, v11, fx), fy);

    // Three-stop color gradient: navy → teal → white
    // Remap val from [-1, 1] to [0, 1]
    float t = (val + 1.0) / 2.0;
    t = clamp(t, 0.0, 1.0);

    const float4 navy  = float4(0.04, 0.055, 0.10, 1.0);
    const float4 teal  = float4(0.0,  0.90,  1.0,  1.0);
    const float4 white = float4(1.0,  1.0,   1.0,  1.0);

    float4 color;
    if (t < 0.75) {
        // navy → teal
        color = mix(navy, teal, t / 0.75);
    } else {
        // teal → white
        color = mix(teal, white, (t - 0.75) / 0.25);
    }

    outTexture.write(color, gid);
}
