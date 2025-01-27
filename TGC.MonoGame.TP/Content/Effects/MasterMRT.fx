﻿#if OPENGL
#define SV_POSITION POSITION
#define VS_SHADERMODEL vs_3_0
#define PS_SHADERMODEL ps_3_0
#else
#define VS_SHADERMODEL vs_4_0_level_9_1
#define PS_SHADERMODEL ps_4_0_level_9_1
#endif

float Time;
float ApplyShieldEffect;
float3 ShieldColor;

matrix World;
matrix WorldViewProjection;
matrix InverseTransposeWorld;
matrix LightViewProjection;
matrix InvertViewProjection;

float3 CameraPosition;
float3 LightDirection;
float3 Color;
float3 LightColor;
float AddToFilter;

float SpecularIntensity;
float SpecularPower;
float3 AmbientLightColor;
float AmbientLightIntensity;

float modulatedEpsilon = 0.000041200182749889791011810302734375;
float maxEpsilon = 0.000023200045689009130001068115234375;
//float modulatedEpsilon = 0.00001200182749889791011810302734375;
//float maxEpsilon = 0.000000200045689009130001068115234375;


texture Texture;
sampler2D textureSampler = sampler_state
{
    Texture = (Texture);
    MagFilter = Linear;
    MinFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};
texture ModelNormal;
sampler2D normalSampler = sampler_state
{
    Texture = (ModelNormal);
    MagFilter = Linear;
    MinFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

texture ShadowMap;
float2 ShadowMapSize;
sampler shadowSampler = sampler_state
{
    Texture = (ShadowMap);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = POINT;
    MinFilter = POINT;
    Mipfilter = POINT;
};
technique TexturedDraw
{
    pass Pass0
    {
        VertexShader = compile VS_SHADERMODEL DrawVS();
        PixelShader = compile PS_SHADERMODEL TexturedDrawPS();
    }
};
technique BasicColorDraw
{
    pass Pass0
    {
        VertexShader = compile VS_SHADERMODEL DrawVS();
        PixelShader = compile PS_SHADERMODEL BasicColorPS();
    }
};
technique TrenchDraw
{
    pass Pass0
    {
        VertexShader = compile VS_SHADERMODEL DrawVS();
        PixelShader = compile PS_SHADERMODEL TrenchPS();
    }
};


struct VSIDraw
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL0;
    float3 Binormal : BINORMAL0;
    float3 Tangent : TANGENT0;
    float2 TextureCoordinates : TEXCOORD0;
};

struct VSODraw
{
    float4 Position : SV_POSITION;
    float2 TextureCoordinates : TEXCOORD0;
    float4 Normal : TEXCOORD1;
    float3 DirToCamera : TEXCOORD2;
    float3x3 WorldToTangentSpace : TEXCOORD3;
    float3 OmniLightColor : TEXCOORD6;
    float4 WorldPosition : TEXCOORD7;
    float4 LightSpacePosition : TEXCOORD8;
};

struct PSOMRT
{
    float4 Color : COLOR0;
    float4 Normal : COLOR1;
    float4 DirToCam : COLOR2;
    float4 Bloom : COLOR3;
};



//float ApplyLightEffect;

float3 OmniLightsPos[20];
float3 OmniLightsColor[20];
int OmniLightsCount;
float OmniLightsRadiusMin;
float OmniLightsRadiusMax;

