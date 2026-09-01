-- RPC function to get aggregated demand radar data for the admin dashboard
CREATE OR REPLACE FUNCTION get_demand_radar_data()
RETURNS json AS $$
DECLARE
    result json;
BEGIN
    SELECT json_build_object(
        'top_category', (
            SELECT category FROM public.analytics_events 
            WHERE category IS NOT NULL 
            GROUP BY category 
            ORDER BY count(*) DESC 
            LIMIT 1
        ),
        'top_category_count', (
            SELECT count(*) FROM public.analytics_events 
            WHERE category = (
                SELECT category FROM public.analytics_events 
                WHERE category IS NOT NULL 
                GROUP BY category 
                ORDER BY count(*) DESC 
                LIMIT 1
            )
        ),
        'total_category_clicks', (
            SELECT count(*) FROM public.analytics_events 
            WHERE category IS NOT NULL
        ),
        'top_searches', (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (
                SELECT item_id as keyword, count(*) as count
                FROM public.analytics_events
                WHERE event_type = 'search' AND item_id IS NOT NULL
                GROUP BY item_id
                ORDER BY count DESC
                LIMIT 5
            ) t
        ),
        'top_properties', (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (
                SELECT item_id as property_id, count(*) as count
                FROM public.analytics_events
                WHERE event_type = 'property_view' AND item_id IS NOT NULL
                GROUP BY item_id
                ORDER BY count DESC
                LIMIT 5
            ) t
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;
