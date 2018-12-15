uniform float4 shirr[7];
Texture2D<float4> ImageTexture;
SamplerState _ImageTexture_sampler;
uniform float3 lightPos;
uniform int lightType;
uniform float3 lightDir;
uniform float2 spotlightData;
uniform float envmapStrength;
uniform float3 lightColor;

static float3 wnormal;
static float2 texCoord;
static float3 eyeDir;
static float3 wposition;
static float4 fragColor;

struct SPIRV_Cross_Input
{
    float3 eyeDir : TEXCOORD0;
    float2 texCoord : TEXCOORD1;
    float3 wnormal : TEXCOORD2;
    float3 wposition : TEXCOORD3;
};

struct SPIRV_Cross_Output
{
    float4 fragColor : SV_Target0;
};

float attenuate(float dist)
{
    return 1.0f / (dist * dist);
}

float3 surfaceAlbedo(float3 baseColor, float metalness)
{
    return lerp(baseColor, 0.0f.xxx, metalness.xxx);
}

float3 surfaceF0(float3 baseColor, float metalness)
{
    return lerp(0.039999999105930328369140625f.xxx, baseColor, metalness.xxx);
}

float3 lambertDiffuseBRDF(float3 albedo, float nl)
{
    return albedo * max(0.0f, nl);
}

float d_ggx(float nh, float a)
{
    float a2 = a * a;
    float denom = pow(((nh * nh) * (a2 - 1.0f)) + 1.0f, 2.0f);
    return (a2 * 0.3183098733425140380859375f) / denom;
}

float v_smithschlick(float nl, float nv, float a)
{
    return 1.0f / (((nl * (1.0f - a)) + a) * ((nv * (1.0f - a)) + a));
}

float3 f_schlick(float3 f0, float vh)
{
    return f0 + ((1.0f.xxx - f0) * exp2((((-5.554729938507080078125f) * vh) - 6.9831600189208984375f) * vh));
}

float3 specularBRDF(float3 f0, float roughness, float nl, float nh, float nv, float vh)
{
    float a = roughness * roughness;
    return (f_schlick(f0, vh) * (d_ggx(nh, a) * clamp(v_smithschlick(nl, nv, a), 0.0f, 1.0f))) / 4.0f.xxx;
}

float3 shIrradiance(float3 nor)
{
    float3 cl00 = float3(shirr[0].x, shirr[0].y, shirr[0].z);
    float3 cl1m1 = float3(shirr[0].w, shirr[1].x, shirr[1].y);
    float3 cl10 = float3(shirr[1].z, shirr[1].w, shirr[2].x);
    float3 cl11 = float3(shirr[2].y, shirr[2].z, shirr[2].w);
    float3 cl2m2 = float3(shirr[3].x, shirr[3].y, shirr[3].z);
    float3 cl2m1 = float3(shirr[3].w, shirr[4].x, shirr[4].y);
    float3 cl20 = float3(shirr[4].z, shirr[4].w, shirr[5].x);
    float3 cl21 = float3(shirr[5].y, shirr[5].z, shirr[5].w);
    float3 cl22 = float3(shirr[6].x, shirr[6].y, shirr[6].z);
    return ((((((((((cl22 * 0.429042994976043701171875f) * ((nor.y * nor.y) - ((-nor.z) * (-nor.z)))) + (((cl20 * 0.743125021457672119140625f) * nor.x) * nor.x)) + (cl00 * 0.88622701168060302734375f)) - (cl20 * 0.2477079927921295166015625f)) + (((cl2m2 * 0.85808598995208740234375f) * nor.y) * (-nor.z))) + (((cl21 * 0.85808598995208740234375f) * nor.y) * nor.x)) + (((cl2m1 * 0.85808598995208740234375f) * (-nor.z)) * nor.x)) + ((cl11 * 1.02332794666290283203125f) * nor.y)) + ((cl1m1 * 1.02332794666290283203125f) * (-nor.z))) + ((cl10 * 1.02332794666290283203125f) * nor.x);
}

float3 tonemapFilmic(float3 color)
{
    float3 x = max(0.0f.xxx, color - 0.0040000001899898052215576171875f.xxx);
    return (x * ((x * 6.19999980926513671875f) + 0.5f.xxx)) / ((x * ((x * 6.19999980926513671875f) + 1.7000000476837158203125f.xxx)) + 0.0599999986588954925537109375f.xxx);
}

void frag_main()
{
    float3 n = normalize(wnormal);
    float3 TextureCoordinate_UV_res_wt = float3(texCoord.x, 1.0f - texCoord.y, 0.0f);
    float4 ImageTexture_store = ImageTexture.Sample(_ImageTexture_sampler, float2(TextureCoordinate_UV_res_wt.x, 1.0f - TextureCoordinate_UV_res_wt.y));
    float3 _356 = pow(ImageTexture_store.xyz, 2.2000000476837158203125f.xxx);
    ImageTexture_store = float4(_356.x, _356.y, _356.z, ImageTexture_store.w);
    float3 vVec = normalize(eyeDir);
    float dotNV = max(dot(n, vVec), 0.0f);
    float3 ImageTexture_Color_res = ImageTexture_store.xyz;
    float3 basecol = ImageTexture_Color_res;
    float roughness = 0.60000002384185791015625f;
    float metallic = 0.0f;
    float occlusion = 1.0f;
    float specular = 1.0f;
    float visibility = 1.0f;
    float3 lp = lightPos - wposition;
    float3 l;
    if (lightType == 0)
    {
        l = lightDir;
    }
    else
    {
        l = normalize(lp);
        visibility *= attenuate(distance(wposition, lightPos));
    }
    float3 h = normalize(vVec + l);
    float dotNL = dot(n, l);
    float dotNH = dot(n, h);
    float dotVH = dot(vVec, h);
    if (lightType == 2)
    {
        float spotEffect = dot(lightDir, l);
        if (spotEffect < spotlightData.x)
        {
            visibility *= smoothstep(spotlightData.y, spotlightData.x, spotEffect);
        }
    }
    float3 albedo = surfaceAlbedo(basecol, metallic);
    float3 f0 = surfaceF0(basecol, metallic);
    float3 direct = lambertDiffuseBRDF(albedo, dotNL);
    direct += (specularBRDF(f0, roughness, dotNL, dotNH, dotNV, dotVH) * specular);
    float3 indirect = shIrradiance(n);
    indirect *= albedo;
    indirect *= envmapStrength;
    fragColor = float4(((direct * lightColor) * visibility) + (indirect * occlusion), 1.0f);
    float3 _497 = tonemapFilmic(fragColor.xyz);
    fragColor = float4(_497.x, _497.y, _497.z, fragColor.w);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    wnormal = stage_input.wnormal;
    texCoord = stage_input.texCoord;
    eyeDir = stage_input.eyeDir;
    wposition = stage_input.wposition;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.fragColor = fragColor;
    return stage_output;
}
