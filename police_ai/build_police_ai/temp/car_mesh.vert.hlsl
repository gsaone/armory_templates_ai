uniform float4x4 W;
uniform float3x3 N;
uniform float4x4 WVP;
uniform float3 eye;

static float4 gl_Position;
static float3 pos;
static float2 texCoord;
static float2 tex;
static float3 wposition;
static float3 wnormal;
static float3 nor;
static float3 eyeDir;

struct SPIRV_Cross_Input
{
    float3 nor : TEXCOORD0;
    float3 pos : TEXCOORD1;
    float2 tex : TEXCOORD2;
};

struct SPIRV_Cross_Output
{
    float3 eyeDir : TEXCOORD0;
    float2 texCoord : TEXCOORD1;
    float3 wnormal : TEXCOORD2;
    float3 wposition : TEXCOORD3;
    float4 gl_Position : SV_Position;
};

void vert_main()
{
    float4 spos = float4(pos, 1.0f);
    texCoord = tex;
    wposition = float4(mul(spos, W)).xyz;
    wnormal = normalize(mul(nor, N));
    gl_Position = mul(spos, WVP);
    eyeDir = eye - wposition;
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    pos = stage_input.pos;
    tex = stage_input.tex;
    nor = stage_input.nor;
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.texCoord = texCoord;
    stage_output.wposition = wposition;
    stage_output.wnormal = wnormal;
    stage_output.eyeDir = eyeDir;
    return stage_output;
}
