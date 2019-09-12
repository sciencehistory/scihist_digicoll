SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


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
-- Name: kithe_models_friendlier_id_gen(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.kithe_models_friendlier_id_gen(min_value bigint, max_value bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
  DECLARE
    new_id_int bigint;
    new_id_str character varying := '';
    done bool;
    tries integer;
    alphabet char[] := ARRAY['0','1','2','3','4','5','6','7','8','9',
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
      'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
    alphabet_length integer := array_length(alphabet, 1);

  BEGIN
    done := false;
    tries := 0;
    WHILE (NOT done) LOOP
      tries := tries + 1;
      IF (tries > 3) THEN
        RAISE 'Could not find non-conflicting friendlier_id in 3 tries';
      END IF;

      new_id_int := trunc(random() * (max_value - min_value) + min_value);

      -- convert bigint to a Base-36 alphanumeric string
      -- see https://web.archive.org/web/20130420084605/http://www.jamiebegin.com/base36-conversion-in-postgresql/
      -- https://gist.github.com/btbytes/7159902
      WHILE new_id_int != 0 LOOP
        new_id_str := alphabet[(new_id_int % alphabet_length)+1] || new_id_str;
        new_id_int := new_id_int / alphabet_length;
      END LOOP;

      done := NOT exists(SELECT 1 FROM kithe_models WHERE friendlier_id=new_id_str);
    END LOOP;
    RETURN new_id_str;
  END;
  $$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: digitization_queue_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.digitization_queue_items (
    id bigint NOT NULL,
    title character varying,
    collecting_area character varying,
    bib_number character varying,
    location character varying,
    accession_number character varying,
    museum_object_id character varying,
    box character varying,
    folder character varying,
    dimensions character varying,
    materials character varying,
    scope text,
    instructions text,
    additional_notes text,
    copyright_status character varying,
    status character varying DEFAULT 'awaiting_dig_on_cart'::character varying,
    status_changed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: digitization_queue_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.digitization_queue_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: digitization_queue_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.digitization_queue_items_id_seq OWNED BY public.digitization_queue_items.id;


--
-- Name: fixity_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixity_checks (
    id bigint NOT NULL,
    asset_id uuid NOT NULL,
    passed boolean,
    expected_result character varying,
    actual_result character varying,
    checked_uri character varying,
    hash_function character varying DEFAULT 'SHA-512'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: fixity_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fixity_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fixity_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fixity_checks_id_seq OWNED BY public.fixity_checks.id;


--
-- Name: kithe_derivatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kithe_derivatives (
    id bigint NOT NULL,
    key character varying NOT NULL,
    file_data jsonb,
    asset_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: kithe_derivatives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kithe_derivatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: kithe_derivatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kithe_derivatives_id_seq OWNED BY public.kithe_derivatives.id;


--
-- Name: kithe_model_contains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kithe_model_contains (
    containee_id uuid,
    container_id uuid
);


--
-- Name: kithe_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kithe_models (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    title character varying NOT NULL,
    type character varying NOT NULL,
    "position" integer,
    json_attributes jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    parent_id uuid,
    friendlier_id character varying DEFAULT public.kithe_models_friendlier_id_gen('2176782336'::bigint, '78364164095'::bigint) NOT NULL,
    file_data jsonb,
    representative_id uuid,
    leaf_representative_id uuid,
    digitization_queue_item_id bigint,
    published boolean DEFAULT false NOT NULL,
    kithe_model_type integer NOT NULL
);


--
-- Name: on_demand_derivatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.on_demand_derivatives (
    id bigint NOT NULL,
    work_id uuid NOT NULL,
    deriv_type character varying NOT NULL,
    status character varying DEFAULT 'in_progress'::character varying NOT NULL,
    inputs_checksum character varying NOT NULL,
    error_info text,
    progress integer,
    progress_total integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: on_demand_derivatives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.on_demand_derivatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: on_demand_derivatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.on_demand_derivatives_id_seq OWNED BY public.on_demand_derivatives.id;


--
-- Name: queue_item_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.queue_item_comments (
    id bigint NOT NULL,
    digitization_queue_item_id bigint NOT NULL,
    user_id bigint,
    text text,
    system_action boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: queue_item_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.queue_item_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: queue_item_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.queue_item_comments_id_seq OWNED BY public.queue_item_comments.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searches (
    id integer NOT NULL,
    query_params bytea,
    user_id integer,
    user_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.searches_id_seq OWNED BY public.searches.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying,
    admin boolean,
    locked_out boolean
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: digitization_queue_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.digitization_queue_items ALTER COLUMN id SET DEFAULT nextval('public.digitization_queue_items_id_seq'::regclass);


--
-- Name: fixity_checks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixity_checks ALTER COLUMN id SET DEFAULT nextval('public.fixity_checks_id_seq'::regclass);


--
-- Name: kithe_derivatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_derivatives ALTER COLUMN id SET DEFAULT nextval('public.kithe_derivatives_id_seq'::regclass);


--
-- Name: on_demand_derivatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.on_demand_derivatives ALTER COLUMN id SET DEFAULT nextval('public.on_demand_derivatives_id_seq'::regclass);


--
-- Name: queue_item_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queue_item_comments ALTER COLUMN id SET DEFAULT nextval('public.queue_item_comments_id_seq'::regclass);


--
-- Name: searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches ALTER COLUMN id SET DEFAULT nextval('public.searches_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: digitization_queue_items digitization_queue_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.digitization_queue_items
    ADD CONSTRAINT digitization_queue_items_pkey PRIMARY KEY (id);


--
-- Name: fixity_checks fixity_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixity_checks
    ADD CONSTRAINT fixity_checks_pkey PRIMARY KEY (id);


--
-- Name: kithe_derivatives kithe_derivatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_derivatives
    ADD CONSTRAINT kithe_derivatives_pkey PRIMARY KEY (id);


--
-- Name: kithe_models kithe_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_models
    ADD CONSTRAINT kithe_models_pkey PRIMARY KEY (id);


--
-- Name: on_demand_derivatives on_demand_derivatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.on_demand_derivatives
    ADD CONSTRAINT on_demand_derivatives_pkey PRIMARY KEY (id);


--
-- Name: queue_item_comments queue_item_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queue_item_comments
    ADD CONSTRAINT queue_item_comments_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: by_asset_and_checked_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_asset_and_checked_uri ON public.fixity_checks USING btree (asset_id, checked_uri);


--
-- Name: index_fixity_checks_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixity_checks_on_asset_id ON public.fixity_checks USING btree (asset_id);


--
-- Name: index_fixity_checks_on_checked_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixity_checks_on_checked_uri ON public.fixity_checks USING btree (checked_uri);


--
-- Name: index_kithe_derivatives_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_derivatives_on_asset_id ON public.kithe_derivatives USING btree (asset_id);


--
-- Name: index_kithe_derivatives_on_asset_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_kithe_derivatives_on_asset_id_and_key ON public.kithe_derivatives USING btree (asset_id, key);


--
-- Name: index_kithe_model_contains_on_containee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_model_contains_on_containee_id ON public.kithe_model_contains USING btree (containee_id);


--
-- Name: index_kithe_model_contains_on_container_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_model_contains_on_container_id ON public.kithe_model_contains USING btree (container_id);


--
-- Name: index_kithe_models_on_friendlier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_kithe_models_on_friendlier_id ON public.kithe_models USING btree (friendlier_id);


--
-- Name: index_kithe_models_on_leaf_representative_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_leaf_representative_id ON public.kithe_models USING btree (leaf_representative_id);


--
-- Name: index_kithe_models_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_parent_id ON public.kithe_models USING btree (parent_id);


--
-- Name: index_kithe_models_on_representative_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_representative_id ON public.kithe_models USING btree (representative_id);


--
-- Name: index_on_demand_derivatives_on_work_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_on_demand_derivatives_on_work_id ON public.on_demand_derivatives USING btree (work_id);


--
-- Name: index_on_demand_derivatives_on_work_id_and_deriv_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_on_demand_derivatives_on_work_id_and_deriv_type ON public.on_demand_derivatives USING btree (work_id, deriv_type);


--
-- Name: index_queue_item_comments_on_digitization_queue_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_queue_item_comments_on_digitization_queue_item_id ON public.queue_item_comments USING btree (digitization_queue_item_id);


--
-- Name: index_queue_item_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_queue_item_comments_on_user_id ON public.queue_item_comments USING btree (user_id);


--
-- Name: index_searches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_user_id ON public.searches USING btree (user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: trgm_idx_kithe_models_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trgm_idx_kithe_models_title ON public.kithe_models USING gin (title public.gin_trgm_ops);


--
-- Name: kithe_model_contains fk_rails_091010187b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_model_contains
    ADD CONSTRAINT fk_rails_091010187b FOREIGN KEY (container_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_models fk_rails_210e0ee046; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_models
    ADD CONSTRAINT fk_rails_210e0ee046 FOREIGN KEY (digitization_queue_item_id) REFERENCES public.digitization_queue_items(id);


--
-- Name: fixity_checks fk_rails_2950403fc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixity_checks
    ADD CONSTRAINT fk_rails_2950403fc8 FOREIGN KEY (asset_id) REFERENCES public.kithe_models(id);


--
-- Name: on_demand_derivatives fk_rails_3b0ff4a213; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.on_demand_derivatives
    ADD CONSTRAINT fk_rails_3b0ff4a213 FOREIGN KEY (work_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_derivatives fk_rails_3dac8b4201; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_derivatives
    ADD CONSTRAINT fk_rails_3dac8b4201 FOREIGN KEY (asset_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_models fk_rails_403cce5c0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_models
    ADD CONSTRAINT fk_rails_403cce5c0d FOREIGN KEY (leaf_representative_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_model_contains fk_rails_490c1158f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_model_contains
    ADD CONSTRAINT fk_rails_490c1158f7 FOREIGN KEY (containee_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_models fk_rails_90130a9780; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_models
    ADD CONSTRAINT fk_rails_90130a9780 FOREIGN KEY (parent_id) REFERENCES public.kithe_models(id);


--
-- Name: kithe_models fk_rails_afa93b7b5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kithe_models
    ADD CONSTRAINT fk_rails_afa93b7b5d FOREIGN KEY (representative_id) REFERENCES public.kithe_models(id);


--
-- Name: queue_item_comments fk_rails_faa45a6d5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queue_item_comments
    ADD CONSTRAINT fk_rails_faa45a6d5b FOREIGN KEY (digitization_queue_item_id) REFERENCES public.digitization_queue_items(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20181016145643'),
('20181016145644'),
('20181016145645'),
('20181107183159'),
('20181211182457'),
('20190107205722'),
('20190107222521'),
('20190109000356'),
('20190110154359'),
('20190219225344'),
('20190226135744'),
('20190304201533'),
('20190305170908'),
('20190305202051'),
('20190404155001'),
('20190422201311'),
('20190716180327'),
('20190827124516'),
('20190910160148');
