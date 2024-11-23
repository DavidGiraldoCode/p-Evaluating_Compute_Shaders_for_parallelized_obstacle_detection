Shader "David/Participating_Media/RaySphere_Hit"
{
    Properties
    {
        _CameraDepthTexture ("Depth Texture", 2D) = "white" {}
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _FrontFace ("FrontFacexture", Float) = 1
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 2.0)) = 0.5
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

            bool hit(float3 origin, float3 direction, float3 sphere_center, float radius, out float t0, out float t1)
            {   
                float3 sc_to_orign = origin.xyz - sphere_center.xyz;
                float a = dot(direction, direction);
                float h = dot(direction, sc_to_orign);
                float c = dot(sc_to_orign, sc_to_orign) - (radius * radius);

                float discriminant = (h * h) - (a * c);
                float sqr = sqrt(discriminant);

                t0 = ((h * -1.0) - sqr) / a;
                t1 = ((h * -1.0) + sqr) / a;
                
                if(discriminant < 0.0) return false;

                return true;
            }

            CBUFFER_START(UnityMaterial)
            float4  _BaseColor;
            float4  _Center;
            float   _Radius;
            CBUFFER_END

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);


            struct mesh_data
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS   : TEXCOORD2;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS   : TEXCOORD2;
                float4 screenPos : SV_POSITION;
            };

            v2f vert (mesh_data v)
            {
                v2f o;
                //o.vertex = TransformObjectToHClip(v.vertex);
                // ref https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl
                o.positionWS = mul(UNITY_MATRIX_M, v.vertex).xyz;
                o.uv = v.uv;
                o.screenPos = TransformObjectToHClip(v.vertex);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float3 ray_origin     = GetCameraPositionWS();
                float3 ray_direction  = normalize(i.positionWS - ray_origin).xyz;
                float t0, t1;

                float4 col;
                
                // Convert screen space position (screenPos) to normalized device coordinates (NDC)
                float2 uv = i.screenPos.xy / i.screenPos.w;  // Convert to viewport space (0 to 1 range)
                uv = uv * 0.5 + 0.5;  // Adjust to [0,1] range, accounting for potential negative values

                // Get depth from the depth texture
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;

                // Reconstruct the clip space position
                float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);

                // Convert clip space to view space using the inverse projection matrix
                float4 viewPos = mul(UNITY_MATRIX_I_P, clipPos);
                viewPos /= viewPos.w;  // Homogeneous divide to convert to 3D space

                // Convert from view space to world space using the inverse view matrix
                float4 worldPos = mul(UNITY_MATRIX_I_V, viewPos);

                // Calculate ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.positionWS - rayOrigin);//normalize(worldPos.xyz - rayOrigin);

                // For visualization
                //return float4(rayDirection * 0.5 + 0.5, 1.0);

                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    float3 point0 = rayOrigin + rayDirection * t0;
                    float3 point1 = rayOrigin + rayDirection * t1;
                    float d = length(point1 - point0);
                    float normDistance = d / (2.0 * _Radius);
                    col = float4(normDistance, normDistance, normDistance, 1.0);
                }
                else
                {
                    col = float4(0,0,0,0);;
                }

                return col;
            }
            ENDHLSL
        }
    }
}
