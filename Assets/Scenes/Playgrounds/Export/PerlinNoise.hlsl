//psudo-random
float hash(uint n) {
    // Integer hash function for randomness
    n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
    return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
}

// Initialize the permutation table inline
int p[256];

// Function to initialize the permutation table
void initializePermutationTable()
{
    for (int i = 0; i < 256; i++)
    {
        p[i] = int((hash(i) - 1) * 255) ;
    }
}

float fade(float t) { return t * t * t * (t * (t * 6 - 15) + 10); }

float lerp(float t, float a, float b) { return a + t * (b - a); }

float grad(int hash, float x, float y, float z)
{
    int h = hash & 15;
    float u = h<8 ? x : y,
        v = h<4 ? y : h==12||h==14 ? x : z;
    return ((h&1) == 0 ? u : -u) + ((h&2) == 0 ? v : -v);
}

float noise(float x, float y, float z)
{
    initializePermutationTable();

    int X = (int)floor(x) & 255,
        Y = (int)floor(y) & 255,
        Z = (int)floor(z) & 255;

    x -= floor(x);
    y -= floor(y);
    z -= floor(z);

    float u = fade(x),
        v = fade(y),
        w = fade(z);

    int A = p[X  ]+Y, AA = p[A]+Z, AB = p[A+1]+Z,
        B = p[X+1]+Y, BA = p[B]+Z, BB = p[B+1]+Z;

    return lerp(w, lerp(v, lerp(u, grad(p[AA  ], x  , y  , z   ),
                                grad(p[BA  ], x-1, y  , z   )),
                        lerp(u, grad(p[AB  ], x  , y-1, z   ),
                                grad(p[BB  ], x-1, y-1, z   ))),
                lerp(v, lerp(u, grad(p[AA+1], x  , y  , z-1 ),
                                grad(p[BA+1], x-1, y  , z-1 )),
                        lerp(u, grad(p[AB+1], x  , y-1, z-1 ),
                                grad(p[BB+1], x-1, y-1, z-1 ))));
}