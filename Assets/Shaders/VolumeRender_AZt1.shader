Shader "David/Participating_Media/VolumeRender_AZt1"
{
    Properties
    {
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Bitmap ("Texture", 2D) = "white" {}
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 5.0)) = 2.5
    }
    SubShader
    {
        Tags 
        { 
            "Queue" = "Transparent"
            "RenderType"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 

            #pragma vertex vert
            #pragma fragment frag
            #define STEPS 64
            #define STEP_SIZE 0.01

            TEXTURE2D(_Bitmap);
            SAMPLER(sampler_Bitmap);
            
            CBUFFER_START(UnityMaterial)
            float4 _BaseColor;
            float4 _Bitmap_ST;
            float4 _Center;
            float _Radius;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 wPos : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 wPos : TEXCOORD1;
            };

            bool rayMartchHit( float3 pos, float3 dir, out float visibility)
            {
                float3 sample = pos; // Sample start at the positio of the fragment
                for( uint i = 0; i < STEPS; i ++)
                {
                    sample = sample + dir * (STEP_SIZE); // Moves along the direction of the ray by the step
                    
                    float3 centerToSample = sample - _Center;
                    float  sqrDist        = centerToSample.x * centerToSample.x + centerToSample.y * centerToSample.y + centerToSample.z * centerToSample.z;
                    float  sqrR           = (_Radius * _Radius);
                    if(sqrDist < sqrR)
                    {   
                        float radialAttenuation = (0.999 - (sqrDist / sqrR)) * 0.2;
                        visibility += radialAttenuation * radialAttenuation;
                        if(visibility > 1)
                        visibility = 1;
                        //return true;
                    }
                }
                return false;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.wPos = GetVertexPositionInputs(v.vertex.xyz).positionWS;
                o.uv = TRANSFORM_TEX(v.uv, _Bitmap);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 col = SAMPLE_TEXTURE2D(_Bitmap, sampler_Bitmap, i.uv);
                //return col;

                float3 cameraPosWS =  GetCameraPositionWS();
                float3 rayDir   = normalize(i.wPos - cameraPosWS);
                float3 rayOrigin = i.wPos.xyz;
                float visibility = 0;
                //if(!rayMartchHit(rayOrigin, rayDir, visibility))
                //    discard;
                rayMartchHit(rayOrigin, rayDir, visibility);
                return float4(1.0, 1.0, 1.0, visibility);  

                //return float4(rayDir.xyz, 1.0);
                //return float4(i.wPos.xyz, 1.0);
            }
            ENDHLSL
        }
    }
}
