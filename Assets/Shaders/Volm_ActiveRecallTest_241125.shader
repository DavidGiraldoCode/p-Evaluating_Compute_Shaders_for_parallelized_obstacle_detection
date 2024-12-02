Shader "David/Participating_Media/Volm_ActiveRecallTest_241125"
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
        //Cull Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            //include HLSL core and lights
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
            #include "RaySphereIntersection.hlsl" // Include the external HLSL file

            #pragma vertex vert
            #pragma fragment frag

            
            
            //Buffer
            CBUFFER_START(UnityMaterial)
            float4      _BaseColor;
            float4      _Center;
            float       _Radius;
            float       _Absorption;
            float       _Scattering;
            float       _Asymmetry;
            CBUFFER_END

            Light light;
            float extinction;

            struct appdata
            {
                float4 vertex       : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex       : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                //o.positionWS = mult(UNITY_MATRIX_W, v.vertex.xyz); //! mul( UNITY_MATRIX_M  ).xyz
                o.positionWS = mul(UNITY_MATRIX_M, v.vertex).xyz;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Step 0: Define the final color of the volume and the accumulated color
                float4 volumeColor      = float4(0.0, 0.0, 0.0, 0.0); //! alpha must be 0 
                float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0); //! alpha must be 0 
                //? Light color
                //float4 lightColor       = float4(light.color.xyz, 1.0); //! you only need the light once a hit is recorded

                /* Step 1:
                Difine the trasmittence; the amount of light that is absorpted by the 
                participatin medium as the light is travels trough the volume towards the eye.
                Value [0,1], 0 is complety absorpted, and 1 is complete passes throught
                ? Almost forgot
                    - Extictiog coheficiente
                    - Desity
                */
                float transmittance = 1.0;
                extinction = _Absorption + _Scattering;
                float density = 1.0;
                /* Step 2:
                Define a bounding volume that contains the participating media, and implement the
                interserction test to get when the viewing ray enters and leaves the volume.
                */
                float3 rayOrigin    = _WorldSpaceCameraPos; // 2.1. Define the origin of the ray
                float3 rayDirection =  normalize(i.positionWS.xyz - rayOrigin); // 2.2. Dfien the normalized direction passing trough the fragment
                float t0, t1; // 2.3. Entry and exit points along the ray
                
                // Step 3: Perform intersection test to the bounding volumen
                if(hit(rayOrigin, rayDirection, _Center, _Radius, t0, t1))
                {
                
                    /*
                    Compute how much light is coming to the viewing ray.
                    Forward ray-marching
                    Get the distance that the light travels, and subdive that distance by the number of steps
                    */

                    float distance  = t1 - t0;
                    float step_size = 0.1; // dX
                    float steps     = ceil(distance / step_size); // distance / step_size; //! missing ceil( )
                    step_size       = distance / (float) steps; //! missing (float)
                    //? Do not recall this step
                    
                    //! Get light, light_direction, light_color
                    //* Fixing:
                    light = GetMainLight();
                    float4 lightColor       = float4(light.color.xyz, 1.0); 
                    float3 lightDirection   = light.direction;
                    //* -----

                    for(uint n = 0; n < steps; ++n)
                    {
                        // Step : Define the position of the sample
                        float sample_t = t0 + step_size * ((float) n + 0.5); // or * rand() to jitter
                        float3 sample_positon = rayOrigin + rayDirection * sample_t; // This is X
                        
                        //! Sample density from scalar field - procedural

                        // Compute the transmittance of this sample, using Beer's law
                        float sample_transmittence = exp(-step_size * extinction * density);
                        transmittance *= sample_transmittence;

                        // Step: Compute the transmitance of the light that reaches this sample
                        //float3 lightDirection = light.direction; //! Not needed here
                        float l_t0, l_t1;

                        if(hit(sample_positon, lightDirection, _Center, _Radius, l_t0, l_t1))
                        {
                            //! Compute theta of light direction and viewing ray for phase function

                            // Compute how much light has been absorpt
                            float light_attenuation = exp(-l_t1 * extinction * density); 

                            // Gather the light //! Add phase function
                            accumulatedColor += lightColor * light_attenuation * _Scattering * density * step_size;
                        }

                        //! Early exit once transmittance reaches a threshold

                    }

                    //volumeColor += (1.0 - transmittance) * accumulatedColor; //! = T + accumulatedColor;
                    //* Fixing:
                    volumeColor = _BaseColor * (1.0 - transmittance) + accumulatedColor;
                    //*
                }

                //volumeColor = float4(rayDirection.xyz, 1);

                return volumeColor;
            }
            ENDHLSL
        }
    }
}