VSODraw DrawVS(in VSIDraw input)
{
    VSODraw output = (VSODraw) 0;

    float4 pos = mul(input.Position, WorldViewProjection);
    output.Position = pos;
    output.TextureCoordinates = input.TextureCoordinates;
    
    float4 worldPos = mul(input.Position, World);
    output.DirToCamera = normalize(float4(CameraPosition, 1.0) - worldPos).xyz;
    
    output.WorldToTangentSpace[0] = mul(normalize(input.Tangent), (float3x3) World);
    output.WorldToTangentSpace[1] = mul(normalize(input.Binormal), (float3x3) World);
    output.WorldToTangentSpace[2] = mul(normalize(input.Normal), (float3x3) World);
    
    float4 normal = float4(normalize(input.Normal), 1.0);
    
    output.Normal = normal;
    output.WorldPosition = worldPos;
    output.OmniLightColor = float3(0, 0, 0);
    
    output.LightSpacePosition = mul(worldPos, LightViewProjection);
    
    return output;
}
PSOMRT BasicColorPS(VSODraw input)
{
    PSOMRT output = (PSOMRT) 0;
    
    output.Color = float4(Color,0);

    output.Normal = float4(0, 0, 0, 0);
    output.DirToCam = float4(0, 0, 0, 0);
    
    output.Bloom = float4(Color * AddToFilter, 0.0);
    
    return output;
}

float getShadow(VSODraw input, float3 normal)
{
    float3 lightSpacePosition = input.LightSpacePosition.xyz / input.LightSpacePosition.w;
    float2 shadowMapTextureCoordinates = 0.5 * lightSpacePosition.xy + float2(0.5, 0.5);
    shadowMapTextureCoordinates.y = 1.0f - shadowMapTextureCoordinates.y;
	
    if (shadowMapTextureCoordinates.x < 0.0 || shadowMapTextureCoordinates.x > 1.0
        || shadowMapTextureCoordinates.y < 0.0 || shadowMapTextureCoordinates.y > 1.0)
        return -1.0;
    
    float inclinationBias = max(modulatedEpsilon * (1.0 - dot(normal, LightDirection)), maxEpsilon);
	
    float shadowMapDepth = 1 - tex2D(shadowSampler, shadowMapTextureCoordinates).r + inclinationBias;
	
	// Compare the shadowmap with the REAL depth of this fragment
	// in light space
    
    
    return 0.25 * step(shadowMapDepth, lightSpacePosition.z);
}
PSOMRT TexturedDrawPS(VSODraw input)
{
    PSOMRT output = (PSOMRT) 0;
    
    float4 texColor = tex2D(textureSampler, input.TextureCoordinates);
    
    //sample normal from texture and convert 
    float3 fromNormalMap = (2.0 * tex2D(normalSampler, input.TextureCoordinates) - 1.0).xyz;
    float3 normal = normalize(mul(fromNormalMap, input.WorldToTangentSpace));
    output.Normal = float4(normal, 1);
 
    
    //if(ApplyShieldEffect == 1.0)
    //    if (input.TextureCoordinates.x < ran.GetRandomFloat(0,1))    
    //        texColor.rgb = ShieldColor.rgb;
            
    
    output.Color = texColor;
    float shadowFilter = getShadow(input, normal);
    
    if (shadowFilter >= 0)
        output.Color -= shadowFilter;
    
    output.DirToCam = float4(0.5 * (input.DirToCamera + 1), 1); //
    
    output.Bloom = float4(0,0,0, 1);
    
    output.Color.a = input.OmniLightColor.r;
    output.Normal.a = input.OmniLightColor.g;
    output.DirToCam.a = input.OmniLightColor.b;
    
    return output;
}

PSOMRT TrenchPS(VSODraw input)
{
    PSOMRT output = (PSOMRT) 0;
    
    float3 worldNormal = mul(input.Normal, InverseTransposeWorld).xyz;
    
    output.Normal = float4(0.5 * (worldNormal + 1.0), 1);
   
    float nDotLeft = dot(worldNormal, float3(-1.0, 0, 0.0));
    
    if (nDotLeft >= 0 && nDotLeft <= 0.10)
        output.Color = float4(Color * 0.8, 1);
    else
        output.Color = float4(Color, 1);
    
    float shadowFilter = getShadow(input, worldNormal);
    if(shadowFilter >= 0)
        output.Color -= shadowFilter;
    
    output.Bloom = float4(0,0,0, 1);
    
    output.DirToCam = float4(0.5 * (input.DirToCamera + 1), 1);
    
    output.Color.a = input.OmniLightColor.r;
    output.Normal.a = input.OmniLightColor.g;
    output.DirToCam.a = input.OmniLightColor.b;
    
    return output;
}

