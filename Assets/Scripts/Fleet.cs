using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(BoxCollider))]

/// <summary>
/// WIP description
/// Main entry point of this boids implementation
/// An UAV is an aircraft without a human pilot, crew, or passengers 
/// </summary>
public class Fleet : MonoBehaviour
{
    [Header("Instance to Render")]

    [Tooltip("Unmanned Aerial Vehicles (UAVs) is a set of aerial robots i.e., drones")]
    [SerializeField] private uint _numberOfUAV = 50;

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

    /*
    [SerializeField] private float _boundsForceFactor = 5.0f;


    #region Steering coefficients

    [Header("Cohesion behaviour")]
    [Tooltip("The coefficient to determine how close to each other the boids are")]
    [SerializeField] private float _cohesionForceFactor = 1;
    public float CohesionForceFactor { get => _cohesionForceFactor; set => _cohesionForceFactor = value; }
    [Tooltip("Distance threshold to include neighbours in the computation")]
    [SerializeField] private float _cohesionRadius = 3;
    public float CohesionRadius { get => _cohesionRadius; set => _cohesionRadius = value; }

    [Header("Separation behaviour")]
    [Tooltip("The coefficient to determine how separate to each other the boids are")]
    [SerializeField] private float _separationForceFactor = 1;
    public float SeparationForceFactor { get => _separationForceFactor; set => _separationForceFactor = value; }
    [SerializeField] private float _separationRadius = 2;
    public float SeparationRadius { get => _separationRadius; set => _separationRadius = value; }

    [Header("Alignment behaviour")]
    [Tooltip("The coefficient to determine how much other boids' direction influence")]
    [SerializeField] private float _alignmentForceFactor = 1;
    public float AlignmentForceFactor { get => _alignmentForceFactor; set => _alignmentForceFactor = value; }
    [SerializeField] private float m_alignmentRadius = 3;
    public float AlignmentRadius { get => m_alignmentRadius; set => m_alignmentRadius = value; }

    #endregion Steering coefficients

    #region Movement constrains

    [Header("Movement constrains")]
    [SerializeField] private float _maxSpeed = 8;
    public float MaxSpeed { get => _maxSpeed; set => _maxSpeed = value; }
    [SerializeField] private float _minSpeed;
    public float MinSpeed { get => _minSpeed; set => _minSpeed = value; }
    [SerializeField] private float _drag = 0.1f;
    public float Drag { get => _drag; set => _drag = value; }
    public float NeighborRadius
    {
        get { return Mathf.Max(m_alignmentRadius, Mathf.Max(_separationRadius, _cohesionRadius)); }
    }
    #endregion Movement constrains
    */
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
