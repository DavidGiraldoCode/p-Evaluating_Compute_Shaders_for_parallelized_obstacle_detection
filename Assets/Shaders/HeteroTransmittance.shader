Shader "David/Participating_Media/HeteroTransmittance"
{
    Properties
    {
        _CameraDepthTexture ("Depth Texture", 2D) = "white" {}
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 4.0)) = 0.5
        _Absorption ("Absorption coefficient", Range(0.0, 1.0)) = 0.5
        _Scattering ("Scattering coefficient", Range(0.0, 1.0)) = 0.5
        //_Density ("Volume density", Range(0.0, 5.0)) = 0.5
        _Asymmetry ("P(x) Asymmetry", Range(-1.0, 1.0)) = 0.0
        _SmokeScale ("SmokeScale", Range(0.0, 10.0)) = 5.0
        _Frequency ("Frequency", Range(0.0, 80.0)) = 40.0
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
        //Cull Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
            //https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            #pragma vertex vert
            #pragma fragment frag

            #include "RaySphereIntersection.hlsl" // Include the external HLSL file for the ray-sphere intersection
            #include "PerlinNoise.hlsl"
            #define M_PI 3.141592   // PI Value for the phase function
            #define THRESHOLD 1e-3 // Transmittance threshold to stop marching

            CBUFFER_START(UnityMaterial)
            float4  _BaseColor;
            float4  _Center;
            float   _Radius;
            float   _Absorption;  // absorption coefficient, the probability of the light being asorpted
            float   _Scattering;  // in-scattering, the probability of light being scatter into the viewing ray
            //float   _Density; // Scale the contribution of the extintion coefficient
            float   _Asymmetry;
            float   _Frequency;
            float   _SmokeScale;
            CBUFFER_END

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            Light light;
            float transmittance;
            float extinction; // absorption + scattering
            float density;    // How much particle there are in a sample
            uint  d = 2; // russian roulette "probability"

            struct mesh_data
            {
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD2;
                float4 vertex       : SV_POSITION;
            };

            // the Henyey-Greenstein phase function by Scratchapixel's Jean-Colas Prunier 
            //! STUDY
            float phase(const float g, const float cos_theta)
            {
                float denom = 1 + g * g - 2 * g * cos_theta;
                return 1 / (4 * M_PI) * (1 - g * g) / (denom * sqrt(denom));
            }

            float evalDensity(float3 p)
            { 
                float f = _Time * _Frequency;
                return _SmokeScale * (noise(     0.1 * _SmokeScale * p.x - f,
                                                       _SmokeScale * p.y - (f * 1.0), 
                                                 0.5 * _SmokeScale * p.z + (f * 2.0)));// + 1.0) * 0.5;
                //float freq = 1;
                //return (1 + noise(p.x * freq, p.y * freq, p.z * freq)) * 0.5;
            }

            //! STUDY
            float smoothstep(float lo, float hi, float x)
            {
                float t = clamp((x - lo) / (hi - lo), 0.f, 1.f);
                return t * t * (3.0 - (2.0 * t));
            }

            v2f vert (mesh_data v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.positionWS = mul(UNITY_MATRIX_M, v.vertex).xyz;
                o.uv = v.uv;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 1. Define the color of the participating medium
                float4 volumeColor      = float4(0.0, 0.0, 0.0, 0.0);
                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);

                // 2. Define the transmittance, which gives how much radiance gets absorpted 
                // by the participating medium as the light travels through it
                transmittance = 1.0; // initialize transparency to 1
                extinction = _Absorption + _Scattering;
                density = 0.0; // override density to then be changed by noise function
                const float step_size = 0.1;

                // 3. Calculate viewing-ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.positionWS - rayOrigin); // The position of the fragment in world space
                float t0, t1;

                // 4. Compute the intersection test with the bounding volume
                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    
                    // 5. Define the setting for the fixed-step rey marching
                    float distance = t1 - t0;                       // 5.1 Calculate how much the light needs to travel alogn the viewing ray
                    //float step_size = 0.1;                          
                    int num_steps = ceil(distance / step_size);
                    //step_size = distance / (float) num_steps;

                    float stride = distance / (float) num_steps;

                    // 6. Get the light data: color and direction
                    light                   = GetMainLight();
                    float4 lightColor       = float4(light.color.xyz, 1.0);
                    float3 lightDirection   = light.direction;

                    //float f = 0.0;
                    //f = _Time * _Frequency;
                    //f += sin(_Time * 5) * 20.0 + 5;// sin(_Time );

                    // 7. Start marching
                    for(uint n = 0; n < num_steps; ++n)
                    {
                        
                        // 8. Compute the sample position along the ray
                        //float t = t0 + (step_size * ((float)n + hash(n))); //Jittering the Sample Positions
                        float sample_t = t0 + (stride * ((float) n + 0.5)); // 8.1 Compute the t value for the sample n
                        //float sample_t = t0 + (step_size * ( hash((float)n + 0.5))); // 8.1 Compute the t value for the sample n
                        
                        float3 sample_position = rayOrigin + rayDirection * sample_t;
                        
                        // Density is changed by samplying the procedurally generated density field
                        //density = 4.0 * (noise(abs(sample_position.x + f), abs(sample_position.y - f), abs(sample_position.z + f)) + 1.0) / 2.0;
                        //density = (noise(sample_position.x ,sample_position.y , sample_position.z ) + 1.0) / 2.0;
                        
                        /*
                        density = _SmokeScale * (noise(     abs(_SmokeScale * sample_position.x + (f * 2.0)),
                                                            abs(_SmokeScale * sample_position.y - f), 
                                                            abs(_SmokeScale * sample_position.z + f)) + 1.0) * 0.5;
                        
                        density = _SmokeScale * (noise(     0.1 * _SmokeScale * sample_position.x - f,
                                                            _SmokeScale * sample_position.y - (f * 1.0), 
                                                            0.5 * _SmokeScale * sample_position.z + (f * 2.0)) + 1.0) * 0.5;
                        */
                        density = clamp(evalDensity(sample_position), 0.0, 1.0);

                        // current sample transparency, Beer's Law, represents how much of the light is being absorbed by the sample
                        float sample_attenuation = exp(-step_size * extinction * density);
                        
                        // attenuate volume's global transparency by current sample transmission value
                        transmittance *= sample_attenuation;
                        
                        float lt0, lt1;
                        
                        if(hit(sample_position, lightDirection, _Center, _Radius, lt0, lt1))
                        {
                            uint light_steps = ceil((lt1 - lt0)/ step_size);
                            float light_stride = (lt1 - lt0) / (float) light_steps;
                            float tau = 0.0;

                            for(uint nl = 0; nl < light_steps; ++nl)
                            {
                                float t_light = light_stride * (nl + 0.5);
                                float3 light_sample_position =  sample_position + lightDirection * t_light;
                                tau += evalDensity(light_sample_position);
                            }

                            float light_ray_attenuation = exp(-tau * light_stride * extinction);

                            // Cos theta for the phase functio
                            float cos_theta = dot(rayDirection, lightDirection);

                            // in-scattering Li(x), lt1 is distance from the sample to the light
                            //float light_attenuation = exp(-lt1 * extinction * density);
                            
                            //light contribution due to in-scattering is proportional to the scattering coefficient
                            accumulatedColor +=   lightColor 
                                                * light_ray_attenuation 
                                                * phase(_Asymmetry, cos_theta)
                                                * _Scattering 
                                                * density 
                                                * stride
                                                * transmittance;

                        }
                        
                        if (transmittance < THRESHOLD)
                        {
                            if (hash(n) > 1.0 / d) // we stop here
                                break;
                            else
                                transmittance *= d; // we continue but compensate
                        }
                    }

                    volumeColor =  _BaseColor * (1.0 - transmittance) + accumulatedColor;
                }

                return volumeColor;

            }
            ENDHLSL
        }
    }
}
