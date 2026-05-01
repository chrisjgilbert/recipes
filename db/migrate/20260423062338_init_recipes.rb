class InitRecipes < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pgcrypto"
    enable_extension "pg_trgm"

    create_table :recipes, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string  :title, null: false
      t.text    :source_url
      t.string  :source_site
      t.text    :description
      t.text    :image_url
      t.integer :prep_time_minutes
      t.integer :cook_time_minutes
      t.integer :total_time_minutes
      t.integer :servings
      t.jsonb   :parts, null: false, default: []
      t.text    :tags, array: true, null: false, default: []
      t.string  :cuisine
      t.string  :course
      t.string  :difficulty
      t.text    :notes
      t.tsvector :search_tsv
      t.timestamps null: false
    end

    execute <<~SQL
      CREATE INDEX recipes_search_tsv_idx ON recipes USING gin (search_tsv);
      CREATE INDEX recipes_tags_idx ON recipes USING gin (tags);
      CREATE INDEX recipes_title_trgm_idx ON recipes USING gin (title gin_trgm_ops);
      CREATE INDEX recipes_cuisine_idx ON recipes (cuisine);
      CREATE INDEX recipes_course_idx ON recipes (course);
      CREATE INDEX recipes_created_at_idx ON recipes (created_at DESC);

      CREATE OR REPLACE FUNCTION recipes_tsv_update() RETURNS trigger AS $$
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
      END; $$ LANGUAGE plpgsql;

      CREATE TRIGGER recipes_tsv_trg BEFORE INSERT OR UPDATE ON recipes
        FOR EACH ROW EXECUTE FUNCTION recipes_tsv_update();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS recipes_tsv_trg ON recipes"
    execute "DROP FUNCTION IF EXISTS recipes_tsv_update()"
    drop_table :recipes
  end
end
