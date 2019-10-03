Shader "CH's/OIT Transparent"
{
    Properties
    {
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Specular ("Specular Color", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(1, 256)) = 128
        _Cutoff ("Shadow alpha cutoff", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
        // Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}

        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            // Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase
            #pragma multi_compile OIT_Editor OIT_Runtime OIT_OFF

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            #pragma target 5.0

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                SHADOW_COORDS(5)
                float3 worldRefl : TEXCOORD6;
            };

            float4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _OIT_Depth;
            float _Cutoff;
            float4 _Specular;
            float _Gloss;

            struct FragmentAndLinkBuffer_STRUCT
            {
                float4 pixelColor;
                float depth;
                uint next;
            };

            RWStructuredBuffer<FragmentAndLinkBuffer_STRUCT> FLBuffer : register(u1);
            RWByteAddressBuffer StartOffsetBuffer : register(u2);

            inline float Dither8x8Bayer( uint2 pos )
            {
                const float dither[ 64 ] = {
                        1, 49, 13, 61,  4, 52, 16, 64,
                    33, 17, 45, 29, 36, 20, 48, 32,
                        9, 57,  5, 53, 12, 60,  8, 56,
                    41, 25, 37, 21, 44, 28, 40, 24,
                        3, 51, 15, 63,  2, 50, 14, 62,
                    35, 19, 47, 31, 34, 18, 46, 30,
                    11, 59,  7, 55, 10, 58,  6, 54,
                    43, 27, 39, 23, 42, 26, 38, 22};
                int r = fmod(pos.y,8) * 8 + fmod(pos.x,8);
                return dither[r] / 64; // same # of instructions as pre-dividing due to compiler magic
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.pos);
                o.screenPos = ComputeScreenPos(o.pos);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                TRANSFER_SHADOW(o);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
                o.worldRefl = reflect(-worldViewDir, o.worldNormal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
#if defined (OIT_OFF)
                // sample the texture
                fixed4 tex = tex2D(_MainTex, i.uv);
                // 兰伯特
                float3 worldNormal = normalize(i.worldNormal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float NdotL = max(0,dot(worldNormal,lightDir));
                // 高光
                float3 spec = max(0,dot(normalize(normalize(UnityWorldSpaceViewDir(i.worldPos))+lightDir),worldNormal));
                spec = pow(spec, _Gloss);
                // 获取天空盒颜色
                float3 ambient = ShadeSH9(half4(i.worldNormal,1));
                // 阴影
                float shadow = SHADOW_ATTENUATION(i);
                // 最终颜色
                float4 finalColor = float4(tex.rgb*(ambient+_LightColor0*NdotL*shadow)*_Color.rgb + _LightColor0*spec*shadow*_Specular,tex.a*_Color.a);
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return finalColor;
#elif defined (OIT_Editor)
                // sample the texture
                fixed4 tex = tex2D(_MainTex, i.uv);
                // 兰伯特
                float3 worldNormal = normalize(i.worldNormal);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float NdotL = max(0,dot(worldNormal,lightDir));
                // 高光
                float3 spec = max(0,dot(normalize(normalize(UnityWorldSpaceViewDir(i.worldPos))+lightDir),worldNormal));
                spec = pow(spec, _Gloss);
                // 获取天空盒颜色
                float3 ambient = ShadeSH9(half4(i.worldNormal,1));
                // 阴影
                float shadow = SHADOW_ATTENUATION(i);
                // 最终颜色
                float4 finalColor = float4(tex.rgb*(ambient+_LightColor0*NdotL*shadow)*_Color.rgb + _LightColor0*spec*shadow*_Specular,tex.a*_Color.a);
                // 镂空
                uint2 screenPos = i.screenPos.xy/i.screenPos.w*_ScreenParams.xy;
                float dither = step(Dither8x8Bayer(screenPos),finalColor.a);
                clip(dither-_Cutoff);
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return float4(finalColor.rgb,1);
#elif defined (OIT_Runtime)
                float depth = DecodeFloatRGBA(tex2D(_OIT_Depth,i.screenPos.xy/i.screenPos.w));
                float z = i.screenPos.z/i.screenPos.w;
                if (depth < z){
                    // sample the texture
                    float4 tex = tex2D(_MainTex, i.uv);
                    // 兰伯特
                    float3 worldNormal = normalize(i.worldNormal);
                    float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                    float NdotL = max(0,dot(worldNormal,lightDir));
                    // 高光
                    float3 spec = max(0,dot(normalize(normalize(UnityWorldSpaceViewDir(i.worldPos))+lightDir),worldNormal));
                    spec = pow(spec, _Gloss);
                    // 获取天空盒颜色
                    float3 ambient = ShadeSH9(half4(i.worldNormal,1));
                    // 阴影
                    float shadow = SHADOW_ATTENUATION(i);
                    // 最终颜色
                    float4 finalColor = float4(tex.rgb*(ambient+_LightColor0*NdotL*shadow)*_Color.rgb + _LightColor0*spec*shadow*_Specular,tex.a*_Color.a);

                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, finalColor);

                    uint uPixelCount = FLBuffer.IncrementCounter();
                    uint2 screenPos = i.screenPos.xy/i.screenPos.w*_ScreenParams.xy;
                    uint uStartOffsetAddress = 4 * (_ScreenParams.x * screenPos.y + screenPos.x);
                    uint uOldStartOffset;
                    StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

                    FragmentAndLinkBuffer_STRUCT Element;
                    Element.pixelColor = finalColor;
                    Element.depth = z;
                    Element.next = uOldStartOffset;
                    FLBuffer[uPixelCount] = Element;
                }
                discard;
                return 0;
#endif
            }
            ENDCG
        }
        UsePass "Legacy Shaders/Transparent/Cutout/VertexLit/Caster"
    }
}
