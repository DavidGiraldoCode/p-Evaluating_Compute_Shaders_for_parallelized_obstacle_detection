using UnityEngine;
/// <summary>
/// The sensing Ray enables the boid to detect voxels infront and query 
/// their state: VOID or FULL, meaning, detect if the voxel is an obstacle
/// </summary>
public class SensingRay : MonoBehaviour
{
    private Vector3 _origin = new Vector3(0.0f, 0.0f, 0.0f);
    private Vector3 _direction = new Vector3(0.0f, 0.0f, 0.0f);
    private Vector3 _firstIntersection;
    private Vector3 _intersectionPoint;
    private Vector3 _newIntersection;
    private float _reach = 8.0f;

    //Properties

    public Vector3 Origin { get => _origin; set => _origin = value; }
    public Vector3 Direction { get => _direction; set => _direction = value; }
    public float Reach { get => _reach; }


    private void Awake()
    {

    }

    #region Custom API
    // // Default constructor
    // public SensingRay()
    // {
    // }

    // // Parameterized constructor
    // public SensingRay(Vector3 origin, Vector3 direction)
    // {
    // }

    // Method to get the intersection point
    public Vector3 GetIntersectionPoint(Vector3 origin, Vector3 direction)
    {
        return default;
    }

    // Method to get the first intersection point
    public Vector3 GetFirstIntersectionPoint(Vector3 origin, Vector3 direction)
    {
        return default;
    }

    // Method to get the intersection point
    public Vector3 GetIntersectionPoint()
    {
        return default;
    }

    // Method to check for intersection with a plane
    public bool IntersectPlane(Vector3 planeNormal, Vector3 planePosition, Vector3 rayOrigin, Vector3 rayDirection, out float lambdaT)
    {
        lambdaT = default;
        return default;
    }

    #endregion Custom API
}
