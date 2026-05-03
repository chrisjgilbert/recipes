class SimplifyRecipeFields < ActiveRecord::Migration[8.1]
  def up
    remove_column :recipes, :tags
    remove_column :recipes, :cuisine
    remove_column :recipes, :course
    remove_column :recipes, :difficulty

    add_column :recipes, :chef, :string

    execute <<~SQL
      DROP INDEX IF EXISTS recipes_tags_idx;
      DROP INDEX IF EXISTS recipes_cuisine_idx;
      DROP INDEX IF EXISTS recipes_course_idx;

      CREATE INDEX recipes_chef_trgm_idx ON recipes USING gin (chef gin_trgm_ops);

      CREATE OR REPLACE FUNCTION recipes_tsv_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_tsv :=
          setweight(to_tsvector('english', coalesce(NEW.title,'')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.chef,'')), 'B') ||
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
    SQL
  end

  def down
    remove_column :recipes, :chef

    add_column :recipes, :tags, :text, array: true, null: false, default: []
    add_column :recipes, :cuisine, :string
    add_column :recipes, :course, :string
    add_column :recipes, :difficulty, :string

    execute <<~SQL
      DROP INDEX IF EXISTS recipes_chef_trgm_idx;

      CREATE INDEX recipes_tags_idx ON recipes USING gin (tags);
      CREATE INDEX recipes_cuisine_idx ON recipes (cuisine);
      CREATE INDEX recipes_course_idx ON recipes (course);

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
    SQL
  end
end
