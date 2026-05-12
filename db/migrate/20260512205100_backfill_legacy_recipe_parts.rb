class BackfillLegacyRecipeParts < ActiveRecord::Migration[8.1]
  def up
    add_column :recipes, :parts, :jsonb, null: false, default: [] unless column_exists?(:recipes, :parts)

    ingredients_sql = column_exists?(:recipes, :ingredients) ? "COALESCE(ingredients, '[]'::jsonb)" : "'[]'::jsonb"
    instructions_sql = column_exists?(:recipes, :instructions) ? "COALESCE(instructions, '[]'::jsonb)" : "'[]'::jsonb"

    if column_exists?(:recipes, :ingredients) || column_exists?(:recipes, :instructions)
      execute <<~SQL
        UPDATE recipes
        SET parts = jsonb_build_array(
          jsonb_build_object(
            'name', '',
            'ingredients', #{ingredients_sql},
            'instructions', #{instructions_sql}
          )
        )
        WHERE COALESCE(parts, '[]'::jsonb) = '[]'::jsonb
          AND (
            #{ingredients_sql} <> '[]'::jsonb OR
            #{instructions_sql} <> '[]'::jsonb
          );
      SQL

      remove_column :recipes, :ingredients if column_exists?(:recipes, :ingredients)
      remove_column :recipes, :instructions if column_exists?(:recipes, :instructions)
    end

    execute <<~SQL
      DROP TRIGGER IF EXISTS recipes_tsv_trg ON recipes;
      DROP FUNCTION IF EXISTS recipes_tsv_update();

      CREATE FUNCTION recipes_tsv_update() RETURNS trigger AS $$
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

      CREATE TRIGGER recipes_tsv_trg BEFORE INSERT OR UPDATE ON recipes
        FOR EACH ROW EXECUTE FUNCTION recipes_tsv_update();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely recreate legacy ingredients/instructions columns"
  end
end
