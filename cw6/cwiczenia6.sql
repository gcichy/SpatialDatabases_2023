--1. Nowa baza danych
--	CREATE DATABASE cw6;
--    CREATE EXTENSION postgis_raster;
--    pg_restore.exe -h localhost -p 5432 -U postgres -d cw6 postgis_raster.backup

--2. Ładowanie danych rastrowych
--raster2pgsql.exe -s 3763 -N -32767 -t 100x100 -I -C -M -d "C:\Users\gcich\OneDrive\Pulpit\semestr7\BDP\cw6\srtm_1arc_v3.tif" rasters.dem | psql -d cw6 -h localhost -U postgres -p 5432
--raster2pgsql.exe -s 3763 -N -32767 -t 128x128 -I -C -M -d "C:\Users\gcich\OneDrive\Pulpit\semestr7\BDP\cw6\Landsat8_L1TP_RGBN.TIF" rasters.landsat8 | psql -d cw6 -h localhost -U postgres -p 5432

SELECT * FROM public.raster_columns

--Tworzenie rastrów z istniejących rastrów i interakcja z wektorami
--Przykład 1 - ST_Intersects - Przecięcie rastra z wektorem.

CREATE TABLE cichy.intersects AS 
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

alter table cichy.intersects
add column rid SERIAL PRIMARY KEY;

CREATE INDEX idx_intersects_rast_gist ON cichy.intersects
USING gist (ST_ConvexHull(rast));

-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('cichy'::name, 
'intersects'::name,'rast'::name);

--Przykład 2 - ST_Clip - Obcinanie rastra na podstawie wektora.

CREATE TABLE cichy.clip AS 
SELECT ST_Clip(a.rast, b.geom, true), b.municipality 
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

select * from cichy.clip

--Przykład 3 - ST_Union - Połączenie wielu kafelków w jeden raster.
CREATE TABLE cichy.union AS 
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);


select * from cichy.union;

--Tworzenie rastrów z wektorów (rastrowanie)

--Przykład 1 - ST_AsRaster - Przykład pokazuje użycie funkcji ST_AsRaster


CREATE TABLE cichy.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem 
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

select * from cichy.porto_parishes;

--Przykład 2 - ST_Union

DROP TABLE cichy.porto_parishes; --> drop table porto_parishes first
CREATE TABLE cichy.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem 
LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

select * from cichy.porto_parishes;

--Przykład 3 - ST_Tile

DROP TABLE cichy.porto_parishes; --> drop table porto_parishes first
CREATE TABLE cichy.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem 
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-
32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

select * from cichy.porto_parishes;

--Konwertowanie rastrów na wektory (wektoryzowanie)
-- Przykład 1 - ST_Intersection

create table cichy.intersection as 
SELECT 
a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)
).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b 
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

select * from cichy.intersection limit 100;

--Przykład 2 - ST_DumpAsPolygons - konwertuje rastry w wektory (poligony).

CREATE TABLE cichy.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b 
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

select * from cichy.dumppolygons limit 100;

--Analiza rastrów
--Przykład 1 - ST_Band - służy do wyodrębniania pasm z rastra

CREATE TABLE cichy.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

select * from cichy.landsat_nir limit 100;

--Przykład 2 - ST_Clip

CREATE TABLE cichy.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

select * from cichy.paranhos_dem;

--Przykład 3 - ST_Slope

CREATE TABLE cichy.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM cichy.paranhos_dem AS a;

select * from cichy.paranhos_slope;

--Przykład 4 - ST_Reclass - Aby zreklasyfikować raster
CREATE TABLE cichy.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3', 
'32BF',0)
FROM cichy.paranhos_slope AS a;

select * from cichy.paranhos_slope_reclass;

--Przykład 5 - ST_SummaryStats - Aby obliczyć statystyki rastra
SELECT st_summarystats(a.rast) AS stats
FROM cichy.paranhos_dem AS a;

--Przykład 6 - ST_SummaryStats oraz Union
SELECT st_summarystats(ST_Union(a.rast))
FROM cichy.paranhos_dem AS a;


--Przykład 7 - ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM cichy.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

--Przykład 8 - ST_SummaryStats w połączeniu z GROUP BY 
WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

--Przykład 9 - ST_Value
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM 
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;


--Topographic Position Index (TPI)

--Przykład 10 - ST_TPI

create table cichy.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON cichy.tpi30
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('cichy'::name, 
'tpi30'::name,'rast'::name);

--z1 - Problem do samodzielnego rozwiązania
create table cichy.tpi30_narrowed as
with porto as 
(
select geom 
from vectors.porto_parishes
where municipality ilike 'Porto'
)
select ST_TPI(a.rast,1) as rast
from rasters.dem a, porto p
where ST_Intersects(a.rast, p.geom)