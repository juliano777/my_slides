CREATE ROLE user_test ENCRYPTED PASSWORD '123' LOGIN;

CREATE DATABASE db_test OWNER user_test;

\c db_test user_test

CREATE SCHEMA ns_hr;

SELECT
    nspname AS namespace
    FROM pg_catalog.pg_namespace
    WHERE nspname !~ '(^pg_|information_schema)';
    
    
CREATE TABLE ns_hr.tb_person(
    id_ serial primary key,
    name text not null,
    surname text not null
);

SELECT id_, name, surname FROM ns_hr.tb_person;