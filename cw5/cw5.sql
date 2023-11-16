create extension postgis;


create table objects (
	id serial primary key,
	name varchar(30),
	geom geometry
)

--1a
insert into objects (name, geom)
values ('obiekt1', 
		ST_collect(array['LINESTRING(0 1, 1 1)',
				    'CIRCULARSTRING(1 1, 2 0, 3 1)', 
					'CIRCULARSTRING(3 1,4 2, 5 1)',
					'LINESTRING(5 1, 6 1)']));
					

--1b
insert into objects (name, geom)
values ('obiekt2', 
		ST_collect(array['LINESTRING(10 6, 14 6)',
				    'CIRCULARSTRING(14 6, 16 4, 14 2)', 
					'CIRCULARSTRING(14 2, 12 0, 10 2)',
					'LINESTRING(10 2, 10 6)',
					'CIRCULARSTRING(11 2, 12 3, 13 2, 12 1, 11 2)']));
					
--1c
insert into objects (name, geom)
values ('obiekt3', 
		'POLYGON((7 15, 10 17, 12 13, 7 15))');
		
--1d
insert into objects (name, geom)
values ('obiekt4', 
		'MULTILINESTRING((20.5 19.5, 22 19, 26 21, 25 22, 27 24, 25 25, 20 20))');
	
--1e
insert into objects (name, geom)
values ('obiekt5', 
		'MULTIPOINT Z ((30 30 59),(38 32 234))');
		
--1f
insert into objects (name, geom)
values ('obiekt6', 
		ST_collect(array['LINESTRING(1 1, 3 2)',
				    'POINT(4 2)']));
					
--z2
select 
	ST_Area(ST_Buffer(ST_ShortestLine(o1.geom, o2.geom),5))
from objects o1
cross join objects o2
where o1.id = 3 and o2.id = 4

--z3
--aby obiekt był poligonem konieczne jest, żeby jego koordynaty zaczynały się w tym samym punkcie co kończyły
update objects
set geom = (select ST_LineMerge(geom)
			from objects
			where id = 4)
where id = 4;

--z4
insert into objects (name, geom)		
select 
	'obiekt7',
	ST_Collect(ARRAY[o1.geom,o2.geom])
from objects o1
cross join objects o2
where o1.id = 3 and o2.id = 4

--z5
select sum(ST_Area(ST_Buffer(geom,5))) from 
objects where id in (
	select id
	from objects
	where not ST_HasArc(geom)
)
