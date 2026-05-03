// Clear the existing database
MATCH (n) DETACH DELETE n;

// Create uniqueness constraints to optimize search performance
CREATE CONSTRAINT FOR (r:Route) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT FOR (l:Location) REQUIRE l.name IS UNIQUE;

// Load routes with physical attributes and coordinates
LOAD CSV WITH HEADERS FROM 'file:///neo4j_routes_california.csv' AS row
CREATE (:Route {
  id: toInteger(row.route_id), 
  name: row.route, 
  stars: toFloat(row.avg_stars), 
  rating: toInteger(row.rating_num), 
  rating_label: row.rating,
  pitches: toInteger(row.pitches),
  length: toFloat(row.length),
  type: row.route_type,
  lat: toFloat(row.area_latitude),
  lon: toFloat(row.area_longitude)
});

// Import unique location nodes
LOAD CSV WITH HEADERS FROM 'file:///neo4j_locations_california.csv' AS row
MERGE (:Location {name: row.name});

// Map routes to their specific sectors
LOAD CSV WITH HEADERS FROM 'file:///neo4j_edges_california.csv' AS row
WITH row WHERE row.type = 'IN_AREA'
MATCH (r:Route {id: toInteger(replace(row.source, 'route_', ''))})
MATCH (l:Location {name: row.target})
MERGE (r)-[:IN_AREA]->(l);

// Build the geographical hierarchy (Sector > Area > Region)
LOAD CSV WITH HEADERS FROM 'file:///neo4j_edges_california.csv' AS row
WITH row WHERE row.type = 'SUB_AREA_OF'
MATCH (child:Location {name: row.source})
MATCH (parent:Location {name: row.target})
MERGE (child)-[:SUB_AREA_OF]->(parent);

// Initialize properties on Location nodes for graph projection compatibility
MATCH (l:Location)
SET l.lat = 0.0, 
    l.lon = 0.0, 
    l.rating = 0, 
    l.length = 0.0;

// Replace missing heights with the sector average
MATCH (r:Route)
WHERE r.length IS NULL OR toString(r.length) = 'NaN'
MATCH (r)-[:IN_AREA]->(sector:Location)
OPTIONAL MATCH (sector)<-[:IN_AREA]-(sibling:Route)
WHERE sibling.length IS NOT NULL AND toString(sibling.length) <> 'NaN' AND sibling <> r
WITH r, avg(sibling.length) AS sector_avg, sector
SET r.length = coalesce(sector_avg, 65.0) // Fallback to median if sector is empty
RETURN r.name AS Route, r.length AS New_Height, sector.name AS Sector;

// Create the additional connection between close routes
MATCH (r:Route)
WHERE r.lat IS NOT NULL AND r.lon IS NOT NULL
SET r.location_point = point({latitude: r.lat, longitude: r.lon});

MATCH (r1:Route)
MATCH (r2:Route)
WHERE id(r1) < id(r2) 
  AND abs(r1.lat - r2.lat) < 0.001 
  AND abs(r1.lon - r2.lon) < 0.001
  
WITH r1, r2, point.distance(r1.location_point, r2.location_point) AS dist
WHERE dist < 100 // Less than 100 meters

MERGE (r1)-[:NEAR_TO]->(r2);



// Project the graph for GDS including physical features in both node types
CALL gds.graph.project(
  'climbingGraphGeo',
  {
    Route: { properties: ['rating', 'length', 'lat', 'lon'] },
    Location: { properties: ['rating', 'length', 'lat', 'lon'] }
  },
  {
    IN_AREA: { orientation: 'UNDIRECTED' },
    SUB_AREA_OF: { orientation: 'UNDIRECTED' }
  }
);

// Generate embeddings using FastRP with a high property weighting
CALL gds.fastRP.write(
  'climbingGraphGeo',
  {
    embeddingDimension: 64,
    featureProperties: ['rating', 'length', 'lat', 'lon'],
    iterationWeights: [1.0, 0.2], // Limit message passing to preserve local identity
    propertyRatio: 0.9,           // Prioritize technical attributes
    randomSeed: 42,
    writeProperty: 'embedding_geo_rico'
  }
);


// Delete existing proyection to create the new one for GNNs
CALL gds.graph.drop('climbingGraphGeo', false);

MATCH (l:Location)
SET l.stars = 0;

CALL gds.graph.project(
  'climbingGraphClean',
  {
    Route: {
      properties: {
        length: { defaultValue: 0.0 },
        lat: { defaultValue: 0.0 },
        lon: { defaultValue: 0.0 },
        stars: { defaultValue: 0.0 }
      }
    },
    Location: {
      properties: {
        length: { defaultValue: 0.0 },
        lat: { defaultValue: 0.0 },
        lon: { defaultValue: 0.0 },
        stars: { defaultValue: 0.0 }
      }
    }
  },
  {
    IN_AREA: { orientation: 'UNDIRECTED' },
    SUB_AREA_OF: { orientation: 'UNDIRECTED' },
    NEAR_TO: { orientation: 'UNDIRECTED' }
  }
);


// Embeddings for GNNs without the rating attribute
CALL gds.fastRP.write('climbingGraphClean', {
  embeddingDimension: 64,
  propertyRatio: 0.9, 
  nodeProperties: ['length', 'lat', 'lon', 'stars'], 
  iterationWeights: [0.0, 1.0, 1.0],
  writeProperty: 'embedding_gnn_clean'
})

