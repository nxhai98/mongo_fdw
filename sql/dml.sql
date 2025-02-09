-- Before running this file User must create database mongo_fdw_regress and
-- mongo_fdw_regress1 databases on MongoDB with all permission for
-- MONGO_USER_NAME user with MONGO_PASS password and ran mongodb_init.sh file
-- to load collections.
\set ECHO none
\ir sql/parameters.conf
\set ECHO all
\c contrib_regression
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS mongo_fdw;
--Testcase 2:
CREATE SERVER mongo_server FOREIGN DATA WRAPPER mongo_fdw
  OPTIONS (address :MONGO_HOST, port :MONGO_PORT);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER mongo_server;

-- Create foreign tables
--Testcase 4:
CREATE FOREIGN TABLE f_mongo_test (_id name, a int, b varchar) SERVER mongo_server
  OPTIONS (database 'mongo_fdw_regress', collection 'mongo_test');
--Testcase 5:
CREATE FOREIGN TABLE f_mongo_test1 (_id name, a int, b varchar) SERVER mongo_server
  OPTIONS (database 'mongo_fdw_regress1', collection 'mongo_test1');
--Testcase 6:
CREATE FOREIGN TABLE f_mongo_test2 (_id name, a int, b varchar) SERVER mongo_server
  OPTIONS (database 'mongo_fdw_regress2', collection 'mongo_test2');
-- Creating foreign table without specifying database.
--Testcase 7:
CREATE FOREIGN TABLE f_mongo_test3 (_id name, a int, b varchar) SERVER mongo_server
  OPTIONS (collection 'mongo_test3');

-- Verify the INSERT/UPDATE/DELETE operations on a collection (mongo_test)
-- exist in a database (mongo_fdw_regress) in mongoDB.
--Testcase 8:
SELECT a,b FROM f_mongo_test ORDER BY 1, 2;
--Testcase 9:
INSERT INTO f_mongo_test VALUES ('0', 10 , 'INSERT');
--Testcase 10:
SELECT a,b FROM f_mongo_test ORDER BY 1, 2;
--Testcase 11:
UPDATE f_mongo_test SET b = 'UPDATE' WHERE a = 10;
--Testcase 12:
SELECT a,b FROM f_mongo_test ORDER BY 1, 2;
--Testcase 13:
DELETE FROM f_mongo_test WHERE a = 10;
--Testcase 14:
SELECT a,b FROM f_mongo_test ORDER BY 1, 2;

-- Verify the INSERT/UPDATE/DELETE operations on a collection (mongo_test1)
-- not exist in a database (mongo_fdw_regress1) in mongoDB.
--Testcase 15:
SELECT a,b FROM f_mongo_test1 ORDER BY 1, 2;
--Testcase 16:
INSERT INTO f_mongo_test1 VALUES ('0', 10 , 'INSERT');
--Testcase 17:
SELECT a,b FROM f_mongo_test1 ORDER BY 1, 2;
--Testcase 18:
UPDATE f_mongo_test1 SET b = 'UPDATE' WHERE a = 10;
--Testcase 19:
SELECT a,b FROM f_mongo_test1 ORDER BY 1, 2;
--Testcase 20:
DELETE FROM f_mongo_test1 WHERE a = 10;
--Testcase 21:
SELECT a,b FROM f_mongo_test1 ORDER BY 1, 2;

-- Verify the INSERT/UPDATE/DELETE operations on a collection (mongo_test2)
-- not exist in a non exist database (mongo_fdw_regress2) in mongoDB.
--Testcase 22:
SELECT a,b FROM f_mongo_test2 ORDER BY 1, 2;
--Testcase 23:
INSERT INTO f_mongo_test2 VALUES ('0', 10 , 'INSERT');
--Testcase 24:
SELECT a,b FROM f_mongo_test2 ORDER BY 1, 2;
--Testcase 25:
UPDATE f_mongo_test2 SET b = 'UPDATE' WHERE a = 10;
--Testcase 26:
SELECT a,b FROM f_mongo_test2 ORDER BY 1, 2;
--Testcase 27:
DELETE FROM f_mongo_test2 WHERE a = 10;
--Testcase 28:
SELECT a,b FROM f_mongo_test2 ORDER BY 1, 2;

-- Verify the INSERT/UPDATE/DELETE operations on a collection (mongo_test)
-- when foreign table created without database option.
--Testcase 29:
SELECT a,b FROM f_mongo_test3 ORDER BY 1, 2;
--Testcase 30:
INSERT INTO f_mongo_test3 VALUES ('0', 10 , 'INSERT');
--Testcase 31:
SELECT a,b FROM f_mongo_test3 ORDER BY 1, 2;
--Testcase 32:
UPDATE f_mongo_test3 SET b = 'UPDATE' WHERE a = 10;
--Testcase 33:
SELECT a,b FROM f_mongo_test3 ORDER BY 1, 2;
--Testcase 34:
DELETE FROM f_mongo_test3 WHERE a = 10;
--Testcase 35:
SELECT a,b FROM f_mongo_test3 ORDER BY 1, 2;

