module engine.math.ray;
import engine.math;

/**
    A ray
*/
struct Ray(T) if (is_vector!T) {
public:
    /**
        Last position of the ray
    */
    T lastPosition;

    /**
        Current position of the ray
    */
    T position;

    /**
        The direction of the ray
    */
    T direction;

    /**
        Constructs a ray
    */
    this(T position, T direction) {
        this.position = position;
        this.direction = direction;
    }

    /**
        Simulates one step of the ray
    */
    void simulate() {
        this.lastPosition = position;
        this.position += direction;
    }
}