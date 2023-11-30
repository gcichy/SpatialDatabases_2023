--Algebra map

--Przykład 1 - Wyrażenie Algebry Map

CREATE TABLE cichy.porto_ndvi AS 
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] + 
[rast1.val])::float','32BF'
) AS rast
FROM r;

--indeks przestrzenny
CREATE INDEX idx_porto_ndvi_rast_gist ON cichy.porto_ndvi
USING gist (ST_ConvexHull(rast));

--Dodanie constraintów:
SELECT AddRasterConstraints('cichy'::name, 
'porto_ndvi'::name,'rast'::name);

select * from cichy.porto_ndvi;

--Przykład 2 – Funkcja zwrotna
create or replace function cichy.ndvi(
value double precision [] [] [], 
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value 
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;


CREATE TABLE cichy.porto_ndvi2 AS 
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'cichy.ndvi(double precision[], 
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

--indeks przestrzenny:
CREATE INDEX idx_porto_ndvi2_rast_gist ON cichy.porto_ndvi2
USING gist (ST_ConvexHull(rast));

--Dodanie constraintów:
SELECT AddRasterConstraints('cichy'::name, 
'porto_ndvi2'::name,'rast'::name);

select * from cichy.porto_ndvi2;


--Przykład 3 - Funkcje TPI

-- FUNCTION: public._st_tpi4ma(double precision[], integer[], text[])

-- DROP FUNCTION IF EXISTS public._st_tpi4ma(double precision[], integer[], text[]);

CREATE OR REPLACE FUNCTION public._st_tpi4ma(
	value double precision[],
	pos integer[],
	VARIADIC userargs text[] DEFAULT NULL::text[])
    RETURNS double precision
    LANGUAGE 'plpgsql'
    COST 100
    IMMUTABLE PARALLEL SAFE 
AS $BODY$
	DECLARE
		x integer;
		y integer;
		z integer;

		Z1 double precision;
		Z2 double precision;
		Z3 double precision;
		Z4 double precision;
		Z5 double precision;
		Z6 double precision;
		Z7 double precision;
		Z8 double precision;
		Z9 double precision;

		tpi double precision;
		mean double precision;
		_value double precision[][][];
		ndims int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := public._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		-------------------------------------------------
		--|   Z1= Z(-1,1) |  Z2= Z(0,1)	| Z3= Z(1,1)  |--
		-------------------------------------------------
		--|   Z4= Z(-1,0) |  Z5= Z(0,0) | Z6= Z(1,0)  |--
		-------------------------------------------------
		--|   Z7= Z(-1,-1)|  Z8= Z(0,-1)|  Z9= Z(1,-1)|--
		-------------------------------------------------

		Z1 := _value[z][1][1];
		Z2 := _value[z][2][1];
		Z3 := _value[z][3][1];
		Z4 := _value[z][1][2];
		Z5 := _value[z][2][2];
		Z6 := _value[z][3][2];
		Z7 := _value[z][1][3];
		Z8 := _value[z][2][3];
		Z9 := _value[z][3][3];

		mean := (Z1 + Z2 + Z3 + Z4 + Z6 + Z7 + Z8 + Z9)/8;
		tpi := Z5-mean;

		return tpi;
	END;
	
$BODY$;

ALTER FUNCTION public._st_tpi4ma(double precision[], integer[], text[])
    OWNER TO postgres;
	
--FUNKCJE ST_TPI:
-- FUNCTION: public.st_tpi(raster, integer, raster, text, boolean)

-- DROP FUNCTION IF EXISTS public.st_tpi(raster, integer, raster, text, boolean);

CREATE OR REPLACE FUNCTION public.st_tpi(
	rast raster,
	nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF'::text,
	interpolate_nodata boolean DEFAULT false)
    RETURNS raster
    LANGUAGE 'plpgsql'
    COST 100
    IMMUTABLE PARALLEL SAFE 
AS $BODY$
	DECLARE
		_rast public.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent public.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := public.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'public.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := public.ST_PixelWidth(_rast);
		_pixheight := public.ST_PixelHeight(_rast);
		SELECT width, height INTO _width, _height FROM public.ST_Metadata(_rast);

		RETURN public.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' public._ST_tpi4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1);
	END;
	
$BODY$;

ALTER FUNCTION public.st_tpi(raster, integer, raster, text, boolean)
    OWNER TO postgres;

COMMENT ON FUNCTION public.st_tpi(raster, integer, raster, text, boolean)
    IS 'args: rast, nband, customextent, pixeltype="32BF", interpolate_nodata=FALSE - Returns a raster with the calculated Topographic Position Index.';


-- FUNCTION: public.st_tpi(raster, integer, text, boolean)

-- DROP FUNCTION IF EXISTS public.st_tpi(raster, integer, text, boolean);

CREATE OR REPLACE FUNCTION public.st_tpi(
	rast raster,
	nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF'::text,
	interpolate_nodata boolean DEFAULT false)
    RETURNS raster
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE 
AS $BODY$
 SELECT public.ST_tpi($1, $2, NULL::public.raster, $3, $4) 
$BODY$;

ALTER FUNCTION public.st_tpi(raster, integer, text, boolean)
    OWNER TO postgres;


--Przykład 0 - Użycie QGIS

--Przykład 1 - ST_AsTiff

SELECT ST_AsTiff(ST_Union(rast))
FROM cichy.porto_ndvi;

--Przykład 2 - ST_AsGDALRaster

--dostępne formaty
SELECT ST_GDALDrivers();

SELECT ST_AsGDALRaster(ST_Union(rast), 'JPEG', ARRAY['COMPRESS=DEFLATE', 
'PREDICTOR=2', 'PZLEVEL=9'])
FROM cichy.porto_ndvi;


--Przykład 3 - Zapisywanie danych na dysku za pomocą dużego obiektu (large object, lo)
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
 ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 
'PREDICTOR=2', 'PZLEVEL=9'])
 ) AS loid
FROM cichy.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'G:\myraster.tiff') --> Save the file in a place where the user postgres have access. In windows a flash drive usualy works fine.
 FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
 FROM tmp_out; --> Delete the large object.

--Przykład 4 - Użycie Gdal
gdal_translate -co COMPRESS=DEFLATE -co PREDICTOR=2 -co ZLEVEL=9 PG:"host=localhost port=5432 dbname=postgis_raster user=postgres password=...... schema=cichy table=porto_ndvi mode=2" porto_ndvi.tiff


--Publikowanie danych za pomocą MapServer
--Przykład 1 - Mapfile
MAP
	NAME 'map'
	SIZE 800 650
	STATUS ON
	EXTENT -58968 145487 30916 206234
	UNITS METERS
	WEB
		METADATA
		'wms_title' 'Terrain wms'
		'wms_srs' 'EPSG:3763 EPSG:4326 EPSG:3857'
		'wms_enable_request' '*'
		'wms_onlineresource' 
		'http://54.37.13.53/mapservices/srtm'
		END
	END
	PROJECTION
		'init=epsg:3763'
	END
	LAYER
		NAME srtm
		TYPE raster
		STATUS OFF
		DATA "PG:host=localhost port=5432 dbname='postgis_raster' 
		user='postgres' password='...' schema='rasters' table='dem' mode='2'"
		PROCESSING "SCALE=AUTO"
		PROCESSING "NODATA=-32767"
		OFFSITE 0 0 0
		METADATA
			'wms_title' 'srtm'
		END
	END
END