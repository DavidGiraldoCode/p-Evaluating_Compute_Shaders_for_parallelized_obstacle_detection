using UnityEngine;

/// <summary>
/// Scriptable Object that defines the configuration of the fleet at compiletime, it can be change in runtime
/// </summary>
[CreateAssetMenu(fileName = "SteeringSetting", menuName = "Scriptable Objects/Settings/SteeringSettings", order = 0)]
public class SteeringSettings : ScriptableObject
{
    #region Steering coefficients

    [Header("Cohesion behaviour")]
    [Tooltip("The coefficient to determine how close to each other the boids are")]
    [SerializeField] private float _cohesionForceFactor = 1;
    [Tooltip("Distance threshold to include neighbours in the computation")]
    [SerializeField] private float _cohesionRadius = 3;

    [Header("Separation behaviour")]
    [Tooltip("The coefficient to determine how separate to each other the boids are")]
    [SerializeField] private float _separationForceFactor = 1;
    [SerializeField] private float _separationRadius = 2;

    [Header("Alignment behaviour")]
    [Tooltip("The coefficient to determine how much other boids' direction influence")]
    [SerializeField] private float _alignmentForceFactor = 1;
    [SerializeField] private float m_alignmentRadius = 3;

    // Accesors    
    public float CohesionForceFactor { get => _cohesionForceFactor; set => _cohesionForceFactor = value; }
    public float CohesionRadius { get => _cohesionRadius; set => _cohesionRadius = value; }
    public float AlignmentForceFactor { get => _alignmentForceFactor; set => _alignmentForceFactor = value; }
    public float AlignmentRadius { get => m_alignmentRadius; set => m_alignmentRadius = value; }
    public float SeparationForceFactor { get => _separationForceFactor; set => _separationForceFactor = value; }
    public float SeparationRadius { get => _separationRadius; set => _separationRadius = value; }

    #endregion Steering coefficients

    #region Movement constrains

    [Header("Movement constrains")]
    [SerializeField] private float _maxSpeed = 8;
    [SerializeField] private float _minSpeed;
    [SerializeField] private float _drag = 0.1f;
    [SerializeField] private float _boundsForceFactor = 5.0f;

    public float MinSpeed { get => _minSpeed; set => _minSpeed = value; }
    public float MaxSpeed { get => _maxSpeed; set => _maxSpeed = value; }
    public float Drag { get => _drag; set => _drag = value; }
    public float BoundsForceFactor { get => _boundsForceFactor; }
    public float NeighborRadius
    {
        get { return Mathf.Max(m_alignmentRadius, Mathf.Max(_separationRadius, _cohesionRadius)); }
    }
    #endregion Movement constrains
}
