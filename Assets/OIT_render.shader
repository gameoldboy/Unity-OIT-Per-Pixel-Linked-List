Shader "Hidden/OIT_Rendering"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #pragma target 5.0

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.screenPos=ComputeScreenPos(o.vertex);
                return o;
            }

            sampler2D _MainTex;

            struct FragmentAndLinkBuffer_STRUCT
            {
                float4 pixelColor;
                float depth;
                uint next;
            };

            RWStructuredBuffer<FragmentAndLinkBuffer_STRUCT> FLBuffer : register(u1);
            RWByteAddressBuffer StartOffsetBuffer : register(u2);

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                uint2 screenPos = i.screenPos.xy/i.screenPos.w*_ScreenParams.xy;
                uint uStartOffsetAddress = 4 * (_ScreenParams.x * screenPos.y + screenPos.x);
                uint uOffset;
                StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, 0xFFFFFFFF, uOffset);

                static uint SortedPixels[128];

                int nNumPixels = 0;
                while(uOffset != 0xFFFFFFFF){
                    SortedPixels[nNumPixels++] = uOffset;
                    uOffset = (nNumPixels>=128) ? 0xFFFFFFFF : FLBuffer[uOffset].next;
                }

                for (int i = 0; i < nNumPixels - 1; i++)
				{
					for (int j = i + 1; j > 0; j--)
					{
						if (FLBuffer[SortedPixels[j - 1]].depth > FLBuffer[SortedPixels[j]].depth)
						{
							uint temp = SortedPixels[j - 1];
							SortedPixels[j - 1] = SortedPixels[j];
							SortedPixels[j] = temp;
						}
					}
				}

                for (int k = 0; k < nNumPixels; k++)
				{
					float4 vPixColor = FLBuffer[SortedPixels[k]].pixelColor;
					col = col * (1-vPixColor.a) + vPixColor*vPixColor.a;
				}

                return col;
                // return SortedPixels[0].pixelColor;
            }
            ENDCG
        }
    }
}
