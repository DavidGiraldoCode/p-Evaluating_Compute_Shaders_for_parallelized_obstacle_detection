using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Voxelizer : MonoBehaviour
{
    #region Grid setup variables
    [Tooltip("This represents the width, height and depth of the bouding volumen")]
    public Vector3 boundsExtent = new Vector3(3, 3, 3);

    public float voxelSize = 0.25f;

    public GameObject objectsToVoxelize = null;

    [Range(0.0f, 2.0f)]
    public float intersectionBias = 1.0f;


    public Mesh debugMesh;

    public bool debugStaticVoxels = false;
    public bool debugSmokeVoxels = false;
    public bool debugEdgeVoxels = false;

    #endregion Grid setup variables

    public Vector3 maxRadius = new Vector3(1, 1, 1);

    [Range(0.01f, 5.0f)]
    public float growthSpeed = 1.0f;

    [Range(0, 128)]
    public int maxFillSteps = 16;

    public bool iterateFill = false;
    public bool constantFill = false;

    #region GPGPU buffers
    private ComputeBuffer staticVoxelsBuffer, smokeVoxelsBuffer, smokePingVoxelsBuffer, argsBuffer;
    private ComputeShader voxelizeCompute;
    private Material debugVoxelMaterial;
    private Bounds debugBounds;

    #endregion GPGPU buffers
    private int voxelsX, voxelsY, voxelsZ, totalVoxels;
    private float radius;
    private Vector3 smokeOrigin;

    #region Getters
    public ComputeBuffer GetSmokeVoxelBuffer()
    {
        return smokeVoxelsBuffer;
    }

    public Vector3 GetVoxelResolution()
    {
        return new Vector3(voxelsX, voxelsY, voxelsZ);
    }

    public Vector3 GetBoundsExtent()
    {
        return boundsExtent;
    }

    public float GetVoxelSize()
    {
        return voxelSize;
    }

    public Vector3 GetSmokeOrigin()
    {
        return smokeOrigin;
    }

    // public Vector3 GetSmokeRadius()
    // {
    //     return Vector3.Lerp(Vector3.zero, maxRadius, Easing(radius));
    // }

    // public float GetEasing()
    // {
    //     return Easing(radius);
    // }
    #endregion Getters

    private void OnEnable()
    {
        radius = 0.0f;
        // Loading resourses
        debugVoxelMaterial = new Material(Shader.Find("Hidden/VisualizeVoxelsURP")); // The shader had to be translate to URP
        // Use of the class Resources, which allow to create a folder in unity and add any file that we want to get access to in code.  
        // more here https://docs.unity3d.com/ScriptReference/Resources.html
        voxelizeCompute = (ComputeShader)Resources.Load("Voxelize");

        // Smart way to just move the bounding volumen from the center, to sit on the XZ plane
        Vector3 boundsSize = boundsExtent * 2;
        debugBounds = new Bounds(new Vector3(0, boundsExtent.y, 0), boundsSize);

        // Subdividing the bounds in each direction by the size of the voxel to get the total
        voxelsX = Mathf.CeilToInt(boundsSize.x / voxelSize);
        voxelsY = Mathf.CeilToInt(boundsSize.y / voxelSize);
        voxelsZ = Mathf.CeilToInt(boundsSize.z / voxelSize);
        totalVoxels = voxelsX * voxelsY * voxelsZ;

        // TODO study stride (the space we need in memory)
        // Memory allocation to store all the potential voxels that are going to be an obstacle
        staticVoxelsBuffer = new ComputeBuffer(totalVoxels, 4);

        // Clear buffer
        voxelizeCompute.SetBuffer(0, "_Voxels", staticVoxelsBuffer);
        
        // Sends the compute shader to the GPU
        // 128 is the number of thread per thread group, which detemine roughly how many voxels
        // are being process by one processor
        voxelizeCompute.Dispatch(0, Mathf.CeilToInt(totalVoxels / 128.0f), 1, 1);

        // Precompute voxelized representation of the scene
        ComputeBuffer verticesBuffer, trianglesBuffer;

        // For each mesh on the list of meshes to voxelize do
        foreach (Transform child in objectsToVoxelize.GetComponentsInChildren<Transform>())
        {
            MeshFilter meshFilter = child.gameObject.GetComponent<MeshFilter>();

            if (!meshFilter) continue; // Next child
            // Function only for reading mesh data and not for writing, id the mesh that all instances shared
            Mesh sharedMesh = meshFilter.sharedMesh;

            // Creates two buffers, one to store all the vertices and one to store all the striangles of the mesh
            // 3 * sizeof(float) becase a vertex is a vector (float3), contains data for x,y and z
            verticesBuffer = new ComputeBuffer(sharedMesh.vertexCount, 3 * sizeof(float));
            verticesBuffer.SetData(sharedMesh.vertices); // Sending a buffer with vectors in 3D
            trianglesBuffer = new ComputeBuffer(sharedMesh.triangles.Length, sizeof(int));
            trianglesBuffer.SetData(sharedMesh.triangles);

            // Setting variables on the compute shader, recall the GPU knows nothing about WTF is going on on CPU world
            voxelizeCompute.SetBuffer(1, "_StaticVoxels", staticVoxelsBuffer);
            voxelizeCompute.SetBuffer(1, "_MeshVertices", verticesBuffer);
            voxelizeCompute.SetBuffer(1, "_MeshTriangleIndices", trianglesBuffer);
            voxelizeCompute.SetVector("_VoxelResolution", new Vector3(voxelsX, voxelsY, voxelsZ));
            voxelizeCompute.SetVector("_BoundsExtent", boundsExtent);
            voxelizeCompute.SetMatrix("_MeshLocalToWorld", child.localToWorldMatrix); // Sends the matrix that accounts fro transformations
            voxelizeCompute.SetInt("_VoxelCount", totalVoxels);
            voxelizeCompute.SetInt("_TriangleCount", sharedMesh.triangles.Length);
            voxelizeCompute.SetFloat("_VoxelSize", voxelSize);
            voxelizeCompute.SetFloat("_IntersectionBias", intersectionBias); //? Study

            // Sends the compute shader to the GPU
            // 128 is the number of thread per thread group, which detemine roughly how many voxels
            // are being process by one processor
            int threadGroupsX = Mathf.CeilToInt(totalVoxels / 128.0f);
            voxelizeCompute.Dispatch(1, threadGroupsX, 1, 1);

            // Deallocates the memory, utimetly this is called in the ~Destructor.
            verticesBuffer.Release();
            trianglesBuffer.Release();
        }

        // Memory allocation again to store all position voxel that can become smoke
        smokeVoxelsBuffer = new ComputeBuffer(totalVoxels, sizeof(int));
        smokePingVoxelsBuffer = new ComputeBuffer(totalVoxels, sizeof(int));

        // Clear buffers
        voxelizeCompute.SetBuffer(0, "_Voxels", smokeVoxelsBuffer);
        voxelizeCompute.Dispatch(0, Mathf.CeilToInt(totalVoxels / 128.0f), 1, 1);
        voxelizeCompute.SetBuffer(0, "_Voxels", smokePingVoxelsBuffer);
        voxelizeCompute.Dispatch(0, Mathf.CeilToInt(totalVoxels / 128.0f), 1, 1);

        // kernel CS_Seed
        voxelizeCompute.SetBuffer(2, "_SmokeVoxels", smokeVoxelsBuffer);

        // kernel CS_FillStep
        voxelizeCompute.SetBuffer(3, "_StaticVoxels", staticVoxelsBuffer);
        voxelizeCompute.SetBuffer(3, "_SmokeVoxels", smokeVoxelsBuffer);
        voxelizeCompute.SetBuffer(3, "_PingVoxels", smokePingVoxelsBuffer);

        // kernel CS_PingPong
        voxelizeCompute.SetBuffer(4, "_Voxels", smokeVoxelsBuffer);
        voxelizeCompute.SetBuffer(4, "_PingVoxels", smokePingVoxelsBuffer);
        voxelizeCompute.SetBuffer(4, "_StaticVoxels", staticVoxelsBuffer);

        // Debug instancing args
        argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        args[0] = (uint)debugMesh.GetIndexCount(0);
        args[1] = (uint)totalVoxels;
        args[2] = (uint)debugMesh.GetIndexStart(0);
        args[3] = (uint)debugMesh.GetBaseVertex(0);
        argsBuffer.SetData(args);

    }

    private void Update()
    {
        if (debugStaticVoxels || debugSmokeVoxels || debugEdgeVoxels) {
            debugVoxelMaterial.SetBuffer("_StaticVoxels", staticVoxelsBuffer);
            debugVoxelMaterial.SetBuffer("_SmokeVoxels", smokeVoxelsBuffer);
            debugVoxelMaterial.SetVector("_VoxelResolution", new Vector3(voxelsX, voxelsY, voxelsZ));
            debugVoxelMaterial.SetVector("_BoundsExtent", boundsExtent);
            debugVoxelMaterial.SetFloat("_VoxelSize", voxelSize);
            debugVoxelMaterial.SetInt("_MaxFillSteps", maxFillSteps);
            debugVoxelMaterial.SetInt("_DebugSmokeVoxels", debugSmokeVoxels ? 1 : 0);
            debugVoxelMaterial.SetInt("_DebugStaticVoxels", debugStaticVoxels ? 1 : 0);

            // https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html
            //! This function is now obsolete. 
            Graphics.DrawMeshInstancedIndirect(debugMesh, 0, debugVoxelMaterial, debugBounds, argsBuffer);
            // TODO Use Graphics.RenderMeshIndirect instead. Draws the same mesh multiple times using GPU instancing.
        }
    }

    void OnDisable()
    {
        staticVoxelsBuffer.Release();
        smokeVoxelsBuffer.Release();
        smokePingVoxelsBuffer.Release();
        argsBuffer.Release();
    }


    /// <summary>
    /// Helper function to visualize the bounding volume
    /// </summary>
    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireCube(debugBounds.center, debugBounds.extents * 2);
    }
}
