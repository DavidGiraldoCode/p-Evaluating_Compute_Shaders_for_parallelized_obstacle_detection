using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 🚧 Description WIP 🚧
/// Main entry point of this boids implementation. It uses a BoxCollider as bounding volume to define the are where the boids can move
/// </summary>
[RequireComponent(typeof(BoxCollider))]
public class Fleet : MonoBehaviour
{
    [Header("Instance to Render")]

    [Tooltip("Unmanned Aerial Vehicles (UAVs) is a set of aerial robots i.e., drones")]
    [SerializeField] private uint _numberOfUAV = 50; //An UAV is an aircraft without a human pilot, crew, or passengers 

    [Tooltip("this will be passed as reference to instantiate the Prefab")]
    [SerializeField] private Boid _uavPrefab = null;

    [Tooltip("How spread the random spawn locations inside the sphere are going to be")]
    [SerializeField] private float _spawnRadius = 10.0f;

    [Tooltip("The center of the sphere that spawns the boids")]
    [SerializeField] private GameObject _spawnPointPrefab;
    [Tooltip("The bounding volume where the fleet can fly")]
    [SerializeField] private BoxCollider _flyingBoundingVolume = null;
    [Tooltip("Defines how the fleet will behave, the SO saves the settings after play mode")]
    [SerializeField] private SteeringSettings _steeringSetting;
    public SteeringSettings Behaviour { get => _steeringSetting; }

    public BoidManager BoidManager { get; set; }

    //TODO review
    public IEnumerable<Boid> SpawnBirds()
    {
        for (int i = 0; i < _numberOfUAV; ++i)
        {
            Vector3 spawnPoint = _spawnPointPrefab != null ? _spawnPointPrefab.transform.position + _spawnRadius * Random.insideUnitSphere : transform.position + _spawnRadius * Random.insideUnitSphere;

            for (int j = 0; j < 3; ++j)
                spawnPoint[j] = Mathf.Clamp(spawnPoint[j], _flyingBoundingVolume.bounds.min[j], _flyingBoundingVolume.bounds.max[j]);

            Boid boid = Instantiate(_uavPrefab, spawnPoint, _uavPrefab.transform.rotation) as Boid; //! IMPORTANT as Boid
            boid.Position = spawnPoint;
            boid.Velocity = Random.insideUnitSphere;
            boid.UAVFleet = this; //Add the instance of THIS flock
            boid.transform.parent = this.transform;
            //Returns the IEnumerable objects
            // yield return Provides the next boid in the iteration
            //https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/yield#code-try-1
            yield return boid;
        }
    }
    void Awake()
    {
        _flyingBoundingVolume = GetComponent<BoxCollider>();

        if(!_flyingBoundingVolume)
            throw new System.NullReferenceException("The fleet is missing the flying bounding volumen (BoxCollider)");
    }

    // Update is called once per frame
    void Update()
    {

    }

    //TODO double check this math
    public Vector3 GetForceFromBounds(Boid boid)
    {
        Vector3 force = new Vector3();
        Vector3 centerToPos = boid.Position - transform.position;
        Vector3 minDiff = centerToPos + _flyingBoundingVolume.size * 0.5f;
        Vector3 maxDiff = centerToPos - _flyingBoundingVolume.size * 0.5f;
        float friction = 0.0f;

        for (int i = 0; i < 3; ++i)
        {
            if (minDiff[i] < 0)
                force[i] = minDiff[i];
            else if (maxDiff[i] > 0)
                force[i] = maxDiff[i];
            else
                force[i] = 0;

            friction += Mathf.Abs(force[i]);
        }

        force += 0.1f * friction * boid.Velocity;
        return -_steeringSetting.BoundsForceFactor * force;
    }

}
