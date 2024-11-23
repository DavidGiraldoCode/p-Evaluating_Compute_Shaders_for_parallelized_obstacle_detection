bool hit(   float3 origin, 
            float3 direction, 
            float3 sphere_center, 
            float radius, 
            out float t0, 
            out float t1)
{   
    float3 sc_to_orign = origin.xyz - sphere_center.xyz;
    float a = dot(direction, direction);
    float h = dot(direction, sc_to_orign);
    float c = dot(sc_to_orign, sc_to_orign) - (radius * radius);

    float discriminant = (h * h) - (a * c);
    float sqr = sqrt(discriminant);

    t0 = ((h * -1.0) - sqr) / a;
    t1 = ((h * -1.0) + sqr) / a;
    
    if(discriminant < 0.0) return false;

    return true;
}