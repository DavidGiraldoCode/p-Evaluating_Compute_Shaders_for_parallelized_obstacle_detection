using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RaySphereIntersection : MonoBehaviour
{
    private Ray _ray;
    private float t0, t1;
    [SerializeField] private float _scalar = 1.0f;

    private void Update()
    {
        _ray.origin = Camera.main.transform.position;
        _ray.direction = Camera.main.transform.forward;

        if(hit(_ray.origin, _ray.direction, new Vector3(0,0,0) , 0.5f, out t0, out t1))
        {
            Vector3 p0 = _ray.origin + _ray.direction * t0;
            Vector3 p1 = _ray.origin + _ray.direction * t1;

            Debug.DrawLine( p0, p1, Color.red);
        }

        // Visualizer
        Debug.DrawLine(_ray.origin, _ray.origin + _ray.direction * _scalar, Color.yellow);
    }

    private bool hit(Vector3 origin, Vector3 direction, Vector3 sphere_center, float radius, out float t0, out float t1)
    {
        Vector3 sc_to_orign = origin - sphere_center;
        float a = Vector3.Dot(direction, direction);
        float h = Vector3.Dot(direction, sc_to_orign);
        float c = Vector3.Dot(sc_to_orign, sc_to_orign) - (radius * radius);

        float discriminant = (h * h) - (a * c);
        //Debug.Log("discriminant: " + discriminant);
        float sqr = Mathf.Sqrt(discriminant);

        t0 = ((h * -1.0f) - sqr) / a;
        t1 = ((h * -1.0f) + sqr) / a;

        if (discriminant < 0)
            return false;

        return true;
    }
}
