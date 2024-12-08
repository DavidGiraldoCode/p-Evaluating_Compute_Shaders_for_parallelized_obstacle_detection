Shader "David/Participating_Media/Volm_ActiveRecallTest_241202"
{
    Properties
    {
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 4.0)) = 0.5
        _Absorption ("Absorption coefficient", Range(0.0, 1.0)) = 0.5
        _Scattering ("Scattering coefficient", Range(0.0, 1.0)) = 0.5
        _Asymmetry ("Phase(x) Asymmetry", Range(-1.0, 1.0)) = 0.0
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

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Add HLSL library
            //include HLSL core and lights
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
            #include "RaySphereIntersection.hlsl" // Include the external HLSL file

            #define PI 3.1416
            #define d  // Russian roullete

            CBUFFER_START(UnityMaterial)
            float4  _BaseColor;
            float4  _Center;
            float   _Radius;
            float   _Absorption;
            float   _Scattering;
            float   _Asymmetry;
            CBUFFER_END

            Light light;
            float transmittance;
            float extinction;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                //! Missing positions in WS
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                //! Missing passing position in WS
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 volumeColor      = float4(0.0,0.0,0.0,0.0);
                float4 accumulatedColor = float4(0.0,0.0,0.0,0.0);

                transmittance = 1;
                extinction = _Absorption + _Scattering;
                //! Missin density

                // Define the ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                //! i.positionWS
                float3 rayDirection = normalize(i.vertex - rayOrigin);
                float t0, t1;

                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    float distance  = (t1 - t0);
                    float step_size = 0.2;
                    float steps =  ceil(distance / step_size);
                    step_size = distance / (float) steps; //! always add (float)

                    //! Missing getting the light
                    //! light = GetMainLight();

                    for(uint i = 0; i < steps; ++i)
                    {
                        float t_sample = t0 + step_size * ((float)i + 0.5); //! Recall the (float)
                        float3 sample_position = rayOrigin + rayDirection * t_sample;

                        float sample_attenuation = exp(-step_size * extinction ); //! * density
                        transmission *= sample_attenuation;

                        float3 light_direction = light.direction;
                        float4 light_color     = float4(light.color.xyz, 1.0);
                        float  light_attenuation;
                        float l_t0, l_t1;

                        if(hit(sample_position, light_direction, _Center, _Radius, l_t0, l_t1))
                        {
                            float distance_to_light = l_t1 - l_t0;
                            // float theta = ; //! Missing

                            //! attenuation is only needs -> -distance_to_light * extinction * density
                            light_attenuation = exp(-distance_to_light * extinction * phase(theta) * step_size * _Scattering);
                        }
                        //! You only accumulate when there is a hit, so this goes inside the if
                        accumulatedColor += light_color * light_attenuation; //! * _Scattering * density * step_size * phase();
                    }

                    //! Missing early exit once transmittance reaches threshold

                }
                else
                {
                    volumeColor = float4(0.0,0.0,0.0,0.0);
                }

                //! fortgot threshold

                volumeColor  = _BaseColor * (1.0 - transmittance) + accumulatedColor * transmittance;

                return volumeColor;
            }
            ENDHLSL
        }
    }
}
