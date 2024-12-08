Shader "David/Participating_Media/Volm_ActiveRecallTest_241206"
{
 /*    Properties
    {
       _BaseColor
        _Center
        _Radius
        _Scattering
        _Absorption
        _Asymmetry
        _Scale
        _Frequency
    }
    SubShader
    {
        Tags 
        { 
            // Opaque and URP
        }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // HLSL core and light
            // Noise and Intersection definitions

            CBUFFER_START(UnityMaterial)
            float4 _BaseColor;
            float4 _Center;
            float _Radius;
            float _Scattering;
            float _Absorption;
            float _Asymmetry;
            float _Scale;
            float _Frequency;
            CBUFFER_END
            
            Light light;
            float transmission;
            float extinction;
            float density;
            float d = 2;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD0;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.positionWS = // passing word spcae positions
                o.uv = v.uv;
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //define the color
                float4 volumeColor = float4(0.0, 0.0, 0.0, 0.0);
                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);

                //define the ray
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.positionWS - rayOrigin);
                float t0, t1;

                //define the participating media variables
                transmittance = 0;
                density = 0;
                extinction = _Absorption + _Scattering;

                //Intersection test
                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                    float distance = t0 - t1;
                    float step_size = 0.2; //%
                    uint num_steps = ceil(distance / step_size);
                    step_size = distance / (float)num_steps;

                    light = GetMainLight;
                    float4 light_color = float4(light.color.xyz, 1.0);
                    float3 light_direction = light.direction;
                    //Ray martch in side the volume

                    for(uint n = 0; n < num_steps; ++n)
                    {
                        float t_sample = t0 * step_size * (n + 0.5);
                        float3 samplePosition = rayOrigin + rayDirection * t_sample;

                        density = 0.1; // Sample density

                        sample_attenuation = exp(-step_size * extinction * density);
                        transmittance *= sample_attenuation;
                        
                        // Shoot a ray toward the light to get the distance and exit point
                        float l_t0, l_t1;
                        if(hit(samplePosition, light_direction, _Center, _Radius, l_t0, l_t1))
                        {
                           float distance_to_light = l_t1 - l_t0;
                           float light_step = 0.2;
                           uint  num_light_steps = ceil(distance_to_light / light_step);
                           float light_step = distance_to_light / (float) num_light_steps;

                           float transmittance_to_light;
                           //define tau

                           for(uint nl = 0; nl < num_light_steps; ++nl)
                           {
                                float3 lt_sample = l_t0 * light_step * (nl + 0.5);
                                float3 light_sample_position = samplePosition + light_direction * lt_sample;
                                // Compute angle for phase function
                                //accumulate transmittance
                                light_attenuation = exp(-l_t1, _Scattering, extinction, density, phase())
                           }

                        }
                        // Stop when transmittance passes a threshold
                        if(transmittance < 0.01)
                        {
                            //Stop
                            // Russian rullet
                        }

                        volumeColor = _BaseColor * (1 - transmittance) * accumulatedColor;
                    }

                    return volumeColor;

                }

            }
            ENDHLSL
        }
    }*/
}