-- FDW-158: Fix server crash when analyzing a foreign table.
ANALYZE f_mongo_test;
-- Should give correct number of rows now.
--Testcase 36:
SELECT reltuples FROM pg_class WHERE relname = 'f_mongo_test';
-- Check count using select query on table.
--Testcase 37:
SELECT count(*) FROM f_mongo_test;

-- Some more variants of vacuum and analyze
VACUUM f_mongo_test;
VACUUM FULL f_mongo_test;
VACUUM FREEZE f_mongo_test;
ANALYZE f_mongo_test;
ANALYZE f_mongo_test(a);
VACUUM ANALYZE f_mongo_test;

-- FDW-226: Fix COPY FROM and foreign partition routing results in a
-- server crash

-- Should fail as foreign table direct copy is not supported
COPY f_mongo_test TO '/tmp/data.txt' delimiter ',';
COPY f_mongo_test (a) TO '/tmp/data.txt' delimiter ',';
COPY f_mongo_test (b) TO '/tmp/data.txt' delimiter ',';

-- Should pass
COPY (SELECT * FROM f_mongo_test) TO '/tmp/data.txt' delimiter ',';
COPY (SELECT a, b FROM f_mongo_test) TO '/tmp/data.txt' delimiter ',';
COPY (SELECT a FROM f_mongo_test) TO '/tmp/data.txt' delimiter ',';
COPY (SELECT b FROM f_mongo_test) TO '/tmp/data.txt' delimiter ',';

-- Should throw an error as copy to foreign table is not supported
DO
$$
BEGIN
  COPY f_mongo_test FROM '/tmp/data.txt' delimiter ',';
EXCEPTION WHEN others THEN
  IF SQLERRM = 'COPY and foreign partition routing not supported in mongo_fdw' OR
     SQLERRM = 'cannot copy to foreign table "f_mongo_test"' THEN
    RAISE NOTICE 'ERROR:  COPY and foreign partition routing not supported in mongo_fdw';
  ELSE
    RAISE NOTICE '%', SQLERRM;
  END IF;
END;
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  COPY f_mongo_test(a, b) FROM '/tmp/data.txt' delimiter ',';
EXCEPTION WHEN others THEN
  IF SQLERRM = 'COPY and foreign partition routing not supported in mongo_fdw' OR
     SQLERRM = 'cannot copy to foreign table "f_mongo_test"' THEN
    RAISE NOTICE 'ERROR:  COPY and foreign partition routing not supported in mongo_fdw';
  ELSE
    RAISE NOTICE '%', SQLERRM;
  END IF;
END;
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  COPY f_mongo_test(a) FROM '/tmp/data.txt' delimiter ',';
EXCEPTION WHEN others THEN
  IF SQLERRM = 'COPY and foreign partition routing not supported in mongo_fdw' OR
     SQLERRM = 'cannot copy to foreign table "f_mongo_test"' THEN
    RAISE NOTICE 'ERROR:  COPY and foreign partition routing not supported in mongo_fdw';
  ELSE
    RAISE NOTICE '%', SQLERRM;
  END IF;
END;
$$
LANGUAGE plpgsql;

DO
$$
BEGIN
  COPY f_mongo_test(b) FROM '/tmp/data.txt' delimiter ',';
EXCEPTION WHEN others THEN
  IF SQLERRM = 'COPY and foreign partition routing not supported in mongo_fdw' OR
     SQLERRM = 'cannot copy to foreign table "f_mongo_test"' THEN
    RAISE NOTICE 'ERROR:  COPY and foreign partition routing not supported in mongo_fdw';
  ELSE
    RAISE NOTICE '%', SQLERRM;
  END IF;
END;
$$
LANGUAGE plpgsql;


-- Cleanup
--Testcase 38:
DROP FOREIGN TABLE f_mongo_test;
--Testcase 39:
DROP FOREIGN TABLE f_mongo_test1;
--Testcase 40:
DROP FOREIGN TABLE f_mongo_test2;
--Testcase 41:
DROP FOREIGN TABLE f_mongo_test3;
--Testcase 42:
DROP USER MAPPING FOR public SERVER mongo_server;
--Testcase 43:
DROP SERVER mongo_server;
--Testcase 44:
DROP EXTENSION mongo_fdw;
