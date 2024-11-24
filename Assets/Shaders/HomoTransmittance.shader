Shader "David/Participating_Media/HomoTransmittance"
{
    Properties
    {
        _CameraDepthTexture ("Depth Texture", 2D) = "white" {}
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 4.0)) = 0.5
        _Absorption ("Absorption coefficient", Range(0.0, 1.0)) = 0.5
        _Scattering ("Scattering coefficient", Range(0.0, 1.0)) = 0.5
        _Density ("Volume density", Range(0.0, 5.0)) = 0.5
        _Asymmetry ("P(x) Asymmetry", Range(-1.0, 1.0)) = 0.0
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
            //https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            #pragma vertex vert
            #pragma fragment frag

            #include "RaySphereIntersection.hlsl" // Include the external HLSL file
            #define M_PI 3.141592

            CBUFFER_START(UnityMaterial)
            float4  _BaseColor;
            float4  _Center;
            float   _Radius;
            float   _Absorption; // Control how opaque the volume is
            float   _Scattering;
            float   _Density; // Scale the contribution of the extintion coefficient
            float   _Asymmetry;
            CBUFFER_END

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            Light light;
            float extinction;

            struct mesh_data
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS   : TEXCOORD2;
                float4 screenPos : SV_POSITION;
                float3 viewPos : TEXCOORD3;
            };

            // the Henyey-Greenstein phase function by Scratchapixel's Jean-Colas Prunier 
            float phase(const float g, const float cos_theta)
            {
                float denom = 1 + g * g - 2 * g * cos_theta;
                return 1 / (4 * M_PI) * (1 - g * g) / (denom * sqrt(denom));
            }

            v2f vert (mesh_data v)
            {
                v2f o;
                o.screenPos = TransformObjectToHClip(v.vertex);
                // ref https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl
                o.positionWS = mul(UNITY_MATRIX_M, v.vertex).xyz;
                o.uv = v.uv;
                o.viewPos = GetVertexPositionInputs(v.vertex.xyz).positionVS;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 volumeColor = float4(0.0, 0.0, 0.0, 1.0);
                float transmittance = 1.0; // initialize transparency to 1

                // Calculate ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.positionWS - rayOrigin);
                float t0, t1;

                extinction = _Absorption + _Scattering;

                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    

                    float3 point0 = rayOrigin + rayDirection * t0;
                    float3 point1 = rayOrigin + rayDirection * t1;
                    float distance = t1 - t0;//length(point1 - point0);

                    float step_size = 0.2;

                    int num_steps = ceil(distance / step_size);
                    step_size = distance / (float)num_steps;

                    // Beer's Law
                    //float transmittance = exp(-distance * _Absorption);
                    //float normDistance = d / (2.0 * _Radius);

                    light                   = GetMainLight();
                    float4 lightColor       = float4(light.color.xyz, 1.0);
                    float3 lightDirection   = light.direction;
                    float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);

                    for(uint n = 0; n < num_steps; ++n)
                    {
                        float lt0, lt1;

                        float t = t0 + (step_size * (n + 0.5));

                        float3 sample_position = rayOrigin + rayDirection * t;
                        
                        // current sample transparency, Beer's Law
                        // represents how much of the light is being absorbed by the sample
                        float sample_attenuation = exp(-step_size * extinction * _Density);

                        // attenuate volume's global transparency by current sample transmission value
                        transmittance *= sample_attenuation;

                        if(hit(sample_position, lightDirection, _Center, _Radius, lt0, lt1))
                        {
                            //float3 t1_position = sample_position + lightDirection * lt1;
                            //float distaceToLight = length(t1_position - sample_position);// lt1 - lt0;
                            float cos_theta = dot(rayDirection, lightDirection); // Cos theta for the phase function
                            // in-scattering Li(x)
                            float light_attenuation = exp(-lt1 * extinction * _Density); // exp(-lt1 * _Absorption); // exp(-distaceToLight * _Absorption); //
                            //light contribution due to in-scattering is proportional to the scattering coefficient
                            accumulatedColor += lightColor * light_attenuation * phase(_Asymmetry, cos_theta) * _Scattering * _Density * step_size;

                        }
                        // finally attenuate the result by sample transparency
                        //accumulatedColor *= sample_attenuation;
                        if (transmittance < 1e-3)
                            break;
                    }

                    
                    //col = float4(0,0,0,0) * transmittance + ((1 - transmittance) * _BaseColor);
                    //transparency = clamp(transparency, 0.0, 1.0);

                    volumeColor = float4(0,0,0,1) * (1.0 - transmittance) + accumulatedColor;
                }
                else
                {
                    volumeColor = float4(0,0,0,0);
                }

                return volumeColor;
                //return float4(i.viewPos.xyz, 1.0);
                //return float4(v.xyz, 1.0);
                //return float4(i.positionWS.xyz, 1.0);

            }
            ENDHLSL
        }
    }
}
