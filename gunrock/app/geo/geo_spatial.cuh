// ----------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------

/**
 * @file
 * geo_spatial.cuh
 *
 * @brief Spatial helpers for geolocation app
 */

#pragma once

#include <cmath>
#include <algorithm>

namespace gunrock {
namespace app {
namespace geo {

/* This implementation is adapted from python geotagging app. */
#define PI 3.141592653589793

/**
 * @brief Compute the mean of all latitudues and
 *        and longitudes in a given set.
 */
template <typename GraphT, typename ValueT, typename SizeT>
__host__ void mean(
    GraphT &graph,
    ValueT *latitude,
    ValueT *longitude,
    SizeT   length,
    ValueT *y,
    SizeT   v)
{
    typedef typename GraphT::CsrT CsrT;
    typedef typename GraphT::VertexT VertexT;

    // Calculate mean;
    ValueT a = 0;
    ValueT b = 0;

    SizeT start_edge    = graph.CsrT::GetNeighborListOffset(v);
    SizeT num_neighbors = graph.CsrT::GetNeighborListLength(v);

    SizeT len = 0;
    for(SizeT e = start_edge; e < start_edge + num_neighbors; e++)
    {
        VertexT dest = graph.CsrT::GetEdgeDest(e);
        if(util::isValid(latitude[dest]) && util::isValid(longitude[dest]))
        {
            a += latitude[dest];
            b += longitude[dest];
            len++;
        }
    }

    a /= len;
    b /= len;

    y[0] = a; // output latitude
    y[1] = b; // output longitude

    // printf("Locations Mean[%u] = <%f, %f> with length = %u\n", v, y[0], y[1], length);

    return;
}

/**
 * @brief Compute the midpoint of two points on a sphere.
 */
template <typename ValueT, typename SizeT>
__host__ void midpoint(
    ValueT p1_lat,
    ValueT p1_lon,
    ValueT p2_lat,
    ValueT p2_lon,
    ValueT * latitude,
    ValueT * longitude,
    SizeT v)
{
    // Convert to radians
    p1_lat = radians(p1_lat);
    p1_lon = radians(p1_lon);
    p2_lat = radians(p2_lat);
    p2_lon = radians(p2_lon);

    ValueT bx, by;
    bx = cos(p2_lat) * cos(p2_lon - p1_lon);
    by = cos(p2_lat) * sin(p2_lon - p1_lon);

    ValueT lat, lon;
    lat = atan2(sin(p1_lat) + sin(p2_lat), \
                sqrt((cos(p1_lat) + bx) * (cos(p1_lat) \
                + bx) + by*by));

    lon = p1_lon + atan2(by, cos(p1_lat) + bx);

    latitude[v] = degrees(lat);
    longitude[v] = degrees(lon);

    return;
}

/**
 * @brief Compute spatial median of a set of > 2 points.
 *
 *        Spatial Median;
 *        That is, given a set X find the point m s.t.
 *              sum([dist(x, m) for x in X])
 *
 *        is minimized. This is a robust estimator of
 *        the mode of the set.
 */
template <typename GraphT, typename ValueT, typename SizeT>
__host__ void h_spatial_median(
    GraphT  &graph,
    SizeT   length,

    ValueT *latitude,
    ValueT *longitude,

    SizeT   v,

    ValueT *Dinv,

    bool    quiet = false,
    ValueT  eps = 1e-3,
    SizeT   max_iter = 1000)
{

    typedef typename GraphT::VertexT VertexT;
    typedef typename GraphT::CsrT CsrT;

    // Reinitialize these to ::problem
    // ValueT * D = new ValueT[length];
    // ValueT * Dinv = new ValueT[length];
    // ValueT * W = new ValueT[length];

    // <TODO> this will be a huge issue
    // if known locations for a node are
    // a lot! Will overflood the register
    // file.
    // ValueT * D = new ValueT[length];
    // ValueT * Dinv = new ValueT[length];
    // </TODO>

    ValueT r, rinv;
    ValueT Dinvs = 0;

    SizeT iter_ = 0;
    SizeT nonzeros = 0;
    SizeT num_zeros = 0;

    // Can be done cleaner, but storing lat and long.
    ValueT R[2], tmp[2], out[2], T[2];
    ValueT y[2], y1[2];

    SizeT num_neighbors = graph.CsrT::GetNeighborListLength(v);
    SizeT start_edge    = graph.CsrT::GetNeighborListOffset(v);

    // Calculate mean of all <latitude, longitude>
    // for all possible locations of v;
    mean (graph, 
	  latitude, 
	  longitude,
          length, 
	  y, 
	  v);

    // Calculate the spatial median;
    while (true)
    {
        iter_ += 1;
        Dinvs = 0;
        T[0] = 0; T[1] = 0; // T.lat = 0, T.lon = 0;
        nonzeros = 0;


	for(SizeT e = start_edge; e < start_edge + num_neighbors; e++)
        {
            VertexT dest = graph.CsrT::GetEdgeDest(e);
            if(util::isValid(latitude[dest]) && util::isValid(longitude[dest]))
            {

             ValueT Dist = haversine(latitude[dest],
                              longitude[dest],
                              y[0], y[1]);

	
	     Dinv[e] = Dist == 0 ? 0 : 1/Dist;
	     nonzeros = Dist != 0 ? nonzeros + 1 : nonzeros;
	     Dinvs += Dinv[e];
	    }
	}

	SizeT len = 0;
        for(SizeT e = start_edge; e < start_edge + num_neighbors; e++)
        {
            VertexT dest = graph.CsrT::GetEdgeDest(e);
            if(util::isValid(latitude[dest]) && util::isValid(longitude[dest]))
            {
	        T[0] += (Dinv[e]/Dinvs) * latitude[dest];
	        T[1] += (Dinv[e]/Dinvs) * longitude[dest];
		len++;
	    }
	}

	num_zeros = len - nonzeros;
	if (num_zeros == 0)
	{
	    y1[0] = T[0];
	    y1[1] = T[1];
	}

	else if (num_zeros == len)
	{
	    latitude[v] = y[0];
	    longitude[v] = y[1];
	    return;
	}

	else
	{
	    R[0] = (T[0] - y[0]) * Dinvs;
	    R[1] = (T[1] - y[1]) * Dinvs;
	    r = sqrt(R[0] * R[0] + R[1] * R[1]);
	    rinv = r == 0 ? : num_zeros / r;

	    y1[0] = std::max(0.0f, 1-rinv) * T[0]
	          + std::min(1.0f, rinv)   * y[0]; // latitude
	    y1[1] = std::max(0.0f, 1-rinv) * T[1]
	          + std::min(1.0f, rinv)   * y[1]; // longitude
	}

	tmp[0] = y[0] - y1[0];
	tmp[1] = y[1] - y1[1];

	if((sqrt(tmp[0] * tmp[0] + tmp[1] * tmp[1])) < eps || (iter_ > max_iter))
	{
	    latitude[v] = y1[0];
	    longitude[v] = y1[1];
	    return;
	}

	y[0] = y1[0];
	y[1] = y1[1];
    }
}


} // namespace geo
} // namespace app
} // namespace gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
