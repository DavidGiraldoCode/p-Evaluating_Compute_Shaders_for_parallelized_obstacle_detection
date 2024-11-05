using UnityEngine;

/// <summary>
/// 🚧 Description WIP 🚧
/// </summary>
public class Boid : MonoBehaviour
{
    public Fleet UAVFleet { get; set; }

    public Vector3 Position;
    public Vector3 Velocity;
    public Vector3 Acceleration;
    void Start()
    {
        // Set the initial velocidty to a random direction of length 1.
        Velocity = Random.insideUnitSphere * 2;
    }

    #region Simulation
    //Custom Methods
    public void UpdateSimulation(float deltaTime)
    {
        //Clear acceleration from last frame
        Acceleration = Vector3.zero;

        //Apply forces
        Acceleration += UAVFleet.GetForceFromBounds(this);
        Acceleration += GetConstraintSpeedForce();
        Acceleration += GetSteeringForce();

        //Step simulation
        Velocity += deltaTime * Acceleration;
        Position += 0.5f * deltaTime * deltaTime * Acceleration + deltaTime * Velocity;

    }

    /// <summary>
    /// Computes the steering forces that involve the fleet
    /// </summary>
    /// <returns>Vector</returns>
    private Vector3 GetSteeringForce()
    {
        Vector3 cohesionForce = Vector3.zero;
        Vector3 alignmentForce = Vector3.zero;
        Vector3 separationForce = Vector3.zero;

        //Average velocity
        Vector3 velocityAccumulador = Vector3.zero;
        Vector3 averageVelocity = Vector3.zero;

        //Average position
        Vector3 positionAccumulador = Vector3.zero;
        Vector3 averagePosition = Vector3.zero;

        //Boid forces
        //The iteration happens on a collection IEnumerable<Boid>
        foreach (Boid neighbor in UAVFleet.BoidManager.GetNeighbors(this, UAVFleet.Behaviour.NeighborRadius))
        {
            float distance = (neighbor.Position - Position).magnitude;

            //Separation force
            if (distance < UAVFleet.Behaviour.SeparationRadius)
            {
                separationForce += UAVFleet.Behaviour.SeparationForceFactor * ((UAVFleet.Behaviour.SeparationRadius - distance) / distance) * (Position - neighbor.Position);
            }

            //Aerage velocity
            if (distance < UAVFleet.Behaviour.AlignmentRadius)
            {
                velocityAccumulador += neighbor.Velocity;
            }

            //Aerage velocity
            if (distance < UAVFleet.Behaviour.CohesionRadius)
            {
                positionAccumulador += neighbor.Position;
            }

        }

        averageVelocity = velocityAccumulador / UAVFleet.BoidManager.GetNeighborsCount();
        alignmentForce = UAVFleet.Behaviour.AlignmentForceFactor * (averageVelocity - Velocity);

        averagePosition = positionAccumulador / UAVFleet.BoidManager.GetNeighborsCount();
        cohesionForce = UAVFleet.Behaviour.CohesionForceFactor * (averagePosition - Position);

        return alignmentForce + cohesionForce + separationForce;
    }

    Vector3 GetConstraintSpeedForce()
    {
        Vector3 force = Vector3.zero;

        //Apply drag
        force -= UAVFleet.Behaviour.Drag * Velocity;

        float vel = Velocity.magnitude;
        if (vel > UAVFleet.Behaviour.MaxSpeed)
        {
            //If speed is above the maximum allowed speed, apply extra friction force
            force -= (20.0f * (vel - UAVFleet.Behaviour.MaxSpeed) / vel) * Velocity;
        }
        else if (vel < UAVFleet.Behaviour.MinSpeed)
        {
            //Increase the speed slightly in the same direction if it is below the minimum
            force += (5.0f * (UAVFleet.Behaviour.MinSpeed - vel) / vel) * Velocity;
        }

        return force;
    }

    #endregion Simulation
}
