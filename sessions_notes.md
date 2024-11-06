# Sessions
Details descriptions, thoughs and snippets.

## Sessions 2024-11-05: Setting up environment
- Setup the basic Boids algorithm
- The code documentation in WIP

<div style="display: flex; justify-content: space-around; align-items: center;">
    <img src="Assets/Art/Images/first_setup_boids_moving.gif" alt="First Setup Boids Moving" style="max-width: 45%;">
    <img src="Assets/Art/Images/wth_ray.gif" alt="With Ray" style="max-width: 45%;">
</div>


### Next steps
- Review voxel grid from Acerola's work, evaluate adding it vs own implementation
- Add the sensing Ray to the boids
- Add the Ray-Voxel intersection test

Here is the corrected version of your README report:

---

## Session 2024-11-06: Evaluate How to Incorporate a Voxelizer

### Questions to be Answered:
- What’s the entry point?
- How do the C# script and compute shader communicate?
- How to create just one voxel using this method?
- How to detect if the voxel has intersected geometry?
- How to detect if the voxel is an obstacle in this method?

### Steps in the Algorithm
``` bash
In C#
1. Create a bounding volume at the center of the scene, and define its width, height, and depth.
2. Define the size of a voxel and compute the resolution along the width, height, and depth axes.
3. Gather all the geometry to voxelize.
4. For each mesh do:
    allocate memory (create the buffers) to store the triangles and vertices count.
5. Set all the variables in the Compute Shader that the GPU will need to reconstruct the scene, for instance the LocalToWorldMatrix
6. Dispatch the voxelization kernel to the GPU for each of the meshes we want to voxelize.
    Distribute the load between the threads

In the GPU:
1. Create the AABB representing a voxel. It extends beyond the size of the voxel by an _IntersectionBias.
2. Build each triangle of the given mesh and apply the transformation matrix.
3. Once ready, run the intersection test between the AABB and the triangle.
4. If true, flag the triangle as 1.
5. Repeat this until all the triangles are tested against the AABB of a voxel.
```

### Doubts and Bugs
- The voxelized representation of the mesh seems to be constructed, or at least visualized, without the proper transformation. Something might be off when passing the matrix, or the deprecated graphics method `DrawMeshInstancedIndirect` could be causing trouble.
![alt text](Assets/Art/Images/off_voxelization.png)

### Next Steps
- Fix unwanted behavior from the matrix.
- Query the position of a voxel using the voxelized representation; return 1 if it is an obstacle.

**Reference**
- [1] Acerola, "I Tried Recreating Counter Strike 2’s Smoke Grenades," (2023). Accessed: Nov. 06, 2024. [Online Video]. Available: https://www.youtube.com/watch?v=ryB8hT5TMSg