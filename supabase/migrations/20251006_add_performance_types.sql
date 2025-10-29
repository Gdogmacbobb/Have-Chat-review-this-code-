-- Add performance_types JSONB column to support multi-category selection
-- This allows street performers to select multiple performance categories with subcategories

ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS performance_types JSONB DEFAULT '{}'::JSONB;

-- Add comment to document the column structure
COMMENT ON COLUMN public.user_profiles.performance_types IS 'Stores multi-category performance selections as JSONB map: {"Music": ["Singing", "Guitar"], "Dance": ["Hip Hop"]}';

-- Create index for faster JSONB queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_performance_types ON public.user_profiles USING GIN (performance_types);
