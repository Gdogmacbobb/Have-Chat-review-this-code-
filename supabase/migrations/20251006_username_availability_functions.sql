-- Username availability checking function
CREATE OR REPLACE FUNCTION check_username_availability(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return true if username is available (doesn't exist)
  RETURN NOT EXISTS (
    SELECT 1 
    FROM user_profiles 
    WHERE LOWER(username) = LOWER(p_username)
  );
END;
$$;

-- Username suggestions function
CREATE OR REPLACE FUNCTION get_username_suggestions(
  p_username TEXT,
  p_borough TEXT DEFAULT NULL,
  p_performance_types JSONB DEFAULT NULL
)
RETURNS TEXT[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  suggestions TEXT[] := ARRAY[]::TEXT[];
  base_username TEXT;
  counter INT;
  temp_suggestion TEXT;
  borough_suffix TEXT;
  category_suffix TEXT;
BEGIN
  -- Clean the username
  base_username := LOWER(TRIM(p_username));
  
  -- Generate numeric suffixes (username1, username2, username3)
  FOR counter IN 1..3 LOOP
    temp_suggestion := base_username || counter::TEXT;
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = temp_suggestion) THEN
      suggestions := array_append(suggestions, temp_suggestion);
    END IF;
  END LOOP;
  
  -- Generate location-based suggestions if borough is provided
  IF p_borough IS NOT NULL THEN
    CASE p_borough
      WHEN 'Manhattan' THEN borough_suffix := '_manhattan';
      WHEN 'Brooklyn' THEN borough_suffix := '_brooklyn';
      WHEN 'Queens' THEN borough_suffix := '_queens';
      WHEN 'Bronx' THEN borough_suffix := '_bronx';
      WHEN 'Staten Island' THEN borough_suffix := '_si';
      ELSE borough_suffix := '_nyc';
    END CASE;
    
    temp_suggestion := base_username || borough_suffix;
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = temp_suggestion) THEN
      suggestions := array_append(suggestions, temp_suggestion);
    END IF;
  ELSE
    -- Default to _nyc if no borough
    temp_suggestion := base_username || '_nyc';
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = temp_suggestion) THEN
      suggestions := array_append(suggestions, temp_suggestion);
    END IF;
  END IF;
  
  -- Generate category-based suggestions if performance types provided
  IF p_performance_types IS NOT NULL AND jsonb_array_length(p_performance_types) > 0 THEN
    -- Get the first performance type
    category_suffix := CASE jsonb_array_element_text(p_performance_types, 0)
      WHEN 'Music' THEN '_music'
      WHEN 'Dance' THEN '_dance'
      WHEN 'Visual Arts' THEN '_art'
      WHEN 'Comedy' THEN '_comedy'
      WHEN 'Magic' THEN '_magic'
      ELSE '_performer'
    END;
    
    temp_suggestion := base_username || category_suffix;
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = temp_suggestion) THEN
      suggestions := array_append(suggestions, temp_suggestion);
    END IF;
  END IF;
  
  RETURN suggestions;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION check_username_availability(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_username_availability(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_username_suggestions(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_username_suggestions(TEXT, TEXT, JSONB) TO anon;
