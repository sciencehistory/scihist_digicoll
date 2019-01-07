SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: kithe_models_friendlier_id_gen(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION kithe_models_friendlier_id_gen(min_value bigint, max_value bigint) RETURNS text
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

CREATE TABLE ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: kithe_derivatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE kithe_derivatives (
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

CREATE SEQUENCE kithe_derivatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: kithe_derivatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE kithe_derivatives_id_seq OWNED BY kithe_derivatives.id;


--
-- Name: kithe_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE kithe_models (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying NOT NULL,
    type character varying NOT NULL,
    "position" integer,
    json_attributes jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    parent_id uuid,
    friendlier_id character varying DEFAULT kithe_models_friendlier_id_gen('2176782336'::bigint, '78364164095'::bigint) NOT NULL,
    file_data jsonb,
    representative_id uuid,
    leaf_representative_id uuid
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: kithe_derivatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_derivatives ALTER COLUMN id SET DEFAULT nextval('kithe_derivatives_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: kithe_derivatives kithe_derivatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_derivatives
    ADD CONSTRAINT kithe_derivatives_pkey PRIMARY KEY (id);


--
-- Name: kithe_models kithe_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_models
    ADD CONSTRAINT kithe_models_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_kithe_derivatives_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_derivatives_on_asset_id ON kithe_derivatives USING btree (asset_id);


--
-- Name: index_kithe_derivatives_on_asset_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_kithe_derivatives_on_asset_id_and_key ON kithe_derivatives USING btree (asset_id, key);


--
-- Name: index_kithe_models_on_friendlier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_kithe_models_on_friendlier_id ON kithe_models USING btree (friendlier_id);


--
-- Name: index_kithe_models_on_leaf_representative_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_leaf_representative_id ON kithe_models USING btree (leaf_representative_id);


--
-- Name: index_kithe_models_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_parent_id ON kithe_models USING btree (parent_id);


--
-- Name: index_kithe_models_on_representative_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kithe_models_on_representative_id ON kithe_models USING btree (representative_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON users USING btree (reset_password_token);


--
-- Name: kithe_derivatives fk_rails_3dac8b4201; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_derivatives
    ADD CONSTRAINT fk_rails_3dac8b4201 FOREIGN KEY (asset_id) REFERENCES kithe_models(id);


--
-- Name: kithe_models fk_rails_403cce5c0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_models
    ADD CONSTRAINT fk_rails_403cce5c0d FOREIGN KEY (leaf_representative_id) REFERENCES kithe_models(id);


--
-- Name: kithe_models fk_rails_90130a9780; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_models
    ADD CONSTRAINT fk_rails_90130a9780 FOREIGN KEY (parent_id) REFERENCES kithe_models(id);


--
-- Name: kithe_models fk_rails_afa93b7b5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY kithe_models
    ADD CONSTRAINT fk_rails_afa93b7b5d FOREIGN KEY (representative_id) REFERENCES kithe_models(id);


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
('20190107222521');


