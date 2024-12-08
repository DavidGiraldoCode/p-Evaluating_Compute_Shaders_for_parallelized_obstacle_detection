Shader "David/Participating_Media/PartiMedia_procedural"
{
    Properties
    {
        _BaseColor ("Base color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Center ("Center", Vector) = (0.0, 0.0, 0.0, 0.0)
        _Radius ("Radius", Range(0.1, 4.0)) = 0.5
        _Absorption ("Absorption coefficient", Range(0.0, 1.0)) = 0.5
        _Scattering ("Scattering coefficient", Range(0.0, 1.0)) = 0.5
        _Asymmetry ("P(x) Asymmetry", Range(-1.0, 1.0)) = 0.0
        _SmokeScale ("SmokeScale", Range(0.0, 10.0)) = 5.0
        _Frequency ("Frequency", Range(0.0, 80.0)) = 40.0
        _SampleXYZOffSet ("Sample XYZ Offset", Vector) = (1.0, 1.0, 1.0, 0.0)
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
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
            #include "RaySphereIntersection.hlsl" // Include the external HLSL file for the ray-sphere intersection
            #include "PerlinNoise.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            #define M_PI 3.141592   // PI Value for the phase function
            #define THRESHOLD 1e-3  // Transmittance threshold to stop marching

            CBUFFER_START(UnityMaterial)
            float4  _BaseColor;
            float4  _Center;
            float   _Radius;
            float   _Absorption;  // absorption coefficient, the probability of the light being asorpted
            float   _Scattering;  // in-scattering, the probability of light being scatter into the viewing ray
            float   _Asymmetry;   // The direction the light bounces off given the phase function
            float   _Frequency;
            float   _SmokeScale;
            float4  _SampleXYZOffSet;
            CBUFFER_END

            // Pariticipation Media Attributes
            
            float transmittance;    // How much light manage to reach the eye 0: none, 1: all
            float extinction;       // absorption + scattering
            float density;          // How much particle there are in a sample
            uint  d = 2;            // russian roulette "probability"

            float smoothstep(float lo, float hi, float x)
            {
                float t = clamp((x - lo) / (hi - lo), 0.0, 1.0);
                return t * t * (3.0 - (2.0 * t));
            }

            float evalDensity(float3 p)
            { 
                float f = _Frequency ;//_Time * _Frequency;
                // float densityValue = _SmokeScale * (noise(  _SmokeScale * p.x,
                //                                             _SmokeScale * p.y, 
                //                                             _SmokeScale * p.z ));// + 1.0) * 0.5;

                float densityAbsValue = (noise( abs( p.x * f),
                                             abs( p.y * f), 
                                             abs( p.z * f)) + 1.0) * 0.5;
                
                float densityValue = (noise( p.x * f,
                                             p.y * f, 
                                             p.z * f) + 1.0) * 0.5;
                
                return densityValue;//clamp(densityValue, 0.0, 1.0);
                                                 //float freq = 0.1;
                //return (1 + noise(p.x * freq, p.y * freq, p.z * freq)) * 0.5;
            }

            float evalDensityFalloff(float3 sample_pos, float3 sphere_center, float sphere_radius)
            {
                
                float3 vp = sample_pos.xyz - sphere_center.xyz;
                float3 vp_xform;
                float theta = M_PI * _Time * 20.0;
                vp_xform.x =  cos(theta) * vp.x + sin(theta) * vp.z;
                vp_xform.y =  vp.y;
                vp_xform.z = -sin(theta) * vp.x + cos(theta) * vp.z;
                
                float f = _Frequency ;
                // float densityValue = (noise(    0.1 * vp_xform.x * f,
                //                                 vp_xform.y * f, 
                //                                 0.5 * vp_xform.z * f) + 1.0) * 0.5;

                float densityValueScaled = _SmokeScale * (noise(     
                    _SampleXYZOffSet.x * _SmokeScale * vp_xform.x + f,
                    _SampleXYZOffSet.y * _SmokeScale * vp_xform.y, 
                    _SampleXYZOffSet.z * _SmokeScale * vp_xform.z + f));
                                              
                float densityValue = clamp(densityValueScaled, 0.0, 1.0);

                float dist = min(1.0, length(vp.xyz) / sphere_radius);
                float falloff = smoothstep(0.6, 1, dist); // smooth transition from 0 to 1 as distance goes from 0.1 to 1
                return densityValue * (1 - falloff);
            }

            // The Henyey-Greenstein phase function
            float phaseHG(float3 view_dir, float3 light_dir, float g)
            {
                float cos_theta = view_dir * light_dir;
                return 1 / (4 * M_PI) * (1 - g * g) / pow(1 + g * g - 2 * g * cos_theta, 1.5);
            }

            //
            struct appdata
            {
                float4 vertex       : POSITION;
                float3 positionWS   : TEXCOORD1;
            };

            struct v2f
            {
                float4 vertex       : SV_POSITION;
                float3 positionWS   : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex        = TransformObjectToHClip(v.vertex.xyz); // Positions in Clip space
                o.positionWS    = mul(UNITY_MATRIX_M, v.vertex).xyz;    // Positions in world space
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Define the color fo the volume
                float4 volumeColor      = float4(0.0, 0.0, 0.0, 0.0); //float4(_BaseColor.rgb, 0.0);
                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);

                // Define the Ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.positionWS.xyz - rayOrigin);
                float t0, t1;

                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    transmittance = 1.0; // All light pases through
                    extinction = _Absorption + _Scattering; // Extinction cohefficient
                    density = 0.0;
                    //Define the light ray
                    Light light = GetMainLight();
                    float3 lightDirection = normalize(light.direction);
                    float4 lightColor     = float4(light.color.xyz, 1.0);

                    //Compute the transmittance at that view ray
                    //Normalized distance, How much the light needs to travel a long the viewing ray
                    //float distance = t1 - t0;
                    float3 p0 = rayOrigin + rayDirection * t0;
                    float3 p1 = rayOrigin + rayDirection * t1;
                    float distance = length(p1 - p0); 
                    //volumeColor += _Scattering;

                    // Compute In-Scattering contributions; the light that bounces in the direction of the viewing ray
                    float stepSize = distance * 0.05;
                    uint numSteps = ceil(distance / stepSize);
                    float stride = distance / (float) numSteps;

                    for(uint n = 0; n < numSteps; ++n)
                    {
                        // Define the Raiman Sum dx
                        // The position t of the sample along the viewing ray
                        float t = t0 * stride * (n + 0.5);
                        //float t = t0 * stride * ((float)n + hash(n*n)); //Jittering the Sample Positions
                        float3 samplePosition = rayOrigin + rayDirection * t;
                        density = evalDensityFalloff(samplePosition, _Center, _Radius);

                        float sampleTransmittance = exp(-stride * extinction * density);
                        transmittance *= sampleTransmittance;

                        
                        float l_t0, l_t1;

                        if(hit(samplePosition, lightDirection, _Center, _Radius, l_t0, l_t1))
                        {
                            //float lightTransmittance = exp(-l_t1 * extinction); // Li(x) * dx
                            // Define Raiman Sum ld to gather the light transmittance and density
                            //float distanceToLight = l_t0 - l_t1; // Normalized

                            float lp1 = samplePosition + lightDirection * l_t1;
                            float distanceToLight = length(lp1 - samplePosition); 

                            float l_stepSize = distanceToLight * 0.1;
                            uint  numLightSteps = ceil(distanceToLight / l_stepSize);
                            float lightStride = distanceToLight / (float) numLightSteps;
                            float tau = 0;

                            for(uint nl = 0; nl < numLightSteps; ++nl)
                            {
                                float l_t = lightStride * (nl + 0.5);
                                float3 lightSamplePosition = samplePosition + lightDirection * l_t;
                                tau += evalDensityFalloff(lightSamplePosition, _Center, _Radius);
                                
                            }
                            
                            float lightRayAttenuation = exp(-lightStride * tau * extinction);

                            accumulatedColor += lightColor 
                                        * lightRayAttenuation // Li(x,w)
                                        * transmittance
                                        * phaseHG(-rayDirection, lightDirection, _Asymmetry)
                                        * stride //dx
                                        * _Scattering // 
                                        * density; // 

                            //volumeColor += lightTransmittance * stride * _Scattering;

                        }
                        //Russian roulette
                        if (transmittance < THRESHOLD) 
                        {
                            if (hash(n) > 1.0 / d)
                                break;
                            else
                                transmittance *= d;
                        }

                    }

                    volumeColor = _BaseColor * (1.0 - transmittance) + accumulatedColor;
                }
                
                return volumeColor;
            }
            ENDHLSL
        }
    }
}
