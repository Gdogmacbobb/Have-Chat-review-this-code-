-- =====================================================
-- Username Availability Functions for Supabase
-- Copy and paste this entire script into Supabase SQL Editor
-- =====================================================

-- Function 1: Check if a username is available
CREATE OR REPLACE FUNCTION check_username_availability(p_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 
        FROM user_profiles 
        WHERE LOWER(username) = LOWER(p_username)
    );
END;
$$;

-- Function 2: Generate smart username suggestions
CREATE OR REPLACE FUNCTION get_username_suggestions(
    p_username text,
    p_borough text DEFAULT NULL,
    p_performance_types jsonb DEFAULT NULL
)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    suggestions text[] := '{}';
    base_username text;
    suggestion text;
    counter int;
    max_suggestions int := 5;
    performance_type text;
BEGIN
    base_username := LOWER(p_username);
    
    -- Strategy 1: Add numeric suffixes (username1, username2, etc.)
    counter := 1;
    WHILE array_length(suggestions, 1) < max_suggestions AND counter <= 99 LOOP
        suggestion := base_username || counter;
        IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = suggestion) THEN
            suggestions := array_append(suggestions, suggestion);
        END IF;
        counter := counter + 1;
    END LOOP;
    
    -- Strategy 2: Add borough suffix if provided
    IF p_borough IS NOT NULL AND array_length(suggestions, 1) < max_suggestions THEN
        suggestion := base_username || '_' || LOWER(REPLACE(p_borough, ' ', ''));
        IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = suggestion) THEN
            suggestions := array_append(suggestions, suggestion);
        END IF;
        
        -- Try short borough codes
        CASE LOWER(p_borough)
            WHEN 'manhattan' THEN suggestion := base_username || '_mhtn';
            WHEN 'brooklyn' THEN suggestion := base_username || '_bk';
            WHEN 'queens' THEN suggestion := base_username || '_qns';
            WHEN 'bronx' THEN suggestion := base_username || '_bx';
            WHEN 'staten island' THEN suggestion := base_username || '_si';
            ELSE suggestion := NULL;
        END CASE;
        
        IF suggestion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = suggestion) THEN
            suggestions := array_append(suggestions, suggestion);
        END IF;
    END IF;
    
    -- Strategy 3: Add performance type suffix if provided
    IF p_performance_types IS NOT NULL AND array_length(suggestions, 1) < max_suggestions THEN
        FOR performance_type IN SELECT jsonb_array_elements_text(p_performance_types) LOOP
            suggestion := base_username || '_' || LOWER(REPLACE(performance_type, ' ', ''));
            IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = suggestion) THEN
                suggestions := array_append(suggestions, suggestion);
                EXIT WHEN array_length(suggestions, 1) >= max_suggestions;
            END IF;
        END LOOP;
    END IF;
    
    RETURN suggestions;
END;
$$;

-- Grant execute permissions to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION check_username_availability(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_username_suggestions(text, text, jsonb) TO authenticated, anon;

-- Verification queries (optional - you can run these to verify)
-- SELECT check_username_availability('testuser');
-- SELECT get_username_suggestions('testuser', 'Brooklyn', '["Music", "Dance"]'::jsonb);
