-- =============================================================================
-- seed.sql
-- Local development seed data. Runs only on `supabase db reset`, never in prod.
-- Real USDA / OpenFoodFacts seeding is handled by scripts/seed_foods.ts.
-- =============================================================================

-- A handful of common foods to make manual testing pleasant.
insert into public.foods
  (source, name, brand, serving_size_g, kcal_per_100g, protein_g, carb_g, fat_g, fiber_g, sugar_g, sodium_mg, blurb)
values
  ('usda', 'Egg, whole, large', null, 50,    143, 12.6,  0.7, 9.5, 0,   0.4, 142,
    'A whole egg is roughly 70 kcal and a great source of protein.'),
  ('usda', 'Greek yogurt, plain', null, 170,   59, 10.0,  3.6, 0.4, 0,   3.2,  36,
    'A creamy strained yogurt, high in protein and low in sugar.'),
  ('usda', 'Banana, raw', null, 118,         89,  1.1, 22.8, 0.3, 2.6, 12.2,  1,
    'A medium banana adds ~100 kcal and natural sugars for energy.'),
  ('usda', 'Chicken breast, cooked', null, 100, 165, 31.0,  0.0, 3.6, 0,   0.0,  74,
    'Lean cooked chicken breast; one of the highest protein-per-calorie foods.'),
  ('usda', 'Brown rice, cooked', null, 195,  111,  2.6, 23.0, 0.9, 1.8, 0.4,   5,
    'A whole grain that adds fiber and steady energy.'),
  ('usda', 'Avocado, raw', null, 150,        160,  2.0,  8.5, 14.7, 6.7, 0.7,  7,
    'High in healthy fats and fiber.'),
  ('usda', 'Spinach, raw', null, 30,          23,  2.9,  3.6, 0.4, 2.2, 0.4, 79,
    'Very low calorie, high in iron and vitamins.'),
  ('usda', 'Olive oil', null, 13.5,          884,  0.0,  0.0, 100.0, 0, 0.0,  2,
    'Pure fat; 1 tbsp is ~120 kcal.');
