CREATE EXTENSION postgis;

--1
select polygon_id, type, name, height, geom from buildings_2019
except
select polygon_id, type, name, height, geom from buildings_2018

create view new_buildings as
select polygon_id, type, name, height, geom from buildings_2019
except
select polygon_id, type, name, height, geom from buildings_2018

--2
select * from poi_2019

select a.type, count(*) from (
	select distinct p.*
		from poi_2019 p
		cross join new_buildings nb
		where p.poi_id in(
					select poi_id from poi_2019
					except
					select poi_id from poi_2018)
			  and st_distance(p.geom::geography,nb.geom::geography) < 500
) a
group by a.type

--3
update streets_reprojected
set geom = st_transform(geom, 3068)

--4 / 5
create table input_points (
	name text,
	geom geometry(point, 3068)
)

insert into input_points values
('X','POINT(8.36093 8.39876)'),
('Y','POINT(49.03174 49.00644)')


--7
select count(*) from (
	select distinct po.*
	from poi_2019 po
	cross join parks_2019 pa
	where po.type = 'Sporting Goods Store'
			and st_distance(po.geom::geography,st_centroid(pa.geom)::geography) < 300
)

--8
select row_number() over() as num,
		water_type,
		geom
into bridges_2019
from(
	select distinct 
				wl.type as water_type, 
				st_intersection(r.geom, wl.geom) as geom
	from railways_2019 r
	cross join water_lines_2019 wl
	where st_astext(st_intersection(r.geom, wl.geom)) != 'LINESTRING EMPTY'
)

select * from bridges_2019