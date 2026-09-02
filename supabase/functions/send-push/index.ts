import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

console.log("Push notification function started");

async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const formattedKey = (serviceAccount.private_key || "")
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(formattedKey), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const header = { alg: "RS256", typ: "JWT" };
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const encodedClaim = btoa(JSON.stringify(claim)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  
  const tokenToSign = new TextEncoder().encode(`${encodedHeader}.${encodedClaim}`);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, tokenToSign);
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${encodedHeader}.${encodedClaim}.${encodedSignature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Google OAuth error: ${JSON.stringify(data)}`);
  }

  return data.access_token;
}

serve(async (req) => {
  try {
    const payload = await req.json();

    // Check if this is an insert event from the database webhook
    if (payload.type === "INSERT" && payload.table === "broadcast_notifications") {
      const notification = payload.record;

      // 1. Initialize Supabase client
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      // 2. Fetch device tokens using the RPC
      const { data: tokensData, error: rpcError } = await supabase.rpc("get_segmented_fcm_tokens", {
        target_audience: notification.target_audience
      });

      if (rpcError) {
        throw new Error(`Failed to fetch tokens: ${rpcError.message}`);
      }

      const tokens = tokensData.map((t: any) => t.fcm_token).filter(Boolean);

      if (tokens.length === 0) {
        return new Response(JSON.stringify({ message: "No devices found for target audience" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      // 3. Get Google Access Token
      let serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
      if (!serviceAccountStr) {
        const b64 = "eyJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsICJwcm9qZWN0X2lkIjogInJlbnRhbC02NzAzMiIsICJwcml2YXRlX2tleV9pZCI6ICJmZTYzMTBlNmE4MTNlM2EzMjEyYjJiMzUxYjkwMWQwZTg5MWZmODk0IiwgInByaXZhdGVfa2V5IjogIi0tLS0tQkVHSU4gUFJJVkFURSBLRVktLS0tLVxuTUlJRXZ3SUJBREFOQmdrcWhraUc5dzBCQVFFRkFBU0NCS2t3Z2dTbEFnRUFBb0lCQVFDMlJRUUFBbERhTGs3c1xuWUlIaWJiQzlEdHRFYzV1WXNJTlJnZXAvVVJRZzFRWXAvUlh6UjdRZ1o2bXFyK3pLZXR5SmhpblpjQmFzTHhLb1xua3dyenc5U2VHa0RFZVExOTFhRXl1TS9rNGRaRVFvZ0ZjUjBDMjh1ZU4zZTJ1eW5LVnRPVEJsRWFMWUlzNi9zNlxuODdkWjlhNTFQRVNxNjkrVk1kb2djb1NOeGV0NmphVmRrOVN1ZER4aVA1VnNheC9KTDllb2YxcjBkWStiS0FPelxuVXZ5UTdZelA3c2lKTTVHbHFXSnBDYzlHUFFvOTJ4T0ZncTFTS0FTYzQrM2ZZeDNEbzhCV3lCNmJwTTIzMzEyaFxuMHBIcFhoNUc3bjBZWndEWXRCdEZHcjZLT3Z0ajdFeGJLTkUvS0poTFl1aWkwUW1FWWhMU0o1THBUL3hTREZRSVxuUlJEbTZrNUxBZ01CQUFFQ2dnRUFFdFZLRnRvbVo5K0xFTW8wQVhwd3N2TGxzeC80UHRjQTZwdHdQY2JaNXBQbVxuOXRCZ3crb2FjWks1MUVUVFJHU3lMdW8rOUJSWE0yUUxHeXlwQ3JaUnNpTVNUWHJEUUhKTXlBU1NtVVZyTWYyOFxualBDNng2c3EvSkVoL0lQcTlkanlORDh6TFcrYkEzQ1ZYVCt3MHA4YnhKOVNsUS91NHBLV2NFTXZtOFUzUEtBRFxuZUhiVFVpKzRxclZiVzhJVFB0TktyYWR6MHpMNXF6TmFFNHMzWFZsWXV3bGl0WTJGUURhTEZBOUtRcHVuTjFkclxuSjY5aS9hcC91RTllN1VjTFdER3NQNllHT1JwajJkUVpvdDNaVzRXaURrM2J2OVF0TWlCYXBmb2s4b3ViektqQ1xuVWpnamd0bFJZU093RTVmRWRlTXdudXIrQmdBTnR0d25TazJpRURYcHFRS0JnUURqVitQZDdaTzJkRVMvUzA4RFxuMTdQNEFrc3hmVzRxNTNFaFNRY3NpMCtha05WLzlZakVONE1rUk8rVkc3V0IwbzJEQ1EwWWZzRTlIZFlXUVdNd1xuL094SFFtKzY4V2kwcHZFUlhhRVV2bzNsbTFoZ25TM2pSZ1cxZVphSWk4MUY2Qm1pb2FybWJMVXE5QlYxdkhnTFxuc2EyMVR1M1BiNWpDa01UQUVMQko2QzloNXdLQmdRRE5QcVhOZFREUUl1ZkVqdmRUUGhmc3F5MHBvUnpvdnlzY1xuUmRRd2xDTjRFcUxkTFNVbFAyNURGVTZURDZkVlM0S3k2TnpESmFJVWY3UzNIbGpySjN1djYvam1XY0EyekNkUVxubWtHSTZSSlIyYmxLN2dhYmtHNFRTdm5qQmtpU1lOamRHaEN2VVhGanZ4KzhKRkN5bXVGaVNOVUtzeFpxYk9SbFxuOTRWanZSMXIvUUtCZ1FES1NZZ2VEcWxpcmE0R01MSk1Ed0M1NndDUk5yUnlSS0dySmxuVnp0ZTBCcStTUGgzRlxueWtkTVhISjUwTC8rbGlVSXRXTUxxcTJ5L2Z0aXJpZmVqUTZJa1pydFVxVUNLWkZUREdhcUdLd1Y0OVlOa1k0bFxuTGtjaUpPQkcrMjVaaDU1WDBWWkoxZXlXSGIyQ2w0S1JsVFdsb0dlR0xoeFU4NCs5L3B0K0I3VXhmUUtCZ1FDM1xubGVyKzdXMWRMMnU2c05yZnRiSDJ1MktwVXZpbDQ2RnZKN0xXUlJ1NDRvcVZaalZNclFFMnRnOVRrZlB1WXAya1xuNUkvYmFvVWc2dDQ5MGNKZGpUS2d1R1Vwdm13bFY5VnV6cHdDRitDUUlEMFNuZmlCRzk2cUdTMk4rV2Zlcnd3c1xuTVkxdEZGOWxobWFmaHFnOEtqZWlEMTJvdFdvK2hlcUNuclhNOGpNb0RRS0JnUURCSlNTU3QrQVd6OWxRdXErOVxuallJbVF5ejhuQkZ2ak9Kc0Q5dWFESDF2WXdIcVJjZ29XVGFwTGtDRjZSelQzNlFsOVY2RjRsNll5eFpvazI5cFxudGZsYlpaN1RXUDZWWE1na3dwNU9mWWV2eXFtcjFpTlRnZm1WNzJtZXQvdFk2WWJCWWt3Uk8yL0lXZ0NWeE5NMlxuSStSUnBHR250NGhyY2FFWUZwOTN3bzBUalE9PVxuLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLVxuIiwgImNsaWVudF9lbWFpbCI6ICJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0ByZW50YWwtNjcwMzIuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCAiY2xpZW50X2lkIjogIjEwOTI5MDI0NDE4NDE5OTY3MDc0IiwgImF1dGhfdXJpIjogImh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlYXBpcy5jb20vby9vYXV0aDIvYXV0aCIsICJ0b2tlbl91cmkiOiAiaHR0cHM6Ly9vYXV0aDIuZ29vZ2xlYXBpcy5jb20vdG9rZW4iLCAiYXV0aF9wcm92aWRlcl94NTA5X2NlcnRfdXJsIjogImh0dHBzOi8vd3d3Lmdvb2dsZWFwaXMuY29tL29hdXRoMi92MS9jZXJ0cyIsICJjbGllbnRfeDUwOV9jZXJ0X3VybCI6ICJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9yb2JvdC92MS9tZXRhZGF0YS94NTA5L2ZpcmViYXNlLWFkbWluc2RrLWZic3ZjJTQwcmVudGFsLTY3MDMyLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwgInVuaXZlcnNlX2RvbWFpbiI6ICJnb29nbGVhcGlzLmNvbSJ9";
        const binaryStr = atob(b64);
        const bytes = new Uint8Array(binaryStr.length);
        for (let i = 0; i < binaryStr.length; i++) {
          bytes[i] = binaryStr.charCodeAt(i);
        }
        serviceAccountStr = new TextDecoder().decode(bytes);
      }

      const serviceAccount = JSON.parse(serviceAccountStr);
      const accessToken = await getGoogleAccessToken(serviceAccount);

      // 4. Send Firebase Messages
      // Firebase FCM HTTP v1 API
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
      
      let successCount = 0;
      let failureCount = 0;

      // Send to each token
      for (const token of tokens) {
        const messageBody = {
          message: {
            token: token,
            notification: {
              title: notification.title,
              body: notification.body,
              image: notification.image_url || undefined,
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "rental_signature_channel",
                sound: "correct",
                notification_priority: "PRIORITY_MAX",
                visibility: "PUBLIC"
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                  "content-available": 1
                }
              }
            },
            data: {
              // Pass the full notification payload as data so the app can route it
              id: notification.id,
              title: notification.title,
              body: notification.body,
              image_url: notification.image_url || "",
              target_audience: notification.target_audience,
              action_type: notification.action_type,
              target_route_or_id: notification.target_route_or_id || "",
              target_label: notification.target_label || "",
              is_high_priority: notification.is_high_priority ? "true" : "false",
              created_at: notification.created_at,
            }
          }
        };

        const response = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(messageBody),
        });

        const resText = await response.text();
        if (response.ok) {
          successCount++;
        } else {
          failureCount++;
          console.error(`Failed to send to token ${token}: status=${response.status} body=${resText}`);
          if (response.status === 404 || resText.includes("UNREGISTERED") || resText.includes("NotRegistered")) {
            // Automatically clean up stale/uninstalled token from public.devices
            await supabase.from("devices").delete().eq("fcm_token", token);
          }
        }
      }

      // 5. Update notification record with recipient count
      await supabase
        .from("broadcast_notifications")
        .update({ recipient_count: successCount, status: "sent" })
        .eq("id", notification.id);

      return new Response(JSON.stringify({ 
        message: "Notifications dispatched", 
        successCount, 
        failureCount 
      }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ message: "Invalid payload" }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    });
  } catch (err: any) {
    console.error("Function error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
