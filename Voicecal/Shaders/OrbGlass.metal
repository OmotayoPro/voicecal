#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The `glass` layer of the mic orb: a round lens over whatever is drawn beneath it.
// Parameters follow Figma's glass effect (refraction, depth, dispersion, light angle, light intensity).
//
//   size        the layer's size in points; the lens fills it
//   refraction  0...1, how strongly the rim bends what is beneath it
//   depth       points, the width of the curved rim, measured in from the edge
//   dispersion  0...1, how far red and blue separate where the glass bends
//   toLight     unit vector pointing from the centre towards the light
//   intensity   0...1, strength of the highlights on the rim
[[ stitchable ]] half4 orbGlass(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float refraction,
    float depth,
    float dispersion,
    float2 toLight,
    float intensity
) {
    float2 centre = size * 0.5;
    float radius = min(size.x, size.y) * 0.5;
    float2 fromCentre = position - centre;
    float distance = length(fromCentre);
    if (distance >= radius) {
        return layer.sample(position);
    }
    float2 outward = distance > 0.001 ? fromCentre / distance : float2(0.0);

    // 0 across the flat middle of the lens, rising to 1 at the edge over the curved rim.
    float rim = smoothstep(radius - depth, radius, distance);
    float curve = rim * rim;

    // A convex rim shows what lies nearer the centre, so the middle's light is carried outwards.
    float2 bend = -outward * refraction * depth * curve;

    // Each colour bends by a slightly different amount.
    float spread = 0.3 * dispersion;
    half4 middle = layer.sample(position + bend);
    half red = layer.sample(position + bend * (1.0 + spread)).r;
    half blue = layer.sample(position + bend * (1.0 - spread)).b;
    half4 colour = half4(red, middle.g, blue, middle.a);

    // The curved rim darkens a little before the edge, which gives the lens its roundness.
    float shade = 1.0 - 0.22 * smoothstep(0.35, 0.9, rim) * (1.0 - smoothstep(0.9, 1.0, rim));
    colour.rgb *= half(shade);

    // Highlights: a bright one on the rim facing the light, a fainter one opposite.
    float facing = dot(outward, toLight);
    float edge = smoothstep(radius - 2.0, radius - 0.25, distance);
    float lit = pow(max(facing, 0.0), 5.0) + 0.4 * pow(max(-facing, 0.0), 5.0);
    colour.rgb += half3(half(lit * edge * intensity));

    return colour;
}
