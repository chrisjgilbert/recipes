SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: recipes_tsv_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recipes_tsv_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.search_tsv :=
    setweight(to_tsvector('english', coalesce(NEW.title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.description,'')), 'B') ||
    setweight(to_tsvector('english',
      coalesce((
        SELECT string_agg(ing->>'name', ' ')
        FROM jsonb_array_elements(NEW.parts) part,
             jsonb_array_elements(part->'ingredients') ing
      ), '')
    ), 'C');
  RETURN NEW;
END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recipes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying NOT NULL,
    source_url text,
    source_site character varying,
    description text,
    image_url text,
    prep_time_minutes integer,
    cook_time_minutes integer,
    total_time_minutes integer,
    servings integer,
    parts jsonb DEFAULT '[]'::jsonb NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    cuisine character varying,
    course character varying,
    difficulty character varying,
    notes text,
    search_tsv tsvector,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: recipes recipes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: recipes_course_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_course_idx ON public.recipes USING btree (course);


--
-- Name: recipes_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_created_at_idx ON public.recipes USING btree (created_at DESC);


--
-- Name: recipes_cuisine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_cuisine_idx ON public.recipes USING btree (cuisine);


--
-- Name: recipes_search_tsv_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_search_tsv_idx ON public.recipes USING gin (search_tsv);


--
-- Name: recipes_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_tags_idx ON public.recipes USING gin (tags);


--
-- Name: recipes_title_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recipes_title_trgm_idx ON public.recipes USING gin (title public.gin_trgm_ops);


--
-- Name: recipes recipes_tsv_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER recipes_tsv_trg BEFORE INSERT OR UPDATE ON public.recipes FOR EACH ROW EXECUTE FUNCTION public.recipes_tsv_update();


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260423062338');

