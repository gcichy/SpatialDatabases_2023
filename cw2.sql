--z3
create extension postgis;

--z4
create table buildings (id int,geometry geometry,name varchar);
create table roads (id int,geometry geometry,name varchar);
create table poi (id int,geometry geometry,name varchar);

insert into buildings(id, geometry, name)
values
(1,'POLYGON((8 4, 10.5 4, 10.5 1.5, 8 1.5, 8 4))','BuildingA'),
(1,'POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))','BuildingB'),
(1,'POLYGON((3 8, 5 8, 5 6, 3 6, 3 8))','BuildingC'),
(1,'POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))','BuildingD'),
(1,'POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))','BuildingF')


insert into poi(id, geometry, name)
values
(2,'POINT(6.5 6)','J'),
(3,'POINT(9.5 6)','I'),
(4,'POINT(5.5 1.5)','H'),
(5,'POINT(1 3.5)','G')


insert into roads(id, geometry, name)
values
(1,'LINESTRING(7.5 10.5, 7.5 0)', 'RoadY'),
(2,'LINESTRING(0 4.5, 12 4.5)','RoadX')

--z6
--a
select sum(ST_Length(geometry)) from roads
--b
select ST_Astext(geometry)
	   ,ST_Area(geometry)
	   ,ST_Perimeter(geometry)
from buildings
where name = 'BuildingA'
--c
select name
	   ,ST_Area(geometry)
from buildings
order by name asc
--d
select name
	   ,ST_Perimeter(geometry)
from buildings
order by ST_Area(geometry) desc
limit 2
--e 
select ST_Distance(b.geometry, p.geometry) 
from buildings b 
cross join poi p 
where b.name = 'BuildingC' 
	  and p.name = 'K';
--f
select ST_Area(ST_Difference(b.geometry
			   ,ST_Buffer(b2.geometry, 0.5))) 
from buildings b
cross join buildings b2 
where b.name = 'BuildingC' 
	  and b2.name = 'BuildingB';
--g
select ST_Y(ST_Centroid(geometry)), *
from buildings
where ST_Y(ST_Centroid(geometry)) > (select ST_Y(ST_Centroid(geometry))
									from roads 
									 where name = 'RoadX')
	
--h
select ST_Area(ST_Symdifference(geometry, 'POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')) 
from buildings 
where name = 'BuildingC'