/* SKYBOX */
texture SkyBoxTexture;
samplerCUBE SkyBoxSampler = sampler_state
{
    texture = (SkyBoxTexture);
    magfilter = LINEAR;
    minfilter = LINEAR;
    mipfilter = LINEAR;
    AddressU = Mirror;
    AddressV = Mirror;
};

struct VSIsky
{
    float4 Position : POSITION0;
};
struct VSOsky
{
    float4 Position : SV_POSITION;
    float3 TextureCoordinates : TEXCOORD0;
};
technique Skybox
{
    pass Pass1
    {
        VertexShader = compile VS_SHADERMODEL SkyboxVS();
        PixelShader = compile PS_SHADERMODEL SkyboxPS();
    }
}
VSOsky SkyboxVS(VSIsky input)
{
    VSOsky output = (VSOsky) 0;

    output.Position = mul(input.Position, WorldViewProjection);
    float4 VertexPosition = mul(input.Position, World);
    output.TextureCoordinates = VertexPosition.xyz - CameraPosition;

    return output;
}
PSOMRT SkyboxPS(VSOsky input)
{
    PSOMRT output = (PSOMRT) 0;
    
    output.Color = float4(texCUBE(SkyBoxSampler, normalize(input.TextureCoordinates)).rgb, 1);
    output.Bloom = float4(0, 0, 0, 0.0);
    output.DirToCam = float4(0, 0, 0, 0);
    output.Normal= float4(0, 0, 1, 0);
    
    return output;
}


struct VSIdepth
{
    float4 Position : POSITION0;
};
struct VSOdepth
{
    float4 Position : SV_POSITION;
    float4 ScreenPos : TEXCOORD0;
};
technique DepthPass
{
    pass Pass1
    {
        VertexShader = compile VS_SHADERMODEL DepthVS();
        PixelShader = compile PS_SHADERMODEL DepthPS();
    }
}
VSOdepth DepthVS(VSIdepth input)
{
    VSOdepth output = (VSOdepth) 0;
    
    float4 worldPosition = mul(input.Position, World);
    output.Position = mul(worldPosition, LightViewProjection);
    output.ScreenPos = mul(worldPosition, LightViewProjection);

    return output;
}
float4 DepthPS(VSOdepth input) : COLOR
{
    float depth = 1 - (input.ScreenPos.z / input.ScreenPos.w);
    return float4(depth, depth, depth, 1.0);
}

/* DIRECTIONAL LIGHT CALC AND INT */

static const int kernel_r = 6;
static const int kernel_size = 13;
static const float Kernel[kernel_size] =
{
    0.002216, 0.008764, 0.026995, 0.064759, 0.120985, 0.176033, 0.199471, 0.176033, 0.120985, 0.064759, 0.026995, 0.008764, 0.002216,
};
float2 screenSize;

texture ColorMap;
sampler colorSampler = sampler_state
{
    Texture = (ColorMap);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    Mipfilter = LINEAR;
};
texture DirToCamMap;
sampler dirToCamSampler = sampler_state
{
    Texture = (DirToCamMap);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = POINT;
    MinFilter = POINT;
    Mipfilter = POINT;
};

texture NormalMap;
sampler normalMapSampler = sampler_state
{
    Texture = (NormalMap);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = POINT;
    MinFilter = POINT;
    Mipfilter = POINT;
};
texture BloomFilter;
sampler bloomFilterSampler = sampler_state
{
    Texture = (BloomFilter);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = POINT;
    MinFilter = POINT;
    Mipfilter = POINT;
};

struct DLightVSI
{
    float3 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
};

struct DLightVSO
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
};
struct DLightPSO
{
    float4 Scene : COLOR0;
    float4 BlurH: COLOR1;
    float4 BlurV : COLOR2;
};

