-- Enable pg_net for webhooks
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create the webhook function
CREATE OR REPLACE FUNCTION public.handle_push_notification_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://dhbwnteiahefjfpojapz.supabase.co/functions/v1/send-push',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'broadcast_notifications',
      'record', row_to_json(NEW)
    )
  );
  RETURN NEW;
END;
$$;

-- Create the trigger
DROP TRIGGER IF EXISTS "push_notification_trigger" ON public.broadcast_notifications;
CREATE TRIGGER "push_notification_trigger"
  AFTER INSERT
  ON public.broadcast_notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_push_notification_webhook();
