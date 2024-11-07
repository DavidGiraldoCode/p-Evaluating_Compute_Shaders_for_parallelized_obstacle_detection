Shader "Hidden/VisualizeVoxelsURP" {
    SubShader {
        Tags
        { 
            "Queue" = "Transparent"
            "RenderType"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vp
            #pragma fragment fp

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            StructuredBuffer<int> _SmokeVoxels;
            StructuredBuffer<int> _StaticVoxels;
            //StructuredBuffer<int> _Voxels; // New to visualized queries in world space

            float3 _BoundsExtent;
            uint3 _VoxelResolution;
            float _VoxelSize;
            int _MaxFillSteps, _DebugSmokeVoxels, _DebugStaticVoxels, _DebugEdgeVoxels;

            struct VertexData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 hashCol : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            float hash(uint n) {
                // Integer hash function for randomness
                n = (n << 13U) ^ n;
                n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
                return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
            }
            // Where instanceID comes from?
            v2f vp(VertexData v, uint instanceID : SV_INSTANCEID) {
                v2f o;

                // Map the 1D index of the instance, to 3D. This position are in "Object space"
                uint x = instanceID % (_VoxelResolution.x);
                uint y = (instanceID / _VoxelResolution.x) % _VoxelResolution.y;
                uint z = instanceID / (_VoxelResolution.x * _VoxelResolution.y);

                // Convert voxel to world space and then to clip space
                // The aabbOffset only considers the XZ, since the voxel is already at Y=0
                float3 aabbOffset = float3(_BoundsExtent.x , 0.0 , _BoundsExtent.z);
                float3 worldPos = ( v.vertex.xyz + float3(x, y, z)) * _VoxelSize // Translate each vertex by the size of the voxel
                                    + (_VoxelSize * 0.5f)
                                    - aabbOffset;

                o.pos = TransformWorldToHClip(worldPos);

                // Apply voxel visibility based on debug settings
                if (_DebugSmokeVoxels)
                    o.pos *= saturate(_SmokeVoxels[instanceID]); //_SmokeVoxels
                if (_DebugStaticVoxels)
                    o.pos *= _StaticVoxels[instanceID]; //_StaticVoxels

                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = worldPos;
                o.hashCol = float3(hash(instanceID), hash(instanceID * 2), hash(instanceID * 3));

                return o;
            }

            float4 fp(v2f i) : SV_TARGET {
                // Calculate lighting based on URP's main light
                float3 lightDir = GetMainLight().direction;
                float3 lightColor = GetMainLight().color.rgb;
                float ndotl = saturate(dot(i.worldNormal, lightDir)) * 0.5f + 0.5f;
                ndotl *= ndotl;

                // return float4(i.hashCol * lightColor * ndotl, 0.1f); // original
                return float4(float4(0.8, 0, 0, 1) * lightColor * ndotl, 0.2f);
            }

            ENDHLSL
        }
    }
}