DLightVSO DLightVS(DLightVSI input)
{
    DLightVSO output;
    output.Position = float4(input.Position, 1);
    output.TexCoord = input.TexCoord;
    return output;
}


DLightPSO DLightPS(DLightVSO input) : COLOR0
{
    DLightPSO output = (DLightPSO) 0;
    
    float4 bloomFilter = tex2D(bloomFilterSampler, input.TexCoord);
    float applyLighting = bloomFilter.w;
    
    //get original pixel color
    float4 colorMap = tex2D(colorSampler, input.TexCoord);
    
    float3 texColor = colorMap.rgb;
        
    if (applyLighting == 0.0)
        output.Scene = float4(texColor, 1);
    else
    {
    
        //get normal data from the normalMap
        float4 normalData = tex2D(normalMapSampler, input.TexCoord);
        //tranform normal back into [-1,1] range
        float3 normal = 2.0f * normalData.xyz - 1.0;
    
        //get dir to cam map
        float4 dirToCamMap = tex2D(dirToCamSampler, input.TexCoord);
    
        //float3 OmniLight = float3(colorMap.a, normalData.a, dirToCamMap.a);
    
        //surface-to-light vector
        float3 lightVector = -normalize(LightDirection);

        //compute diffuse light (directional)
        float NdL = max(0, dot(normal, lightVector));
        float3 directionalLight = NdL * LightColor;
    
 
        float3 diffuseLight = directionalLight;
    
        //reflexion vector
        float3 reflectionVector = normalize(reflect(-lightVector, normal));
        //convert back to [-1, 1]
        float3 directionToCamera = 2.0 * dirToCamMap.xyz - 1.0;
    
        //compute specular light
        float specularLight = SpecularIntensity * pow(saturate(dot(reflectionVector, directionToCamera)), SpecularPower);

    
        
        //return float4(AmbientLightColor * AmbientLightIntensity + diffuseLight, specularLight);
    
        //integrate
        float3 ambientDiffuse = AmbientLightColor * AmbientLightIntensity + diffuseLight;
        output.Scene = float4((texColor * ambientDiffuse + specularLight), 1);
    }
    
    //Calculate horizontal and vertical blur for the bloom filter
    float4 hColor = float4(0, 0, 0, 1);
    float4 vColor = float4(0, 0, 0, 1);
    
    for (int i = 0; i < kernel_size; i++)
    {
        float2 scaledTextureCoordinatesH = input.TexCoord + float2((float) (i - kernel_r) / screenSize.x, 0);
        float2 scaledTextureCoordinatesV = input.TexCoord + float2(0, (float) (i - kernel_r) / screenSize.y);
        hColor += tex2D(bloomFilterSampler, scaledTextureCoordinatesH) * Kernel[i];
        vColor += tex2D(bloomFilterSampler, scaledTextureCoordinatesV) * Kernel[i];
    }
    
    output.BlurH = hColor;
    output.BlurV = vColor;
    
    return output;
}

texture LightMap;
sampler lightSampler = sampler_state
{
    Texture = (LightMap);
    AddressU = CLAMP;
    AddressV = CLAMP;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    Mipfilter = LINEAR;
};

float4 IntLightPS(DLightVSO input) : COLOR
{
    float3 diffuseColor = tex2D(colorSampler, input.TexCoord).rgb;
    float4 light = tex2D(lightSampler, input.TexCoord);
    float3 diffuseLight = light.rgb;
    float specularLight = light.a;
    return float4((diffuseColor * diffuseLight + specularLight), 1);
}

technique CalcIntLightBlur
{
    pass Pass0
    {
        VertexShader = compile VS_SHADERMODEL DLightVS();
        PixelShader = compile PS_SHADERMODEL DLightPS();
    }
}

technique IntegrateLight
{
    pass Pass0
    {
        VertexShader = compile VS_SHADERMODEL DLightVS();
        PixelShader = compile PS_SHADERMODEL IntLightPS();
    }
}